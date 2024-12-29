// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import {Test, console} from "forge-std/Test.sol";
import {LiquidRon, WithdrawalStatus, Pausable} from "../src/LiquidRon.sol";
import {WrappedRon} from "../src/mock/WrappedRon.sol";
import {ValidatorSet} from "../src/mock/ValidatorSet.sol";
import {MockRonStaking} from "../src/mock/MockRonStaking.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract LiquidRonTest is Test {
	LiquidRon public liquidRon;
	WrappedRon public wrappedRon;
	ValidatorSet public validatorSet;
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
		validatorSet = new ValidatorSet();
		validatorSet.addValidator(0xF000000000000000000000000000000000000001);
		validatorSet.addValidator(0xf000000000000000000000000000000000000002);
		validatorSet.addValidator(0xf000000000000000000000000000000000000003);
		validatorSet.addValidator(0xF000000000000000000000000000000000000004);
		validatorSet.addValidator(0xf000000000000000000000000000000000000005);
		wrappedRon = new WrappedRon();
		liquidRon = new LiquidRon(address(mockRonStaking), address(validatorSet), address(wrappedRon));
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
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

	function test_deposit(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		uint256 pre = wrappedRon.balanceOf(address(liquidRon));
		liquidRon.deposit{value:_amount}();
		assertEq(liquidRon.balanceOf(address(this)), _amount);
		assertEq(wrappedRon.balanceOf(address(liquidRon)), pre + _amount);
	}

	function test_delegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		uint256 totalAsset = liquidRon.totalAssets();
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		assertEq(liquidRon.totalAssets(), totalAsset);
	}

	function test_revert_insufficient_delegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++)
			amounts[i] = delegateAmount;
		vm.expectRevert("ERC20: burn amount exceeds balance");
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
	}

