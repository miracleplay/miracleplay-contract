// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'

pragma solidity ^0.8.17;

// Token
import "@thirdweb-dev/contracts/drop/DropERC1155.sol"; // For my collection of Node
import "@thirdweb-dev/contracts/token/TokenERC20.sol"; // For my ERC-20 Token contract

// Access Control + security
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./module/Miracle-Stake-Core.sol";

// CanbeatStakeDeca, CanbeatStakePeta, CanbeatStakeQuetta
contract FoundersStaking is StakeMiracleCore
{
    constructor(address _defaultAdmin, uint256 _stakingsection, DropERC1155 _NodeNFTToken, TokenERC20 _RewardToken, address _DaoAddress, uint256 _rewardPerMin, uint256 _alreadyClaimed) {
        StakingSection = _stakingsection;
        IStakingSection = _stakingsection - 1;
        
        NodeNftCollection = _NodeNFTToken;
        rewardsToken = _RewardToken;
        DaoAddress = _DaoAddress;
        rewardPerMin = _rewardPerMin;
        
        //Fee Definition
        DaoRoyalty = [5, 10, 15, 20];
        AgentRoyalty = 2;

        // Initialize this contract's state.
        PausePool = false;
        PauseClaim = false;
        _owner = _defaultAdmin;
        totalClaimed = _alreadyClaimed;
        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
    }

    // ===================================================================================
    // User Function 
    // ===================================================================================
    function stake(uint256 _depositAmount) external nonReentrant{
        _stake(msg.sender, _depositAmount, 0);
    }

    function withdraw(uint256 _withdrawAmount) external nonReentrant {
        _withdraw(msg.sender, _withdrawAmount);
    }

    function claim() external nonReentrant {
        _claim(msg.sender);
    }

    function claimAgent(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant{
        _claimAgent(_user);
    }

    function calculateTotalReward(address _user) external view returns (uint256 _totalReward) {
        _totalReward = _calculateToTalReward(_user);
    }

    function calculateRewards(address _user) external view returns (uint256 _MyReward, uint256 _DaoReward) {
        (_MyReward, _DaoReward) = _calculateRewards(_user);
    }

    function calculateAgentRewards(address _user) external view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _AgentReward) {
        (_PlayerReward, _DaoReward, _AgentReward) = _calculateAgentRewards(_user);
    }

    // ===================================================================================
    // Admin Function 
    // ===================================================================================
    function adminStake(address _user, uint256 _depositAmount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _stake(_user, _depositAmount, 0);
    }

    function adminWithdraw(address _user, uint256 _withdrawAmount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        _withdraw(_user, _withdrawAmount);
    }

    function updateClaimed(uint256 _totalClaimed) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        totalClaimed = _totalClaimed;
    }

    // ===================================================================================
    // View Function 
    // ===================================================================================
    function getStakePlayerCount() external view returns (uint256 _playerCount) {
        return _getStakePlayerCount();
    }

    function getStakePlayers() external view returns (address[] memory _stakeplayers){
        return _getStakePlayers();
    }

    function getTotalUnClaim() external view returns (uint256 _totalUnClaim) {
        return _getTotalUnClaim();
    }

    function getTotalCalimed() external view returns (uint256 _totalClaimed){
        return _getTotalClaimed();
    }
}