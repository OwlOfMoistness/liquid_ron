// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import {Test, console} from "forge-std/Test.sol";
import {LiquidRon, WithdrawalStatus, Pausable} from "../src/LiquidRon.sol";
import {WrappedRon} from "../src/mock/WrappedRon.sol";
import {MockRonStaking} from "../src/mock/MockRonStaking.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

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
		liquidRon = new LiquidRon(address(mockRonStaking), address(wrappedRon));
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
		liquidRon.deployStakingProxy();
	}

	function test_deposit(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		uint256 pre = wrappedRon.balanceOf(address(liquidRon));
		liquidRon.deposit{value:_amount}();
		assertEq(liquidRon.balanceOf(address(this)), _amount);
		assertEq(wrappedRon.balanceOf(address(liquidRon)), pre + _amount);
	}

	function test_deposit_no_func_call(uint88 _amount) public {
		vm.assume(_amount >= 0.01 ether);
		uint256 pre = wrappedRon.balanceOf(address(liquidRon));
		(bool res,) = payable(liquidRon).call{value:_amount}("");
		assertTrue(res);
		assertEq(liquidRon.balanceOf(address(this)), _amount);
		assertEq(wrappedRon.balanceOf(address(liquidRon)), pre + _amount);
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