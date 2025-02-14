// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "../interfaces/IRoninValidators.sol";
import "../interfaces/IProfile.sol";

contract MockRonStaking is IRoninValidator {
    uint256 public constant _3_DAYS = 3 days;
    // 12 * 10**16 / 365 days
    uint256 public constant RATE_PER_SECOND = 3805175038;

    mapping(address => mapping(address => uint256)) internal stakingAmounts;
    mapping(address => mapping(address => uint256)) internal pendingRewards;
    mapping(address => uint256) internal totalStakingAmounts;
    mapping(address => mapping(address => uint256)) internal lastAction;
    mapping(address => mapping(address => uint256)) internal lastStakeAction;
    address profile;

    constructor(address _profile) {
        profile = _profile;
    }

    function _sync(address _id, address _user) internal {
        uint256 timePassed = block.timestamp - lastAction[_id][_user];
        uint256 stakingAmount = stakingAmounts[_id][_user];
        uint256 rewards = (stakingAmount * RATE_PER_SECOND * timePassed) / 1e18;
        lastAction[_id][_user] = block.timestamp;
        pendingRewards[_id][_user] += rewards;
    }

    function delegate(address _consensusAddr) external payable {
        address id = IProfile(profile).getConsensus2Id(_consensusAddr);
        _sync(id, msg.sender);
        stakingAmounts[id][msg.sender] += msg.value;
        totalStakingAmounts[id] += msg.value;
        lastStakeAction[id][msg.sender] = block.timestamp;
    }

    function undelegate(address _consensusAddr, uint256 _amount) public {
        address id = IProfile(profile).getConsensus2Id(_consensusAddr);
        require(stakingAmounts[id][msg.sender] >= _amount, "MockRonStaking: insufficient staking amount");
        require(
            lastStakeAction[id][msg.sender] + _3_DAYS < block.timestamp,
            "MockRonStaking: must wait 3 days after last stake action"
        );

        _sync(id, msg.sender);
        stakingAmounts[id][msg.sender] -= _amount;
        totalStakingAmounts[id] -= _amount;
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "MockRonStaking: withdraw failed");
    }

    function redelegate(address _consensusAddrSrc, address _consensusAddrDst, uint256 amount) external {
        address idSrc = IProfile(profile).getConsensus2Id(_consensusAddrSrc);
        address idDst = IProfile(profile).getConsensus2Id(_consensusAddrDst);
        require(stakingAmounts[idSrc][msg.sender] >= amount, "MockRonStaking: insufficient staking amount");
        require(
            lastStakeAction[idDst][msg.sender] + _3_DAYS < block.timestamp,
            "MockRonStaking: must wait 3 days after last stake action"
        );

        _sync(idSrc, msg.sender);
        _sync(idDst, msg.sender);
        stakingAmounts[idSrc][msg.sender] -= amount;
        totalStakingAmounts[idSrc] -= amount;
        stakingAmounts[idDst][msg.sender] += amount;
        totalStakingAmounts[idDst] += amount;
        lastStakeAction[idDst][msg.sender] = block.timestamp;
    }

    function bulkUndelegate(address[] calldata _consensusAddrs, uint256[] calldata _amounts) external {
        for (uint256 i = 0; i < _consensusAddrs.length; i++) {
            undelegate(_consensusAddrs[i], _amounts[i]);
        }
    }

    function _claimRewards(address[] memory _ids) internal returns (uint256 rewards) {
        for (uint256 i = 0; i < _ids.length; i++) {
            _sync(_ids[i], msg.sender);
            rewards += pendingRewards[_ids[i]][msg.sender];
            pendingRewards[_ids[i]][msg.sender] = 0;
        }
        return rewards;
    }

    function claimRewards(address[] calldata _consensusAddrs) external {
        address[] memory ids = IProfile(profile).getManyConsensus2Id(_consensusAddrs);

        uint256 rewards = _claimRewards(ids);
        //  maybe fetch from mock vesting?
        (bool success, ) = msg.sender.call{value: rewards}("");
        require(success, "MockRonStaking: claim rewards failed");
    }
    function delegateRewards(
        address[] calldata _consensusAddrs,
        address _consensusAddrDst
    ) external returns (uint256 rewards) {
        address[] memory ids = IProfile(profile).getManyConsensus2Id(_consensusAddrs);
        address idDst = IProfile(profile).getConsensus2Id(_consensusAddrDst);
        rewards = _claimRewards(ids);
        //  maybe fetch from mock vesting?
        _sync(idDst, msg.sender);
        stakingAmounts[idDst][msg.sender] += rewards;
        totalStakingAmounts[idDst] += rewards;
        lastStakeAction[idDst][msg.sender] = block.timestamp;
    }
    function getRewards(address _user, address[] calldata _consensusAddrs) external view returns (uint256[] memory) {
        address[] memory ids = IProfile(profile).getManyConsensus2Id(_consensusAddrs);
        uint256[] memory rewards = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            rewards[i] = pendingRewards[ids[i]][_user];

            uint256 timePassed = block.timestamp - lastAction[ids[i]][_user];
            uint256 stakingAmount = stakingAmounts[ids[i]][_user];
            uint256 reward = (stakingAmount * RATE_PER_SECOND * timePassed) / 1e18;
            rewards[i] += reward;
        }
        return rewards;
    }

    function getReward(address _consensusAddr, address _user) external view returns (uint256) {
        address id = IProfile(profile).getConsensus2Id(_consensusAddr);
        uint256 timePassed = block.timestamp - lastAction[id][_user];
        uint256 stakingAmount = stakingAmounts[id][_user];
        uint256 reward = (stakingAmount * RATE_PER_SECOND * timePassed) / 1e18;
        return reward + pendingRewards[id][_user];
    }

    function getStakingTotal(address _consensusAddr) external view returns (uint256) {
        address id = IProfile(profile).getConsensus2Id(_consensusAddr);
        return totalStakingAmounts[id];
    }

    function getManyStakingTotals(address[] calldata _consensusAddrs) external view returns (uint256[] memory) {
        address[] memory ids = IProfile(profile).getManyConsensus2Id(_consensusAddrs);
        uint256[] memory totals = new uint256[](_consensusAddrs.length);
        for (uint256 i = 0; i < ids.length; i++) {
            totals[i] = totalStakingAmounts[ids[i]];
        }
        return totals;
    }

    function getStakingAmount(address _consensusAddr, address user) external view returns (uint256) {
        address id = IProfile(profile).getConsensus2Id(_consensusAddr);
        return stakingAmounts[id][user];
    }

    function getManyStakingAmounts(
        address[] calldata _consensusAddrs,
        address[] calldata userList
    ) external view returns (uint256[] memory) {
        address[] memory ids = IProfile(profile).getManyConsensus2Id(_consensusAddrs);
        uint256[] memory amounts = new uint256[](userList.length);
        for (uint256 i = 0; i < userList.length; i++) {
            amounts[i] = stakingAmounts[ids[i]][userList[i]];
        }
        return amounts;
    }
    receive() external payable {}
}
