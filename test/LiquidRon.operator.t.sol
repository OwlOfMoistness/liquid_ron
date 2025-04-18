// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LiquidRon, WithdrawalStatus, Pausable} from "../src/LiquidRon.sol";
import {LiquidProxy} from "../src/LiquidProxy.sol";
import {WrappedRon} from "../src/mock/WrappedRon.sol";
import {MockRonStaking} from "../src/mock/MockRonStaking.sol";
import {MockProfile} from "../src/mock/MockProfile.sol";
import {MockValidatorSet} from "../src/mock/MockValidatorSet.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/interfaces/draft-IERC6093.sol";

contract LiquidRonTest is Test {
	LiquidRon public liquidRon;
	WrappedRon public wrappedRon;
	MockRonStaking public mockRonStaking;
	MockProfile public mockProfile;
	MockValidatorSet public mockValidatorSet;

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
		skip(86400);
	}

	function test_delegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
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

	function test_revert_delegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = 0;
		}
		vm.expectRevert(LiquidRon.ErrNotZero.selector);
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
	}

	function test_revert_delegate_bad_proxy(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = 0;
		}
		vm.expectRevert(LiquidRon.ErrBadProxy.selector);
		liquidRon.delegateAmount(4, amounts, consensusAddrs);
	}

	function test_revert_insufficient_delegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++)
			amounts[i] = delegateAmount;
		vm.expectPartialRevert(IERC20Errors.ERC20InsufficientBalance.selector);
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
	}

	function test_harvest(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
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
		expectedYield -= expectedFee;
		assertApproxEqAbs(newTotal - total, expectedYield, expectedYield / 1e9);
	}

	function test_harvest_duration(uint88 _duration) public {
		vm.assume(_duration >= 1 days && _duration <= 10000 days);
		uint256 _amount = 10000 ether;
		liquidRon.deposit{value:_amount}(address(this));
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
		uint256 expectedFee = expectedYield * liquidRon.operatorFee() / liquidRon.BIPS();
		expectedYield -= expectedFee;
		assertApproxEqAbs(newTotal - total, expectedYield, expectedYield / 1e9);
	}

	function test_harvest_and_delegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
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
		uint256 expectedFee = expectedYield * liquidRon.operatorFee() / liquidRon.BIPS();
		assertTrue(newTotal - total >= expectedYield - expectedFee);
		uint256 c0 = mockRonStaking.getStakingAmount(consensusAddrs[0], liquidRon.stakingProxies(0));
		uint256 c3 = mockRonStaking.getStakingAmount(consensusAddrs[3], liquidRon.stakingProxies(0));
		assertTrue(c0 > c3);
	}

	function test_revert_3days_redelegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
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
		liquidRon.deposit{value:_amount}(address(this));
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
		expectedYield -= expectedYield * liquidRon.operatorFee() / liquidRon.BIPS(); 
		assertTrue(newTotal - total >= expectedYield);
	}

	function test_revert_redelegate_same_address(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
		uint256 delegateAmount = _amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		address[] memory srcs = new address[](2);
		address[] memory dsts = new address[](2);
		uint256[] memory ams = new uint256[](2);
		srcs[0] = consensusAddrs[0];
		srcs[1] = consensusAddrs[1];
		dsts[0] = consensusAddrs[0];
		dsts[1] = consensusAddrs[3];
		ams[0] = delegateAmount;
		ams[1] = delegateAmount;
		skip(86400 * 3 + 1);
		vm.expectRevert(LiquidProxy.ErrSameAddress.selector);
		liquidRon.redelegateAmount(0, ams, srcs, dsts);
	}

	function test_revert_redelegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
		uint256 delegateAmount = _amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		address[] memory srcs = new address[](2);
		address[] memory dsts = new address[](2);
		uint256[] memory ams = new uint256[](2);
		srcs[0] = consensusAddrs[0];
		srcs[1] = consensusAddrs[1];
		dsts[0] = consensusAddrs[2];
		dsts[1] = consensusAddrs[3];
		ams[0] = 0;
		ams[1] = 0;
		skip(86400 * 3 + 1);
		vm.expectRevert(LiquidRon.ErrNotZero.selector);
		liquidRon.redelegateAmount(0, ams, srcs, dsts);
	}

	function test_revert_undelegate(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		liquidRon.deposit{value:_amount}(address(this));
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
		liquidRon.deposit{value:_amount}(address(this));
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

	function test_operator_start_withdraw_process() public {
		uint256 amount = 10000 ether;
		liquidRon.deposit{value:amount}(address(this));
		uint256 delegateAmount = amount / 5;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		skip(86400 * 365 + 1);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.undelegateAmount(0, amounts, consensusAddrs);
		liquidRon.requestWithdrawal(liquidRon.balanceOf(address(this)) / 2, address(this));
		liquidRon.finaliseRonRewardsForEpoch();
		WithdrawalStatus status = liquidRon.statusPerEpoch(liquidRon.withdrawalEpoch() - 1);
		assertTrue(status == WithdrawalStatus.FINALISED);
	}

	function test_validator_array() public {
		uint256 _amount = 10 ether;
		liquidRon.deposit{value:_amount}(address(this));
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		assertEq(liquidRon.validatorCount(), 5);
		assertEq(liquidRon.getValidators(), idList);
	}

	function test_validator_array_consensus_change() public {
		uint256 _amount = 10 ether;
		liquidRon.deposit{value:_amount}(address(this));
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		assertEq(liquidRon.validatorCount(), 5);
		assertEq(liquidRon.getValidators(), idList);
		uint256 totalStaked = liquidRon.getTotalStaked();
		mockProfile.updateConsensus(idList[0], address(0xff00000000000000000000000000000000000001));
		vm.expectRevert();
		address[] memory oldConsensusAddrs = new address[](1);
		uint256[] memory newAmounts = new uint256[](1);
		newAmounts[0] = delegateAmount;
		oldConsensusAddrs[0] = consensusAddrs[0];
		liquidRon.delegateAmount(0, newAmounts, oldConsensusAddrs);
		assertEq(liquidRon.getTotalStaked(), totalStaked);
		address[] memory newConsensusAddrs = new address[](1);
		newConsensusAddrs[0] = 0xff00000000000000000000000000000000000001;
		liquidRon.delegateAmount(0, newAmounts, newConsensusAddrs);
		assertTrue(liquidRon.getTotalStaked() > totalStaked);
	}

	function test_validator_array_prune_no_change() public {
		uint256 _amount = 10 ether;
		liquidRon.deposit{value:_amount}(address(this));
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		liquidRon.delegateAmount(2, amounts, consensusAddrs);
		liquidRon.pruneValidatorList(0, 100);
		assertEq(liquidRon.validatorCount(), 5);
		assertEq(liquidRon.getValidators(), idList);
		skip(3 * 86400 + 1);
		liquidRon.undelegateAmount(0, amounts, consensusAddrs);
		liquidRon.pruneValidatorList(0, 100);
		assertEq(liquidRon.validatorCount(), 5);
		assertEq(liquidRon.getValidators(), idList);

		address[] memory srcs = new address[](2);
		address[] memory dsts = new address[](2);
		uint256[] memory ams = new uint256[](2);
		srcs[0] = consensusAddrs[2];
		srcs[1] = consensusAddrs[3];
		dsts[0] = consensusAddrs[0];
		dsts[1] = consensusAddrs[1];
		ams[0] = delegateAmount;
		ams[1] = delegateAmount;
		liquidRon.redelegateAmount(2, ams, srcs, dsts);
		assertEq(liquidRon.validatorCount(), 5);
		assertEq(liquidRon.getValidators(), idList);
	}

	function test_validator_array_prune() public {
		uint256 _amount = 10 ether;
		liquidRon.deposit{value:_amount}(address(this));
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		skip(3 * 86400 + 1);
		address[] memory p1 = new address[](1);
		address[] memory p2 = new address[](2);
		uint256[] memory am1 = new uint256[](1);
		uint256[] memory am2 = new uint256[](2);
		p1[0] = consensusAddrs[4];
		p2[0] = consensusAddrs[3];
		p2[1] = consensusAddrs[4];
		am1[0] = delegateAmount;
		am2[0] = delegateAmount;
		am2[1] = delegateAmount;
		liquidRon.undelegateAmount(0, am1, p1);
		liquidRon.undelegateAmount(1, am2, p2);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.pruneValidatorList(0, 100);
		assertEq(liquidRon.validatorCount(), 4);
		address[] memory exp = new address[](4);
		exp[0] = idList[0];
		exp[1] = idList[1];
		exp[2] = idList[2];
		exp[3] = idList[3];
		assertEq(liquidRon.getValidators(), exp);
	}

	function test_validator_array_prune_with_index() public {
		uint256 _amount = 10 ether;
		liquidRon.deposit{value:_amount}(address(this));
		uint256 delegateAmount = _amount / 17;
		uint256[] memory amounts = new uint256[](5);
		for (uint256 i = 0; i < 5; i++) {
			amounts[i] = delegateAmount;
		}
		liquidRon.delegateAmount(0, amounts, consensusAddrs);
		liquidRon.delegateAmount(1, amounts, consensusAddrs);
		skip(3 * 86400 + 1);
		address[] memory p1 = new address[](2);
		address[] memory p2 = new address[](2);
		uint256[] memory am1 = new uint256[](2);
		uint256[] memory am2 = new uint256[](2);
		p1[0] = consensusAddrs[1];
		p1[1] = consensusAddrs[2];
		p2[0] = consensusAddrs[1];
		p2[1] = consensusAddrs[2];
		am1[0] = delegateAmount;
		am1[1] = delegateAmount;
		am2[0] = delegateAmount;
		am2[1] = delegateAmount;
		liquidRon.undelegateAmount(0, am1, p1);
		liquidRon.undelegateAmount(1, am2, p2);
		liquidRon.harvest(0, consensusAddrs);
		liquidRon.harvest(1, consensusAddrs);
		liquidRon.pruneValidatorList(2, 2);
		assertEq(liquidRon.validatorCount(), 3);
		address[] memory exp = new address[](3);
		exp[0] = idList[0];
		exp[1] = idList[3];
		exp[2] = idList[4];
		assertEq(liquidRon.getValidators(), exp);
	} 

	function test_revert_only_operator() public {
		vm.expectRevert(LiquidRon.ErrInvalidOperator.selector);
		vm.prank(consensusAddrs[0]);
		liquidRon.harvest(0, consensusAddrs);
	}

	receive() external payable {}
}