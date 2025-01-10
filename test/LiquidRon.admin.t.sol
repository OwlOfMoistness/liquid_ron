// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import {Test, console} from "forge-std/Test.sol";
import {LiquidRon, WithdrawalStatus, Pausable} from "../src/LiquidRon.sol";
import {LiquidProxy} from "../src/LiquidProxy.sol";
import {WrappedRon} from "../src/mock/WrappedRon.sol";
import {MockRonStaking} from "../src/mock/MockRonStaking.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Escrow} from "../src/Escrow.sol";

contract LiquidRonTest is Test {
	LiquidRon public liquidRon;
	WrappedRon public wrappedRon;
	MockRonStaking public mockRonStaking;

	address[] public consensusAddrs = [
			0xF000000000000000000000000000000000000001,
			0xf000000000000000000000000000000000000002,
			0xf000000000000000000000000000000000000003,
			0xF000000000000000000000000000000000000004,
			0xf000000000000000000000000000000000000005
	];

	function setUp() public {
		mockRonStaking = new MockRonStaking();
		payable(address(mockRonStaking)).transfer(100_000_000 ether);
		wrappedRon = new WrappedRon();
		liquidRon = new LiquidRon(address(mockRonStaking), address(wrappedRon), 250);
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
	}

	function test_revert_proxy_calls_not_vault() public {
		vm.prank(consensusAddrs[1]);
		address proxy = liquidRon.stakingProxies(0);
		vm.expectRevert("LiquidProxy: not vault");
		LiquidProxy(payable(proxy)).harvest(consensusAddrs);
	}

	function test_admin_pause() public {
		liquidRon.pause();
		assertTrue(liquidRon.paused());
	}

	function test_revert_admin_pause(address _user) public {
		vm.assume(_user != address(this));
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(_user);
		liquidRon.pause();
	}

	function test_admin_unpause() public {
		liquidRon.unpause();
		assertTrue(!liquidRon.paused());
	}

	function test_pause_modifer() public {
		liquidRon.pause();
		vm.expectRevert(Pausable.ErrPaused.selector);
		liquidRon.deposit{value:1000 ether}();
	}

	function test_admin_set_operator(address _operator) public {
		liquidRon.updateOperator(_operator, true);
		assertEq(liquidRon.operator(_operator), true);
	}

	function test_admin_revert_set_operator(address _operator) public {
		vm.assume(_operator != address(this));
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(_operator);
		liquidRon.updateOperator(_operator, true);
	}

	function test_admin_set_operator_fee(uint256 _amount) public {
		vm.assume(_amount < 1000);
		liquidRon.setOperatorFee(_amount);
		assertEq(liquidRon.operatorFee(), _amount);
	}

	function test_admin_revert_set_operator_fee(uint256 _amount) public {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(consensusAddrs[1]);
		liquidRon.setOperatorFee(_amount);
		vm.expectRevert("LiquidRon: Invalid fee");
		liquidRon.setOperatorFee(2000);
	}

	function test_admin_revert_deploy_staking_proxy(address _user) public {
		vm.assume(_user != address(this));
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(_user);
		liquidRon.deployStakingProxy();
	}

	function test_admin_deploy_staking_proxy() public {
		uint256 proxyCount = liquidRon.stakingProxyCount();
		liquidRon.deployStakingProxy();
		assertEq(liquidRon.stakingProxyCount(), proxyCount + 1);
	}

	function test_admin_fetch_operator_fee(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		uint256 total =  liquidRon.totalAssets();
		skip(86400 * 365);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		uint256 newTotal =  liquidRon.totalAssets();
		uint256 expectedYield = uint256(_amount) * 12 / 100;
		uint256 expectedFee = expectedYield * liquidRon.operatorFee() / liquidRon.BIPS();
		assertApproxEqAbs(newTotal - total, expectedYield - expectedFee, expectedYield / 1e9);
		uint256 operatorFee = liquidRon.operatorFeeAmount();
		uint256 pre = address(this).balance;
		liquidRon.fetchOperatorFee();
		assertEq(address(this).balance, pre + operatorFee);
	}

	function test_revert_fetch_fee_non_receiver(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		uint256 total =  liquidRon.totalAssets();
		skip(86400 * 365);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		uint256 newTotal =  liquidRon.totalAssets();
		uint256 expectedYield = uint256(_amount) * 12 / 100;
		uint256 expectedFee = expectedYield * liquidRon.operatorFee() / liquidRon.BIPS();
		assertApproxEqAbs(newTotal - total, expectedYield - expectedFee, expectedYield / 1e9);
		liquidRon.transferOwnership(address(wrappedRon));
		vm.prank(address(wrappedRon));
		vm.expectRevert("RonHelper: withdraw failed");
		liquidRon.fetchOperatorFee();
	}

	function test_revert_escrow_not_vault(address _user) public {
		vm.assume(_user != address(liquidRon));
		Escrow e = Escrow(liquidRon.escrow());
		vm.expectRevert(Escrow.ErrNotVault.selector);
		vm.prank(_user);
		e.deposit(1000 ether, _user);
	}

	receive() external payable {}
}