// 309_485_009.821345068724781052
	function test_harvest(uint88 _amount) public {
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
		assertApproxEqAbs(newTotal - total, expectedYield, expectedYield / 1e9);
	}

	function test_harvest_duration(uint88 _duration) public {
		vm.assume(_duration >= 1 days && _duration <= 10000 days);
		uint256 _amount = 10000 ether;
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
		skip(_duration);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		uint256 newTotal =  liquidRon.totalAssets();
		uint256 expectedYield = uint256(_amount) * uint256(_duration) * 12 / 100 / 365 / 86400;
		assertApproxEqAbs(newTotal - total, expectedYield, expectedYield / 1e9);
	}

	function test_harvest_and_delegate(uint88 _amount) public {
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
		skip(86400 * 365 + 1);
		liquidRon.harvestAndDelegateRewards(0, consensusAddrs, consensusAddrs[0]);
		liquidRon.harvestAndDelegateRewards(1, consensusAddrs, consensusAddrs[1]);
		liquidRon.harvestAndDelegateRewards(2, consensusAddrs, consensusAddrs[2]);
		uint256 newTotal =  liquidRon.totalAssets();
		uint256 expectedYield = uint256(_amount) * 12 / 100;
		assertTrue(newTotal - total >= expectedYield);
		uint256 c0 = mockRonStaking.stakingAmounts(consensusAddrs[0], liquidRon.stakingProxies(0));
		uint256 c3 = mockRonStaking.stakingAmounts(consensusAddrs[3], liquidRon.stakingProxies(0));
		assertTrue(c0 > c3);
	}

	function test_revert_3days_redelegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		vm.expectRevert("MockRonStaking: must wait 3 days after last stake action");
		address[] memory srcs = new address[](2);
		address[] memory dsts = new address[](2);
		uint256[] memory ams = new uint256[](2);
		srcs[0] = consensusAddrs[0];
		srcs[1] = consensusAddrs[1];
		dsts[0] = consensusAddrs[2];
		dsts[1] = consensusAddrs[3];
		ams[0] = delegateAmount;
		ams[1] = delegateAmount;
		liquidRon.redelegateAmount(0, ams, srcs, dsts);
	}

	function test_redelegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		uint256 total =  liquidRon.totalAssets();
		address[] memory srcs = new address[](2);
		address[] memory dsts = new address[](2);
		uint256[] memory ams = new uint256[](2);
		srcs[0] = consensusAddrs[0];
		srcs[1] = consensusAddrs[1];
		dsts[0] = consensusAddrs[2];
		dsts[1] = consensusAddrs[3];
		ams[0] = delegateAmount;
		ams[1] = delegateAmount;
		skip(86400 * 3 + 1);
		liquidRon.redelegateAmount(0, ams, srcs, dsts);
		uint256 newTotal =  liquidRon.totalAssets();
		uint256 expectedYield = uint256(_amount) * 3 * 12 / 100 / 365;
		assertTrue(newTotal - total >= expectedYield);
	}

	function test_revert_undelegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		vm.expectRevert("MockRonStaking: must wait 3 days after last stake action");
		address[] memory srcs = new address[](2);
		uint256[] memory ams = new uint256[](2);
		srcs[0] = consensusAddrs[0];
		srcs[1] = consensusAddrs[1];
		ams[0] = delegateAmount;
		ams[1] = delegateAmount;
		liquidRon.undelegateAmount(0, ams, srcs);
	}

	function test_undelegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		skip(86400 * 3 + 1);
		address[] memory srcs = new address[](1);
		uint256[] memory ams = new uint256[](1);
		srcs[0] = consensusAddrs[0];
		ams[0] = delegateAmount;
		liquidRon.undelegateAmount(0, amounts, consensusAddrs);
		uint256 rewards = liquidRon.getTotalRewards();
		uint256 stakedAndLying = liquidRon.getTotalStaked() + liquidRon.getAssetsInVault();
		assertEq(stakedAndLying, _amount);
		assertEq(rewards, liquidRon.totalAssets() - (stakedAndLying));
	}

	function test_withdraw_init(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}();
		uint256 delegateAmount = _amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.requestWithdrawal(liquidRon.balanceOf(address(this)));
		assertEq(liquidRon.balanceOf(address(this)), 0);
	}

	function test_operator_start_withdraw_process() public {
		uint256 amount = 10000 ether;
		liquidRon.deposit{value:amount}();
		uint256 delegateAmount = amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		skip(86400 * 365 + 1);
		liquidRon.requestWithdrawal(liquidRon.balanceOf(address(this)) / 2);
		liquidRon.initiateWithdrawalEpoch();
		WithdrawalStatus status = liquidRon.statusPerEpoch(liquidRon.withdrawalEpoch());
		assertTrue(status == WithdrawalStatus.INITIATED);
	}

	function test_revert_start_withdraw_process_user() public {
		uint256 amount = 10000 ether;
		liquidRon.deposit{value:amount}();
		uint256 delegateAmount = amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		skip(86400 * 365 + 1);
		liquidRon.requestWithdrawal(liquidRon.balanceOf(address(this)) / 2);
		liquidRon.initiateWithdrawalEpoch();
		WithdrawalStatus status = liquidRon.statusPerEpoch(liquidRon.withdrawalEpoch());
		assertTrue(status == WithdrawalStatus.INITIATED);
		uint256 bal = liquidRon.balanceOf(address(this));
		vm.expectRevert(LiquidRon.ErrWithdrawalProcessInitiated.selector);
		liquidRon.requestWithdrawal(bal / 2);
		vm.expectRevert(LiquidRon.ErrWithdrawalProcessNotFinalised.selector);
		liquidRon.redeem(0);
	}

	function test_revert_finalise_withdraw_process_operator() public {
		uint256 amount = 10000 ether;
		liquidRon.deposit{value:amount}();
		uint256 delegateAmount = amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		skip(86400 * 365 + 1);
		liquidRon.requestWithdrawal(liquidRon.balanceOf(address(this)) / 2);
		liquidRon.initiateWithdrawalEpoch();
		WithdrawalStatus status = liquidRon.statusPerEpoch(liquidRon.withdrawalEpoch());
		assertTrue(status == WithdrawalStatus.INITIATED);
		vm.expectRevert("ERC20: transfer amount exceeds balance");
		liquidRon.finaliseRonRewardsForEpoch();
	}


	function test_withdraw_process_user() public {
		uint256 amount = 100000 ether;
		liquidRon.deposit{value:amount}();
		uint256 delegateAmount = amount / 7;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		skip(86400 * 365 + 2 + 1);
		uint256 epoch = liquidRon.withdrawalEpoch();
		liquidRon.requestWithdrawal(200 ether);
		liquidRon.initiateWithdrawalEpoch();
		liquidRon.finaliseRonRewardsForEpoch();
		WithdrawalStatus status = liquidRon.statusPerEpoch(epoch);
		assertTrue(status == WithdrawalStatus.FINALISED);
		uint256 pre = address(this).balance;
		liquidRon.redeem(0);
		uint256 post = address(this).balance;
		assertTrue(post - pre > 200 ether);
		vm.expectRevert(LiquidRon.ErrRequestFulfilled.selector);
		liquidRon.redeem(0);
	}

	function test_overrides() public {
		liquidRon.mint(1, address(this));
		liquidRon.withdraw(1, address(this), address(this));
		liquidRon.redeem(1, address(this), address(this));
	}

	function test_revert_receiver_ron() public {
		liquidRon.requestWithdrawal(0);
		vm.prank(liquidRon.escrow());
		vm.expectRevert(LiquidRon.ErrCannotReceiveRon.selector);
		liquidRon.requestWithdrawal(0);
	}

	receive() external payable {}

}