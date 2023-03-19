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

// Access Control + security
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakeMiracle is ReentrancyGuard, PermissionsEnumerable
{
    // Store our two other contracts here (Edition Drop and Token)
    DropERC1155 public NodeNftCollection;
    TokenERC20 public rewardsToken;

    /// @dev Owner of the contract (purpose: OpenSea compatibility, etc.)
    address internal _owner;
    /// @dev The recipient of who gets the royalty.
    address public DaoAddress;
    /// @dev The percentage of royalty how much royalty in basis points.
    uint256[] internal DaoRoyalty;
    /// @dev The rewards rate is [_rewardPerMin] per 1 Min.
    uint256 public rewardPerMin;
    /// @dev Operation status of the Pool.
    bool public PausePool;
    /// @dev Operation claim of the Pool.
    bool public PauseClaim;
    /// @dev The user state of the Pool.
    struct StakeMap {
        bool isStake;
        uint256 updateTime;
        uint256 amount;
        uint256 poolID;
    }
    /// @dev for storing stakepool
    address[] StakingPool;
    /// @dev for storing stake user
    address[] StakePlayers;
    /// @dev Agent Claim Fees
    uint256 AgentRoyalty;
    /// @dev Pool Fees
    uint256 PoolRoyalty;
    /// @dev Node Section
    uint256 public StakingSection;
    uint256 internal IStakingSection;

    // @dev Mapping of player addresses to their NFT
    // By default, player has no NFT. They will not be in the mapping.
    mapping(address => StakeMap) public StakePlayer;

    // Multiply by 1000 for the decimal division calculation and divide 1000 after the operation is completed.
    uint256 private constant INVERSE_BASIS_POINT = 1000; //Using point

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return hasRole(DEFAULT_ADMIN_ROLE, _owner) ? _owner : address(0);
    }

    ///     =====   External functions  =====
    function _stake(uint256 _depositAmount, uint256 _poolID) internal {
        // Ensure the player has at least 1 of the token they are trying to stake
        require(_depositAmount > 0, "Please enter more than 0 staking amount.");
        require(NodeNftCollection.balanceOf(msg.sender, IStakingSection) >= _depositAmount, "You must have deposit amount node you are trying to stake");
        require(!PausePool, "Pool is in Pause state.");

        uint256 _tokenId = IStakingSection;
        uint256 _totalStakeAmount;
        // If they have a node already, add node and mint reward token.
        if (StakePlayer[msg.sender].isStake) {
            uint256 _nowAmount = StakePlayer[msg.sender].amount;
            _totalStakeAmount = _nowAmount + _depositAmount;

            // Calculate the rewards they are owed, and pay them out.
            if(!PauseClaim){
                // Calculate the rewards they are owed, and pay them out.
                _claim(msg.sender);
            }

        }else{
            //New Player
            StakePlayers.push(msg.sender);
            _totalStakeAmount = _depositAmount;
        }
              
        // Transfer using safeTransfer
        // Transfer the node to the contract
        NodeNftCollection.safeTransferFrom(msg.sender, address(this), _tokenId, _depositAmount, "Staking your node");

        // Update the StakePlayer mapping
        StakePlayer[msg.sender].isStake = true;
        StakePlayer[msg.sender].updateTime = block.timestamp;
        StakePlayer[msg.sender].poolID = _poolID;
        StakePlayer[msg.sender].amount = _totalStakeAmount;
    }

    function _withdraw(address _user, uint256 withdrawAmount) internal {
        // Ensure the player has a pickaxe
        require(StakePlayer[_user].isStake, "You do not have a node to withdraw.");
        require(!PausePool, "Pool is in Pause state.");
        
        uint256 nowAmount = StakePlayer[_user].amount;
        uint256 _totalAmount = nowAmount - withdrawAmount;
        require(_totalAmount > 0, "The withdrawal amount cannot be larger than the current staking amount.");

        NodeNftCollection.safeTransferFrom(address(this), _user, StakePlayer[_user].amount, withdrawAmount, "Returning your withdraw node");

        if(!PauseClaim){
            _claim(_user);
        }

        if (_totalAmount>0){
            // Update the StakePlayer mapping
            StakePlayer[_user].isStake = true;
            StakePlayer[_user].updateTime = block.timestamp;
            StakePlayer[_user].amount = _totalAmount;
        }else if(_totalAmount==0){
            // Remove StakePlayer
            removePlayer(_user);
            // Update the StakePlayer mapping
            StakePlayer[_user].isStake = false;
            StakePlayer[_user].updateTime = block.timestamp;
            StakePlayer[_user].amount = _totalAmount;
        }
    }

    function _claim(address _player) internal {
        require(!PausePool, "Pool is in Pause state.");
        require(!PauseClaim, "Claim is in Pause state.");

        // Calculate the rewards they are owed, and pay them out.
        (uint256 _MyReward, uint256 _DaoReward, uint _PoolReward) = _calculateRewards(_player);

        rewardsToken.mintTo(StakingPool[StakePlayer[_player].poolID], _PoolReward);
        rewardsToken.mintTo(_player, _MyReward);
        rewardsToken.mintTo(DaoAddress, _DaoReward);

        // Update the playerLastUpdate mapping
        StakePlayer[_player].updateTime = block.timestamp;
    }

    function _claimAgent(address _user) internal {
        require(!PausePool, "Pool is in Pause state.");
        require(!PauseClaim, "Claim is in Pause state.");

        // Calculate the rewards they are owed, and pay them out.
        (uint256 _MyReward, uint256 _DaoReward,  uint _PoolReward, uint256 _AgentReward) = _calculateAgentRewards(msg.sender);

        rewardsToken.mintTo(StakingPool[StakePlayer[_user].poolID], _PoolReward);
        rewardsToken.mintTo(_user, _MyReward);
        rewardsToken.mintTo(DaoAddress, _DaoReward);
        rewardsToken.mintTo(msg.sender, _AgentReward);
        
        // Update the playerLastUpdate mapping
        StakePlayer[_user].updateTime = block.timestamp;
    }

    // ===== Internal =====

    // Calculate the rewards the player is owed since last time they were paid out
    // This is calculated using block.timestamp and the playerLastUpdate.
    // If playerLastUpdate or playerNode is not set, then the player has no rewards.
    function _calculateToTalReward(address _player) internal view returns (uint256 _totalReward) {
        // Calculate the time difference between now and the last time they staked/withdrew/claimed their rewards
        uint256 timeDifference = block.timestamp - StakePlayer[_player].updateTime;
        // Calculate the rewards they are owed
        // R1, All NFT have the same value
        return _totalReward = (((timeDifference * rewardPerMin) * StakePlayer[_player].amount) * INVERSE_BASIS_POINT) / 60;
    }

    function _calculateRewards(address _player) internal view  returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward) {
        // If playerLastUpdate or playerNode is not set, then the player has no rewards.
        if (StakePlayer[_player].isStake == false) {
            return (0,0,0);
        }
        uint256 TotalRewards = _calculateToTalReward(_player);
        // Cal DAO Reward
        _DaoReward = ((TotalRewards * DaoRoyalty[IStakingSection]) / INVERSE_BASIS_POINT) / 100;
        // Cal Agent Reward
        _PoolReward = ((TotalRewards * PoolRoyalty) / INVERSE_BASIS_POINT) / 100;
        // Cal Player Reward
        _PlayerReward = (TotalRewards / INVERSE_BASIS_POINT) - (_DaoReward + _PoolReward);

        // Return the rewards
        return (_PlayerReward, _DaoReward, _PoolReward);
    }

    function _calculateAgentRewards(address _player) internal view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward, uint256 _AgentReward) {
        // If playerLastUpdate or playerNode is not set, then the player has no rewards.
        if (StakePlayer[_player].isStake == false) {
            return (0,0,0,0);
        }
        uint256 TotalRewards = _calculateToTalReward(_player);
        // Cal DAO Reward
        _DaoReward = ((TotalRewards * DaoRoyalty[StakingSection-1]) / INVERSE_BASIS_POINT) / 100;
        // Cal Agent Reward
        _PoolReward = ((TotalRewards * PoolRoyalty) / INVERSE_BASIS_POINT) / 100;
        // Cal Agent Reward
        _AgentReward = (TotalRewards * AgentRoyalty) / INVERSE_BASIS_POINT / 100;
        // Cal Player Reward
        _PlayerReward = (TotalRewards / INVERSE_BASIS_POINT) - (_DaoReward + _AgentReward + _PoolReward) ;

        // Return the rewards
        return (_PlayerReward, _DaoReward, _PoolReward, _AgentReward);
    }

    function removePlayer(address _user) internal
    {
        address[] memory _array = StakePlayers;
        for (uint i = 0; i < _array.length; i++) {
            if (_array[i] == _user) {
                StakePlayers[i] = _array[_array.length - 1];
                StakePlayers.pop();
                break;
            }
        }
    }

    //  =====   Setter functions  =====
    function setPausePoolStatus(bool status) external onlyRole(DEFAULT_ADMIN_ROLE){
        PausePool = status;
    }

    function setPauseClaimStatus(bool status) external onlyRole(DEFAULT_ADMIN_ROLE){
        PauseClaim = status;
    }

    function setrewardPerMin(uint256 _rewardPerMin) external onlyRole(DEFAULT_ADMIN_ROLE){
        rewardPerMin = _rewardPerMin;
    }

    function addStakingPool(address _poolAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        StakingPool.push(_poolAddress);
    }

    function editStakingPool(address _originAddress, address _newAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        for (uint256 i=0; i <StakingPool.length; i++)
        {
            if(StakingPool[i] == _originAddress)
            {
                StakingPool[i] = _newAddress;
                break;
            }
        }
    }


    //  =====   View  =====
    function _getStakePlayers() internal view returns (address[] memory) {
        return StakePlayers;
    }

    function _getStakingPool(uint256 _PoolSeq) internal view returns (address _poolAddress) {
        return StakingPool[_PoolSeq];
    }

    function _getStakePlayerCount() internal view returns (uint256 _playerCount) {
        return StakePlayers.length;
    }

    function _getTotalUnClaim() internal view returns (uint256 _totalUnClaim) {
        address[] memory _stakePlayers = StakePlayers;
        for(uint256 i = 0; i < _stakePlayers.length; i++)
        {   
            address _player = _stakePlayers[i];
            _totalUnClaim = _totalUnClaim + _calculateToTalReward(_player);
        }

        return _totalUnClaim;
    }

}