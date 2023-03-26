// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/
pragma solidity ^0.8.17;

// Token
import "@thirdweb-dev/contracts/drop/DropERC1155.sol";
import "@thirdweb-dev/contracts/token/TokenERC20.sol";
import "@thirdweb-dev/contracts/openzeppelin-presets/utils/ERC1155/ERC1155Holder.sol";

// Access Control + security
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakeMiracleCore is ReentrancyGuard, PermissionsEnumerable, ERC1155Holder
{
    DropERC1155 public NodeNftCollection;    // The DropERC1155 contract instance for the Node NFT collection.
    TokenERC20 public rewardsToken;          // The TokenERC20 contract instance for the reward token.

    address internal _owner;                // The owner address of the contract.
    address internal DaoAddress;            // The DAO address for collecting DAO royalties.
    uint256[] internal DaoRoyalty;          // An array of royalty percentages for the DAO.
    uint256 public rewardPerMin;            // The reward rate per minute for staking.
    bool public PausePool;                  // A flag to pause the staking pool.
    bool public PauseClaim;                 // A flag to pause the claim function.
    struct StakeMap {                       // A struct to store staking details for each user.
        bool isStake;                       // A flag to indicate if the user is staking.
        uint256 updateTime;                 // The timestamp when the user last staked or unstaked.
        uint256 amount;                     // The amount of tokens staked by the user.
        uint256 poolID;                     // The ID of the staking pool where the user has staked.
    }
    address[] StakingPool;                  // An array of staking pool contract addresses.
    address[] StakePlayers;                 // An array of addresses of all users who have staked.
    uint256 AgentRoyalty;                   // The royalty percentage for the agent.
    uint256 PoolRoyalty;                    // The royalty percentage for the pool.
    uint256 public StakingSection;          // The section ID of the staking pool.
    uint256 internal IStakingSection;       // An internal variable to store the staking section ID.
    uint256 totalClaimed;                   // The total amount of rewards claimed by users.

    mapping(address => StakeMap) public StakePlayer;  // A mapping to store staking details for each user.

    uint256 private constant INVERSE_BASIS_POINT = 1000;  // A constant to represent one basis point as a fraction.

    event Staked(address indexed user, uint256 _amount);        // An event emitted when a user stakes tokens.
    event unStaked(address indexed user, uint256 _amount);      // An event emitted when a user unstakes tokens.
    event RewardPaid(address indexed user, uint256 _userReward, uint256 _daoReward, uint256 _poolReward, uint256 _agentReward);  // An event emitted when a user claims their rewards.
    
    /*///////////////////////////////////////////////////////////////
                           External Function
    //////////////////////////////////////////////////////////////*/
    /**
    * @dev A function to get the owner address of the contract.
    * @return The owner address of the contract.
    */
    function owner() public view returns (address) {
        return hasRole(DEFAULT_ADMIN_ROLE, _owner) ? _owner : address(0);
    }

    /**
    * @dev A function to stake tokens.
    * @param _depositAmount The amount of tokens to stake.
    * @param _poolID The ID of the staking pool where the tokens will be staked.
    */
    function _stake(address _user, uint256 _depositAmount, uint256 _poolID) internal {
        require(_depositAmount > 0, "Please enter more than 0 staking amount."); // @dev The deposit amount must be greater than 0.
        require(NodeNftCollection.balanceOf(_user, IStakingSection) >= _depositAmount, "You must have deposit amount node you are trying to stake"); // @dev The user must have enough balance of the node to be staked.
        require(!PausePool, "Pool is in Pause state."); // @dev The staking pool must not be paused.

        uint256 _tokenId = IStakingSection;
        uint256 _totalStakeAmount;

        if (StakePlayer[_user].isStake) { // @dev If the user has already staked tokens.
            uint256 _nowAmount = StakePlayer[_user].amount;
            _totalStakeAmount = _nowAmount + _depositAmount;

            if(!PauseClaim){
                _claim(_user); // @dev The user's rewards are claimed before the tokens are staked again.
            }

        }else{ // @dev If the user has not staked any tokens before.
            StakePlayers.push(_user);
            _totalStakeAmount = _depositAmount;
        }
                
        NodeNftCollection.safeTransferFrom(_user, address(this), _tokenId, _depositAmount, "Staking your node"); // @dev Transfer the tokens from the user to the staking pool contract.

        StakePlayer[_user].isStake = true;
        StakePlayer[_user].updateTime = block.timestamp;
        StakePlayer[_user].poolID = _poolID;
        StakePlayer[_user].amount = _totalStakeAmount;

        emit Staked(_user, _depositAmount); // @dev Emit an event for the stake action.
    }

    /**
    * @dev A function to withdraw staked tokens.
    * @param _user The address of the user who wants to withdraw tokens.
    * @param withdrawAmount The amount of tokens to withdraw.
    */
    function _withdraw(address _user, uint256 withdrawAmount) internal {
        require(StakePlayer[_user].isStake, "You do not have a node to withdraw."); // @dev The user must have staked tokens.
        require(!PausePool, "Pool is in Pause state."); // @dev The staking pool must not be paused.
            
        uint256 nowAmount = StakePlayer[_user].amount;
        uint256 _totalAmount = nowAmount - withdrawAmount;
        require(_totalAmount >= 0, "The withdrawal amount cannot be larger than the current staking amount."); // @dev The withdrawal amount cannot be greater than the current staking amount.

        NodeNftCollection.safeTransferFrom(address(this), _user, IStakingSection, withdrawAmount, "Returning your withdraw node"); // @dev Transfer the tokens back to the user.

        if(!PauseClaim){
            _claim(_user); // @dev Claim the user's rewards before withdrawing the tokens.
        }

        if (_totalAmount>0){ // @dev If the user still has some tokens staked.
            StakePlayer[_user].isStake = true;
            StakePlayer[_user].updateTime = block.timestamp;
            StakePlayer[_user].amount = _totalAmount;
        }else if(_totalAmount==0){ // @dev If the user has withdrawn all their tokens.
            removePlayer(_user); // @dev Remove the user from the stakers list.
            StakePlayer[_user].isStake = false;
            StakePlayer[_user].updateTime = block.timestamp;
            StakePlayer[_user].amount = _totalAmount;
        }

        emit unStaked(_user, withdrawAmount); // @dev Emit an event for the withdraw action.
    }

    /**
    * @dev A function to claim rewards for staking.
    * @param _user The address of the user who wants to claim their rewards.
    */
    function _claim(address _user) internal {
        require(!PausePool, "Pool is in Pause state."); // @dev The staking pool must not be paused.
        require(!PauseClaim, "Claim is in Pause state."); // @dev The claim function must not be paused.

        (uint256 _MyReward, uint256 _DaoReward, uint _PoolReward) = _calculateRewards(_user); // @dev Calculate the rewards for the user.

        rewardsToken.mintTo(StakingPool[StakePlayer[_user].poolID], _PoolReward); // @dev Mint the staking pool's share of the rewards to the staking pool contract.
        rewardsToken.mintTo(_user, _MyReward); // @dev Mint the user's share of the rewards to their account.
        rewardsToken.mintTo(DaoAddress, _DaoReward); // @dev Mint the DAO's share of the rewards to the DAO contract.

        StakePlayer[_user].updateTime = block.timestamp; // @dev Update the last claimed time for the user.
        totalClaimed = totalClaimed + _MyReward + _DaoReward + _PoolReward;
        emit RewardPaid(_user, _MyReward, _DaoReward, _PoolReward, 0); // @dev Emit an event for the reward payment.
    }

    /**
    * @dev A function to claim agent rewards for staking.
    * @param _user The address of the user who wants to claim their agent rewards.
    */
    function _claimAgent(address _user) internal {
        require(!PausePool, "Pool is in Pause state."); // @dev The staking pool must not be paused.
        require(!PauseClaim, "Claim is in Pause state."); // @dev The claim function must not be paused.

        (uint256 _PlayerReward, uint256 _DaoReward,  uint _PoolReward, uint256 _AgentReward) = _calculateAgentRewards(msg.sender); // @dev Calculate the rewards for the agent.

        rewardsToken.mintTo(StakingPool[StakePlayer[_user].poolID], _PoolReward); // @dev Mint the staking pool's share of the rewards to the staking pool contract.
        rewardsToken.mintTo(_user, _PlayerReward); // @dev Mint the user's share of the rewards to their account.
        rewardsToken.mintTo(DaoAddress, _DaoReward); // @dev Mint the DAO's share of the rewards to the DAO contract.
        rewardsToken.mintTo(msg.sender, _AgentReward); // @dev Mint the agent's share of the rewards to the agent's account.

        StakePlayer[_user].updateTime = block.timestamp; // @dev Update the last claimed time for the user.
        totalClaimed = totalClaimed + _PoolReward + _PlayerReward + _DaoReward + _PoolReward;
        emit RewardPaid(_user, _PlayerReward, _DaoReward, _PoolReward, _AgentReward); // @dev Emit an event for the reward payment.
    }

    /*///////////////////////////////////////////////////////////////
                           Internal Function
    //////////////////////////////////////////////////////////////*/
    /**
    * @dev A function to calculate the total rewards for a staker.
    * @param _player The address of the staker.
    * @return _totalReward The total rewards for the staker.
    */
    function _calculateToTalReward(address _player) internal view returns (uint256 _totalReward) {
        uint256 timeDifference = block.timestamp - StakePlayer[_player].updateTime; // @dev Calculate the time difference between the last claimed time and the current time.
        return _totalReward = (((timeDifference * rewardPerMin) * StakePlayer[_player].amount) * INVERSE_BASIS_POINT) / 60; // @dev Calculate the total rewards for the staker.
    }

    /**
    * @dev A function to calculate the rewards for a staker.
    * @param _player The address of the staker.
    * @return _PlayerReward The rewards for the staker.
    * @return _DaoReward The rewards for the DAO.
    * @return _PoolReward The rewards for the staking pool.
    */
    function _calculateRewards(address _player) internal view  returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward) {
        if (StakePlayer[_player].isStake == false) { // @dev If the staker has not staked any tokens, return 0 rewards.
            return (0,0,0);
        }
        uint256 TotalRewards = _calculateToTalReward(_player); // @dev Calculate the total rewards for the staker.
        _DaoReward = ((TotalRewards * DaoRoyalty[IStakingSection]) / INVERSE_BASIS_POINT) / 100; // @dev Calculate the DAO's share of the rewards.
        _PoolReward = ((TotalRewards * PoolRoyalty) / INVERSE_BASIS_POINT) / 100; // @dev Calculate the staking pool's share of the rewards.
        _PlayerReward = (TotalRewards / INVERSE_BASIS_POINT) - (_DaoReward + _PoolReward); // @dev Calculate the staker's share of the rewards.

        return (_PlayerReward, _DaoReward, _PoolReward);
    }

    /**
    * @dev A function to calculate the agent rewards for a staker.
    * @param _player The address of the staker.
    * @return _PlayerReward The rewards for the staker.
    * @return _DaoReward The rewards for the DAO.
    * @return _PoolReward The rewards for the staking pool.
    * @return _AgentReward The rewards for the agent.
    */
    function _calculateAgentRewards(address _player) internal view returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward, uint256 _AgentReward) {
        if (StakePlayer[_player].isStake == false) { // @dev If the staker has not staked any tokens, return 0 rewards.
            return (0,0,0,0);
        }
        uint256 TotalRewards = _calculateToTalReward(_player); // @dev Calculate the total rewards for the staker.
        _DaoReward = ((TotalRewards * DaoRoyalty[StakingSection]) / INVERSE_BASIS_POINT) / 100; // @dev Calculate the DAO's share of the rewards.
        _PoolReward = ((TotalRewards * PoolRoyalty) / INVERSE_BASIS_POINT) / 100; // @dev Calculate the staking pool's share of the rewards.
        _AgentReward = ((TotalRewards * AgentRoyalty) / INVERSE_BASIS_POINT) / 100; // @dev Calculate the agent's share of the rewards.
        _PlayerReward = (TotalRewards / INVERSE_BASIS_POINT) - (_DaoReward + _AgentReward + _PoolReward) ; // @dev Calculate the staker's share of the rewards.

        return (_PlayerReward, _DaoReward, _PoolReward, _AgentReward);
    }

    /**
    * @dev A function to remove a staker from the stakers' list.
    * @param _user The address of the staker to remove.
    */
    function removePlayer(address _user) internal {
        address[] memory _array = StakePlayers; // @dev Get the array of stakers.
        for (uint i = 0; i < _array.length; i++) { // @dev Loop through the stakers' array.
            if (_array[i] == _user) { // @dev If the staker to remove is found in the array.
                StakePlayers[i] = _array[_array.length - 1]; // @dev Move the last staker in the array to the position of the staker to remove.
                StakePlayers.pop(); // @dev Remove the last staker from the array.
                break; // @dev Exit the loop.
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                           Setter Function
    //////////////////////////////////////////////////////////////*/
    /**
    * @dev A function to pause or unpause the staking pool.
    * @param status The status to set the pause flag to.
    */
    function setPausePoolStatus(bool status) external onlyRole(DEFAULT_ADMIN_ROLE){
        PausePool = status;
    }

    /**
    * @dev A function to pause or unpause the reward claim process.
    * @param status The status to set the pause flag to.
    */
    function setPauseClaimStatus(bool status) external onlyRole(DEFAULT_ADMIN_ROLE){
        PauseClaim = status;
    }

    /**
    * @dev A function to set the reward per minute for staking.
    * @param _rewardPerMin The amount of reward to be set.
    */
    function setrewardPerMin(uint256 _rewardPerMin) external onlyRole(DEFAULT_ADMIN_ROLE){
        rewardPerMin = _rewardPerMin;
    }

    /**
    * @dev A function to add a new staking pool.
    * @param _poolAddress The address of the staking pool to add.
    */
    function addStakingPool(address _poolAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        StakingPool.push(_poolAddress);
    }

    /**
    * @dev A function to edit the address of a staking pool.
    * @param _originAddress The original address of the staking pool to be edited.
    * @param _newAddress The new address to set for the staking pool.
    */
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


    /*///////////////////////////////////////////////////////////////
                             View Function
    //////////////////////////////////////////////////////////////*/
    /**
    * @dev A function to get the array of all staking players.
    * @return An array containing all staking players' addresses.
    */
    function _getStakePlayers() internal view returns (address[] memory) {
        return StakePlayers;
    }

    /**
    * @dev A function to get the address of a staking pool by its sequence number.
    * @param _PoolSeq The sequence number of the staking pool to retrieve the address for.
    * @return _poolAddress The address of the staking pool.
    */
    function _getStakingPool(uint256 _PoolSeq) internal view returns (address _poolAddress) {
        _poolAddress = StakingPool[_PoolSeq];
    }

    /**
    * @dev A function to get the number of staking players in the pool.
    * @return _playerCount The number of staking players.
    */
    function _getStakePlayerCount() internal view returns (uint256 _playerCount) {
        return StakePlayers.length;
    }

    /**
    * @dev A function to get the total unclaimed rewards across all staking players.
    * @return _totalUnClaim The total amount of unclaimed rewards.
    */
    function _getTotalUnClaim() internal view returns (uint256 _totalUnClaim) {
        address[] memory _stakePlayers = StakePlayers;
        for(uint256 i = 0; i < _stakePlayers.length; i++)
        {   
            address _player = _stakePlayers[i];
            _totalUnClaim = (_totalUnClaim + _calculateToTalReward(_player)) / INVERSE_BASIS_POINT;
        }
        return _totalUnClaim;
    }

    /**
    @dev A function to get the total amount of rewards claimed by users.
    @return _totalClaimed The total amount of rewards claimed.
    */
    function _getTotalClaimed() internal view returns (uint256 _totalClaimed) {
        return totalClaimed;
    }

}