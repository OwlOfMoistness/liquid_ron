// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import {IComet} from "./IComet.sol";
import {IUniPoolV3} from "./IUniPoolV3.sol";
import {IUniPoolV3Factory} from "./IUniPoolV3.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Iwron} from "./IWRON.sol";
import {LiquidRon} from "../LiquidRon.sol";
import {LiquidProxy} from "../LiquidProxy.sol";
import {IProfile} from "../interfaces/IProfile.sol";
import {IRoninValidator} from "../interfaces/IRoninValidators.sol";

contract LiquidRonCompLiquidator {
	error BadAsset();
	error NoBaseToken();
	error NotEnoughAssets();
	error ExpectedPool();

	struct Fee {
		uint256 f0;
		uint256 f1;
	}

	struct PoolKey {
		address tokenA;
		address tokenB;
		uint24 fee;
	}

	struct Data {
		address[] pools;
		uint256[] amounts;
		Fee[] fees;
		PoolKey[] poolKeys;
		address comet;
		uint256 collateralBalance;
		uint256 askAmount;
		uint256 amountRaised;
		uint256 index;
	}

	uint256 public constant QUOTE_PRICE_SCALE = 1e18;

	address public immutable WRON;
	address public immutable LRON;
	address public immutable PROFILE;
	address public immutable RONIN_VALIDATOR;
	address public immutable UNI_V3_FACTORY;

	constructor(address _wron, address _lron, address _profile, address _roninValidator, address _uniV3Factory) {
		WRON = _wron;
		LRON = _lron;
		PROFILE = _profile;
		RONIN_VALIDATOR = _roninValidator;
		UNI_V3_FACTORY = _uniV3Factory;
	}

	/**
	 * @notice Liquidates underwater positions in Compound by absorbing them and buying the collateral
	 * @param _comet The Compound Comet contract address
	 * @param _pools Array of Katana V3 pool addresses to use for flash loans
	 * @param _accounts Array of accounts to liquidate
	 */
	function liquidate(address _comet, address[] memory _pools, address[] calldata _accounts) external payable {
		IComet comet = IComet(_comet);
		Data memory data;
		if (comet.baseToken() != WRON) revert BadAsset();

		if (address(this).balance > 0) Iwron(WRON).deposit{value: address(this).balance}();
		comet.absorb(msg.sender, _accounts);
		(data.collateralBalance, data.askAmount) = _purchasableBalanceOfAsset(comet, LRON);
		data.amountRaised = IERC20(WRON).balanceOf(address(this));
		data.pools = _pools;
		data.fees = new Fee[](_pools.length);
		data.poolKeys = new PoolKey[](_pools.length);
		data.amounts = new uint256[](_pools.length);
		data.comet = _comet;

		if (data.amountRaised >= data.askAmount) return _proceedDiscountAcquisition(data);
		for (uint256 i = 0; i < _pools.length; i++) {
			data.poolKeys[i] = PoolKey({
				tokenA: IUniPoolV3(_pools[i]).token0(),
				tokenB: IUniPoolV3(_pools[i]).token1(),
				fee: IUniPoolV3(_pools[i]).fee()
			});
		}
		_initiateKatanaV3Flash(_pools[0], data.poolKeys[0], data);
	}

	/**
	 * @notice Callback function called by Katana V3 pool after flash loan
	 * @param _fee0 Fee to pay for token0 flash loan
	 * @param _fee1 Fee to pay for token1 flash loan  
	 * @param _data Encoded data containing liquidation parameters
	 */
	function katanaV3FlashCallback(uint256 _fee0, uint256 _fee1, bytes memory _data) external {
		Data memory data = abi.decode(_data, (Data));
		PoolKey memory poolKey = data.poolKeys[data.index];
		address pool = IUniPoolV3Factory(UNI_V3_FACTORY).getPool(poolKey.tokenA, poolKey.tokenB, poolKey.fee);
		if (msg.sender != pool) revert ExpectedPool();

		data.fees[data.index] = Fee({f0: _fee0, f1: _fee1});
		data.index++;
		if (data.amountRaised >= data.askAmount) return _proceedDiscountAcquisition(data);
		_initiateKatanaV3Flash(data.pools[data.index], data.poolKeys[data.index], data);
	}

	/**
	 * @notice Initiates a flash loan from a Katana V3 pool
	 * @param _pool Address of the pool to flash loan from
	 * @param _poolKey Pool key containing token addresses and fee
	 * @param data Encoded data containing liquidation parameters
	 */
	function _initiateKatanaV3Flash(address _pool, PoolKey memory _poolKey, Data memory data) internal {
		uint256 amount0;
		uint256 amount1;
		(bool zeroOrOne, uint256 amount) = _checkPoolHasBaseToken(_pool, _poolKey, WRON, data.askAmount - data.amountRaised);
		data.amountRaised += amount;
		data.amounts[data.index] = amount;
		if (zeroOrOne)
			amount0 = amount;
		else
			amount1 = amount;
		IUniPoolV3(_pool).flash(address(this), amount0, amount1, abi.encode(data));
	}

	/**
	 * @notice Checks if a pool has the required base token and returns available balance
	 * @param _pool Address of the Katana V3 pool
	 * @param _poolKey Pool key containing token addresses and fee
	 * @param _baseToken Address of the base token to check for
	 * @param _totalNeeded Total amount of base token needed
	 * @return bool True if token1 is base token, false if token0
	 * @return uint256 Available balance of base token in pool
	 */
	function _checkPoolHasBaseToken(
		address _pool,
		PoolKey memory _poolKey,
		address _baseToken,
		uint256 _totalNeeded
	) internal view returns (bool, uint256) {
		address token0 = _poolKey.tokenA;
		if (token0 == _baseToken) {
			uint256 balance = IERC20(token0).balanceOf(_pool);
			return (false, balance > _totalNeeded ? _totalNeeded : balance);
		}
		address token1 = _poolKey.tokenB;
		if (token1 == _baseToken) {
			uint256 balance = IERC20(token1).balanceOf(_pool);
			return (true, balance > _totalNeeded ? _totalNeeded : balance);
		}
		revert NoBaseToken();
	}

	/**
	 * @notice Proceeds with discount acquisition after obtaining required funds
	 * Once RON redemption is complete, repay the flash loans and send the remaining WRON to the sender
	 * @param data Encoded data containing liquidation parameters
	 */
	function _proceedDiscountAcquisition(Data memory data) internal {
		IComet comet = IComet(data.comet);

		IERC20(WRON).approve(address(comet), data.askAmount);
		comet.buyCollateral(LRON, 0, data.askAmount, address(this));
		_redeemLRON(IERC20(LRON).balanceOf(address(this)));
		for (uint256 i = 0; i < data.index; i++) {
			Fee memory fee = data.fees[i];
			IERC20(WRON).transfer(data.pools[i], data.amounts[i] + (fee.f0 > 0 ? fee.f0 : fee.f1));
		}
		IERC20(WRON).transfer(msg.sender, IERC20(WRON).balanceOf(address(this)));
	}

	/**
	 * @notice Redeems LRON tokens by undelegating from validators
	 * @param _amount Amount of LRON to redeem
	 */
	function _redeemLRON(uint256 _amount) internal {
		LiquidRon lron = LiquidRon(payable(LRON));
		uint256 amountToRedeem = lron.previewRedeem(_amount) - lron.getAssetsInVault();
		address[] memory consensusAddrs = IProfile(PROFILE).getManyId2Consensus(lron.getValidators());
		uint256 stakingProxyCount = lron.stakingProxyCount();

		for (uint256 i = 0; i < consensusAddrs.length; i++) {
			address consensusAddr = consensusAddrs[i];
			for (uint256 j = 0; j < stakingProxyCount; j++) {
				address proxy = lron.stakingProxies(j);
				uint256 lastDelegatingTimestamp = LiquidProxy(payable(proxy)).lastDelegatingTimestamp(consensusAddr);
				if (lastDelegatingTimestamp + 3 days < block.timestamp) {
					uint256 stakedAmount = IRoninValidator(RONIN_VALIDATOR).getStakingAmount(consensusAddr, proxy);
					uint256[] memory am = new uint256[](1);
					address[] memory addr = new address[](1);
					am[0] = stakedAmount > amountToRedeem ? amountToRedeem : stakedAmount;
					addr[0] = consensusAddr;
					amountToRedeem -= am[0];
					lron.undelegateAmount(j, am, addr);
					if (amountToRedeem == 0) break;
				}
				else
					continue;
			}
			if (amountToRedeem == 0) break;
		}
		if (amountToRedeem > 0) revert NotEnoughAssets();
		lron.redeem(_amount, address(this), address(this));
		Iwron(WRON).deposit{value: address(this).balance}();
	}

	/**
	 * @notice Gets the purchasable balance of an asset from Compound
	 * @param _comet The Compound Comet contract
	 * @param _asset Address of the asset to check
	 * @return uint256 Collateral balance
	 * @return uint256 Collateral balance converted to base token units
	 */
	function _purchasableBalanceOfAsset(IComet _comet, address _asset) internal view returns (uint256, uint256) {
		uint256 collateralBalance = _comet.getCollateralReserves(_asset);
		uint256 baseScale = _comet.baseScale();
		uint256 quotePrice = _comet.quoteCollateral(_asset, QUOTE_PRICE_SCALE * baseScale);
		uint256 collateralBalanceInBase = baseScale * QUOTE_PRICE_SCALE * collateralBalance / quotePrice;

		return (collateralBalance, collateralBalanceInBase);
	}

	receive() external payable {}
}