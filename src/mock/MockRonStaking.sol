// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "../interfaces/IRoninValidators.sol";

contract MockRonStaking is IRoninValidator {
    uint256 public constant _3_DAYS = 3 days;
    // 12 * 10**16 / 365 days
    uint256 public constant RATE_PER_SECOND = 3805175038;

    mapping(address => mapping(address => uint256)) public stakingAmounts;
    mapping(address => mapping(address => uint256)) public pendingRewards;
    mapping(address => uint256) public totalStakingAmounts;
    mapping(address => mapping(address => uint256)) public lastAction;
    mapping(address => mapping(address => uint256)) public lastStakeAction;

    function _sync(address _consensusAddr, address _user) internal {
        uint256 timePassed = block.timestamp - lastAction[_consensusAddr][_user];
        uint256 stakingAmount = stakingAmounts[_consensusAddr][_user];
        uint256 rewards = (stakingAmount * RATE_PER_SECOND * timePassed) / 1e18;
        lastAction[_consensusAddr][_user] = block.timestamp;
        pendingRewards[_consensusAddr][_user] += rewards;
    }

    function delegate(address _consensusAddr) external payable {
        _sync(_consensusAddr, msg.sender);
        stakingAmounts[_consensusAddr][msg.sender] += msg.value;
        totalStakingAmounts[_consensusAddr] += msg.value;
        lastStakeAction[_consensusAddr][msg.sender] = block.timestamp;
    }

    function undelegate(address _consensusAddr, uint256 _amount) public {
        require(stakingAmounts[_consensusAddr][msg.sender] >= _amount, "MockRonStaking: insufficient staking amount");
        require(
            lastStakeAction[_consensusAddr][msg.sender] + _3_DAYS < block.timestamp,
            "MockRonStaking: must wait 3 days after last stake action"
        );

        _sync(_consensusAddr, msg.sender);
        stakingAmounts[_consensusAddr][msg.sender] -= _amount;
        totalStakingAmounts[_consensusAddr] -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "MockRonStaking: withdraw failed");
    }

    function redelegate(address _consensusAddrSrc, address _consensusAddrDst, uint256 amount) external {
        require(stakingAmounts[_consensusAddrSrc][msg.sender] >= amount, "MockRonStaking: insufficient staking amount");
        require(
            lastStakeAction[_consensusAddrSrc][msg.sender] + _3_DAYS < block.timestamp,
            "MockRonStaking: must wait 3 days after last stake action"
        );

        _sync(_consensusAddrSrc, msg.sender);
        _sync(_consensusAddrDst, msg.sender);
        stakingAmounts[_consensusAddrSrc][msg.sender] -= amount;
        totalStakingAmounts[_consensusAddrSrc] -= amount;
        stakingAmounts[_consensusAddrDst][msg.sender] += amount;
        totalStakingAmounts[_consensusAddrDst] += amount;
        lastStakeAction[_consensusAddrDst][msg.sender] = block.timestamp;
    }
    function bulkUndelegate(address[] calldata _consensusAddrs, uint256[] calldata _amounts) external {
        for (uint256 i = 0; i < _consensusAddrs.length; i++) {
            undelegate(_consensusAddrs[i], _amounts[i]);
        }
    }

    function _claimRewards(address[] calldata _consensusAddrs) internal returns (uint256 rewards) {
        for (uint256 i = 0; i < _consensusAddrs.length; i++) {
            _sync(_consensusAddrs[i], msg.sender);
            rewards += pendingRewards[_consensusAddrs[i]][msg.sender];
            pendingRewards[_consensusAddrs[i]][msg.sender] = 0;
        }
        return rewards;
    }

    function claimRewards(address[] calldata _consensusAddrs) external {
        uint256 rewards = _claimRewards(_consensusAddrs);
        //  maybe fetch from mock vesting?
        (bool success, ) = msg.sender.call{value: rewards}("");
        require(success, "MockRonStaking: claim rewards failed");
    }
    function delegateRewards(
        address[] calldata _consensusAddrs,
        address _consensusAddrDst
    ) external returns (uint256 rewards) {
        rewards = _claimRewards(_consensusAddrs);
        //  maybe fetch from mock vesting?
        _sync(_consensusAddrDst, msg.sender);
        stakingAmounts[_consensusAddrDst][msg.sender] += rewards;
        totalStakingAmounts[_consensusAddrDst] += rewards;
        lastStakeAction[_consensusAddrDst][msg.sender] = block.timestamp;
    }
    function getRewards(address _user, address[] calldata _consensusAddrs) external view returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](_consensusAddrs.length);
        for (uint256 i = 0; i < _consensusAddrs.length; i++) {
            rewards[i] = pendingRewards[_consensusAddrs[i]][_user];

            uint256 timePassed = block.timestamp - lastAction[_consensusAddrs[i]][_user];
            uint256 stakingAmount = stakingAmounts[_consensusAddrs[i]][_user];
            uint256 reward = (stakingAmount * RATE_PER_SECOND * timePassed) / 1e18;
            rewards[i] += reward;
        }
        return rewards;
    }

    function getReward(address _user, address _consensusAddr) external view returns (uint256) {
        uint256 timePassed = block.timestamp - lastAction[_consensusAddr][_user];
        uint256 stakingAmount = stakingAmounts[_consensusAddr][_user];
        uint256 reward = (stakingAmount * RATE_PER_SECOND * timePassed) / 1e18;
        return reward + pendingRewards[_consensusAddr][_user];
    }

    function getStakingTotal(address _consensusAddr) external view returns (uint256) {
        return totalStakingAmounts[_consensusAddr];
    }

    function getManyStakingTotals(address[] calldata _consensusAddrs) external view returns (uint256[] memory) {
        uint256[] memory totals = new uint256[](_consensusAddrs.length);
        for (uint256 i = 0; i < _consensusAddrs.length; i++) {
            totals[i] = totalStakingAmounts[_consensusAddrs[i]];
        }
        return totals;
    }

    function getStakingAmount(address _consensusAddr, address user) external view returns (uint256) {
        return stakingAmounts[_consensusAddr][user];
    }

    function getManyStakingAmounts(
        address[] calldata _consensusAddrs,
        address[] calldata userList
    ) external view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](userList.length);
        for (uint256 i = 0; i < userList.length; i++) {
            amounts[i] = stakingAmounts[_consensusAddrs[i]][userList[i]];
        }
        return amounts;
    }
    receive() external payable {}
}
