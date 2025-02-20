// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {LiquidRon, WithdrawalStatus, Pausable, RonHelper} from "../src/LiquidRon.sol";
import {LiquidProxy} from "../src/LiquidProxy.sol";
import {WrappedRon} from "../src/mock/WrappedRon.sol";
import {MockRonStaking} from "../src/mock/MockRonStaking.sol";
import {MockProfile} from "../src/mock/MockProfile.sol";
import {MockValidatorSet} from "../src/mock/MockValidatorSet.sol";
import {Escrow} from "../src/Escrow.sol";








contract LiquidRonTest is StdCheats,  Test {
	LiquidRon public liquidRon;
	WrappedRon public wrappedRon;
	MockRonStaking public mockRonStaking;
	MockProfile public mockProfile;
	MockValidatorSet public mockValidatorSet;

	address alice = address(0x01);

	address[] public consensusAddrs = [
			0xF000000000000000000000000000000000000001,
			0xf000000000000000000000000000000000000002,
			0xf000000000000000000000000000000000000003,
			0xF000000000000000000000000000000000000004,
			0xf000000000000000000000000000000000000005
	];
	address[] public idList = [
		address(0x01), 
		address(0x02), 
		address(0x03), 
		address(0x04), 
		address(0x05)
	];

	function setUp() public {
		mockValidatorSet = new MockValidatorSet();
		mockProfile = new MockProfile();
		mockRonStaking = new MockRonStaking(address(mockProfile));
		payable(address(mockRonStaking)).transfer(100_000_000 ether);
		wrappedRon = new WrappedRon();
		mockProfile.registerMany(idList, consensusAddrs);
		liquidRon = new LiquidRon(address(mockRonStaking), address(mockProfile), address(mockValidatorSet), address(wrappedRon), 250, address(this), "Test", "TST");
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
		skip(86400 * 3);
	}

	function test_fee_stacked_balance() public {
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		uint256 period = mockValidatorSet.currentPeriod();
		skip(86400);
		period = mockValidatorSet.currentPeriod();
		assertTrue(liquidRon.stakedBalance(period) == 0);
		liquidRon.harvest(0, consensusAddrs);
		assertTrue(liquidRon.stakedBalance(period) == _amount);
		assertEq(liquidRon.indexTracker(period), 1);
		liquidRon.harvest(1, consensusAddrs);
		assertEq(liquidRon.indexTracker(period), 3);
		liquidRon.harvest(2, consensusAddrs);
		assertEq(liquidRon.indexTracker(period), 7);
	}

	function test_fee_index_tracker() public {
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		uint256 period = mockValidatorSet.currentPeriod();
		skip(86400);
		period = mockValidatorSet.currentPeriod();
		liquidRon.harvest(0, consensusAddrs);
		assertEq(liquidRon.indexTracker(period), 1);
		liquidRon.harvest(1, consensusAddrs);
		assertEq(liquidRon.indexTracker(period), 3);
		liquidRon.harvest(2, consensusAddrs);
		assertEq(liquidRon.indexTracker(period), 7);
	}

	function test_update_valid_period() public {
		uint256 _amount = 1000000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		assertTrue(liquidRon.latestValidLoggedPeriod() == 0);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		assertTrue(liquidRon.latestValidLoggedPeriod() == 0);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		assertTrue(liquidRon.latestValidLoggedPeriod() > 0);
	}

	function test_fee_rewards(uint256 _depositAmount) public {
		// _depositAmount = bound(uint256(_depositAmount), uint256(1e18), uint256(2 ** 128));
		_depositAmount = bound(_depositAmount, 1e18, 2 ** 128);
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		skip(86400);
		uint256 period = mockValidatorSet.currentPeriod();
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		assertEq(liquidRon.getDepositFee(1000 ether), 0);
		uint256 rewards = liquidRon.rewardsClaimed(period);
		uint256 expectedYield = uint256(_amount) * 12 / 100 / 365;
		uint256 expectedOperatorFee = expectedYield * liquidRon.operatorFee() / liquidRon.BIPS();
		expectedYield -= expectedOperatorFee;
		assertApproxEqAbs(rewards, expectedYield, expectedYield / 1e9);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		uint256 valid = liquidRon.latestValidLoggedPeriod();
		uint256 expectedFee = liquidRon.rewardsClaimed(valid) * _depositAmount / (liquidRon.stakedBalance(valid - 1) + _depositAmount);
		assertTrue(liquidRon.getDepositFee(_depositAmount) == expectedFee);
	}

	function test_fee_on_mint(uint256 _depositAmount) public {
		_depositAmount = bound(_depositAmount, 1e18, 1000000000 ether);
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		vm.deal(alice, _depositAmount * 2);
		vm.startPrank(alice);
		wrappedRon.deposit{value: _depositAmount * 2}();
		wrappedRon.approve(address(liquidRon), UINT256_MAX);
		uint256 expectedAssets = liquidRon.previewMint(_depositAmount);
		vm.stopPrank();
		liquidRon.setDepositFeeEnabled(false);
		uint256 expectedAssetsWithoutFee = liquidRon.previewMint(_depositAmount);
		liquidRon.setDepositFeeEnabled(true);
		vm.startPrank(alice);
		uint256 expectedFee = liquidRon.getDepositFee(expectedAssetsWithoutFee);
		uint256 wronBal = wrappedRon.balanceOf(alice);
		uint256 assets = liquidRon.mint(_depositAmount, alice);
		uint256 wronBalAfter = wrappedRon.balanceOf(alice);
		assertEq(expectedFee, wronBal - wronBalAfter - expectedAssetsWithoutFee);
		assertEq(expectedAssets, assets);
	}

	function test_fee_on_deposit(uint256 _depositAmount) public {
		_depositAmount = bound(_depositAmount, 1e18, 1000000000 ether);
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		uint256 valid = liquidRon.latestValidLoggedPeriod();
		uint256 expectedFee = liquidRon.rewardsClaimed(valid) * _depositAmount / (liquidRon.stakedBalance(valid - 1) + _depositAmount);
		assertTrue(liquidRon.getDepositFee(_depositAmount) == expectedFee);
		vm.deal(alice, _depositAmount);
		vm.startPrank(alice);
		wrappedRon.deposit{value: _depositAmount}();
		wrappedRon.approve(address(liquidRon), UINT256_MAX);
		uint256 expectedShares = liquidRon.previewDeposit(_depositAmount);
		vm.stopPrank();
		liquidRon.setDepositFeeEnabled(false);
		uint256 expectedSharesWithoutFee = liquidRon.previewDeposit(_depositAmount);
		liquidRon.setDepositFeeEnabled(true);
		vm.startPrank(alice);
		expectedFee = liquidRon.getDepositFee(_depositAmount);
		uint256 shares = liquidRon.deposit(_depositAmount, alice);
		uint256 feeInAssets = expectedFee * expectedSharesWithoutFee / _depositAmount;
		assertEq(feeInAssets, expectedSharesWithoutFee - shares);
		assertEq(expectedShares, shares);
	}

	function test_fee_on_deposit_payable(uint256 _depositAmount) public {
		_depositAmount = bound(_depositAmount, 1e18, 1000000000 ether);
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		uint256 valid = liquidRon.latestValidLoggedPeriod();
		uint256 expectedFee = liquidRon.rewardsClaimed(valid) * _depositAmount / (liquidRon.stakedBalance(valid - 1) + _depositAmount);
		assertTrue(liquidRon.getDepositFee(_depositAmount) == expectedFee);
		vm.deal(alice, _depositAmount);
		vm.startPrank(alice);
		uint256 expectedShares = liquidRon.previewDeposit(_depositAmount);
		vm.stopPrank();
		liquidRon.setDepositFeeEnabled(false);
		uint256 expectedSharesWithoutFee = liquidRon.previewDeposit(_depositAmount);
		liquidRon.setDepositFeeEnabled(true);
		vm.startPrank(alice);
		expectedFee = liquidRon.getDepositFee(_depositAmount);
		uint256 shares = liquidRon.deposit{value:_depositAmount}();
		uint256 feeInAssets = expectedFee * expectedSharesWithoutFee / _depositAmount;
		assertEq(feeInAssets, expectedSharesWithoutFee - shares);
		assertEq(expectedShares, shares);
	}

	function test_fee_removed_after_threshold(uint256 _depositCount) public {
		_depositCount = bound(_depositCount, 1, 20);
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.setDepositFeeEnabled(true);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		skip(86400);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		uint256 valid = liquidRon.latestValidLoggedPeriod();
		vm.deal(alice, 10000000 ether);
		vm.startPrank(alice);
		uint256 expectedRewards = liquidRon.rewardsClaimed(valid) * liquidRon.stakedBalance(valid)  / (liquidRon.stakedBalance(valid - 1));

		uint256 depositAmount = _amount / _depositCount;
		uint256 tracker;

		uint256 currentPeriod = mockValidatorSet.currentPeriod();
		for (uint256 i = 0; i < _depositCount + 2; i++) {
			liquidRon.deposit{value: depositAmount}();
			tracker = liquidRon.loggedFees(currentPeriod);
		}
		console.log("tracker", tracker);
		console.log("expectedRewards", expectedRewards);
		assertTrue(tracker >= expectedRewards);
		assertTrue(liquidRon.getDepositFee(100000 ether) == 0);
		skip(86400);
		vm.stopPrank();
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.harvest(2, consensusAddrs);
		assertTrue(liquidRon.getDepositFee(100000 ether) > 0);
	}

	function test_fee_decrease_staked_balance() public {
		uint256 _amount = 1500000 ether;
		liquidRon.deposit{value: _amount}();
		uint256 delegateAmount = _amount / 15;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.harvest(0, consensusAddrs);
		assertEq(liquidRon.stakedBalance(mockValidatorSet.currentPeriod()), _amount);
		skip(86400 * 3 + 1);
		liquidRon.harvest(0, consensusAddrs);
		assertEq(liquidRon.stakedBalance(mockValidatorSet.currentPeriod()), _amount);
		liquidRon.undelegateAmount(0, amounts, consensusAddrs);
		assertEq(liquidRon.stakedBalance(mockValidatorSet.currentPeriod()), _amount * 2 / 3);
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		assertEq(liquidRon.stakedBalance(mockValidatorSet.currentPeriod()), _amount * 2 / 3);
	}
}