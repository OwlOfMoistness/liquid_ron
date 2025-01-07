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

	receive() external payable {}
}