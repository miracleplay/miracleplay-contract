// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/
pragma solidity ^0.8.17;

// Token
import "@thirdweb-dev/contracts/drop/DropERC1155.sol"; // For my collection of Node
import "@thirdweb-dev/contracts/token/TokenERC20.sol"; // For my ERC-20 Token contract
import "@thirdweb-dev/contracts/openzeppelin-presets/utils/ERC1155/ERC1155Holder.sol";

// Access Control + security
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./module/SLG-Miralce-Stake.sol";

contract IStakeMiracle is StakeMiracle
{
    constructor(address _defaultAdmin, uint256 _stakingsection, DropERC1155 _NodeNFTToken, TokenERC20 _RewardToken, address _DaoAddress, uint256 _rewardPerMin) {
        StakingSection = _stakingsection;
        IStakingSection = _stakingsection - 1;
        
        NodeNftCollection = _NodeNFTToken;
        rewardsToken = _RewardToken;
        DaoAddress = _DaoAddress;
        rewardPerMin = _rewardPerMin;
        
        //Fee Definition
        DaoRoyalty = [10, 15, 20, 25, 30, 35, 40, 45, 50];
        PoolRoyalty = 5;
        AgentRoyalty = 2;

        // Initialize this contract's state.
        PausePool = false;
        PauseClaim = false;
        _owner = _defaultAdmin;
        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    function stake(uint256 _depositAmount, uint256 _poolID) external nonReentrant{
        _stake(_depositAmount, _poolID);
    }

    function withdraw(uint256 _withdrawAmount) external nonReentrant {
        _withdraw(msg.sender, _withdrawAmount);
    }

    function withdrawUser(address _user, uint256 _withdrawAmount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _withdraw(_user, _withdrawAmount);
    }

    function claim() external nonReentrant {
        _claim(msg.sender);
    }

    function claimAgent(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant{
        _claimAgent(_user);
    }

    function calculateRewards() external view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward) {
        return _calculateRewards(msg.sender);
    }

    function calculateAgentRewards() external view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward, uint256 _AgentReward) {
        return _calculateAgentRewards(msg.sender);
    }

}