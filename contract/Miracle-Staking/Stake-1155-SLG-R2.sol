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

contract SevenlineStakingPool is
    ReentrancyGuard, 
    ERC1155Holder,
    PermissionsEnumerable
{
    // Store our two other contracts here (Edition Drop and Token)
    DropERC1155 public immutable NodeNftCollection;
    TokenERC20 public immutable rewardsToken;

    /// @dev Owner of the contract (purpose: OpenSea compatibility, etc.)
    address private _owner;
    /// @dev The recipient of who gets the royalty.
    address public DaoAddress;
    /// @dev The percentage of royalty how much royalty in basis points.
    uint256[] public DaoRoyalty;
    /// @dev The rewards rate is [_rewardPerHour] per 1 Hour.
    uint256 public rewardPerHour;
    /// @dev Operation status of the Pool.
    bool public PausePool;
    /// @dev Operation claim of the Pool.
    bool public PauseClaim;
    /// @dev The user state of the Pool.
    struct MapValue {
        bool isData;
        uint256 value;
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

    // @dev Mapping of player addresses to their NFT
    // By default, player has no NFT. They will not be in the mapping.
    mapping(address => MapValue) public playerNode;

    // @dev Mapping of player address until last time they staked/withdrew/claimed their rewards
    // By default, player has no last time. They will not be in the mapping.
    mapping(address => MapValue) public playerLastUpdate;


    // Multiply by 1000 for the decimal division calculation and divide 1000 after the operation is completed.
    uint256 private constant INVERSE_BASIS_POINT = 1000; //Using point

    constructor(
            address _defaultAdmin,
            uint256 _StakingSection,
            DropERC1155 _NodeNFTToken, 
            TokenERC20 _RewardToken,
            address _DaoAddress,
            uint256 _rewardPerHour
            ) {
            StakingSection = _StakingSection;
            NodeNftCollection = _NodeNFTToken;
            rewardsToken = _RewardToken;
            DaoAddress = _DaoAddress;
            rewardPerHour = _rewardPerHour;

            //Section
            
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
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return hasRole(DEFAULT_ADMIN_ROLE, _owner) ? _owner : address(0);
    }

    ///     =====   External functions  =====
    function stake(uint256 _tokenId, uint256 _depositAmount, uint256 _poolID) external nonReentrant {
        // Ensure the player has at least 1 of the token they are trying to stake
        require(StakingSection-1 == _tokenId, "Node not available for this session.");
        require(
            NodeNftCollection.balanceOf(msg.sender, _tokenId) >= _depositAmount,
            "You must have deposit amount node you are trying to stake"
        );
        require(!PausePool, "Pool is in Pause state.");

        uint256 totalStakeAmount;
        // If they have a node already, add node and mint reward token.
        if (playerNode[msg.sender].isData) {
            uint256 _nowAmount = playerNode[msg.sender].amount;
            totalStakeAmount = _nowAmount + _depositAmount;

            // Calculate the rewards they are owed, and pay them out.
            if(!PauseClaim){
                // Calculate the rewards they are owed, and pay them out.
                (uint256 _MyReward, uint256 _DaoReward, uint _PoolReward) = calculateRewards(msg.sender);

                rewardsToken.mintTo(StakingPool[playerNode[msg.sender].poolID], _PoolReward);
                rewardsToken.mintTo(msg.sender, _MyReward);
                rewardsToken.mintTo(DaoAddress, _DaoReward);
            }

        }else{
            //New Player
            StakePlayers.push(msg.sender);
            totalStakeAmount = _depositAmount;
        }
              
        // Transfer using safeTransfer
        // Transfer the node to the contract
        NodeNftCollection.safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _depositAmount,
            "Staking your node"
        );

        // Update the playerNode mapping
        playerNode[msg.sender].poolID = _poolID;
        playerNode[msg.sender].value = _tokenId;
        playerNode[msg.sender].isData = true;
        playerNode[msg.sender].amount = totalStakeAmount;

        // Update the playerLastUpdate mapping
        playerNode[msg.sender].poolID = _poolID;
        playerLastUpdate[msg.sender].isData = true;
        playerLastUpdate[msg.sender].value = block.timestamp;
        playerLastUpdate[msg.sender].amount = totalStakeAmount;
    }

    function withdraw(uint256 withdrawAmount) external nonReentrant {
        // Ensure the player has a pickaxe
        require(
            playerNode[msg.sender].isData,
            "You do not have a node to withdraw."
        );

        require(!PausePool);
        
        uint256 nowAmount = playerNode[msg.sender].amount;
        uint256 totalAmount = nowAmount - withdrawAmount;

        if(totalAmount<0){
            revert();
        }

        // Send the pickaxe back to the player
        NodeNftCollection.safeTransferFrom(
            address(this),
            msg.sender,
            playerNode[msg.sender].value,
            withdrawAmount,
            "Returning your withdraw node"
        );

        if(!PauseClaim){
            // Calculate the rewards they are owed, and pay them out.
            (uint256 _MyReward, uint256 _DaoReward, uint _PoolReward) = calculateRewards(msg.sender);

            rewardsToken.mintTo(StakingPool[playerNode[msg.sender].poolID], _PoolReward);
            rewardsToken.mintTo(msg.sender, _MyReward);
            rewardsToken.mintTo(DaoAddress, _DaoReward);
        }

        if (totalAmount>0){
            // Update the playerNode mapping
            playerNode[msg.sender].isData = true;
            playerNode[msg.sender].amount = totalAmount;

            // Update the playerLastUpdate mapping
            playerLastUpdate[msg.sender].isData = true;
            playerLastUpdate[msg.sender].value = block.timestamp;
            playerLastUpdate[msg.sender].amount = totalAmount;

        }else if(totalAmount==0){
            // Update the playerNode mapping
            playerNode[msg.sender].isData = false;
            playerNode[msg.sender].amount = totalAmount;

            // Remove StakePlayer
            removePlayer(msg.sender);

            // Update the playerLastUpdate mapping
            playerLastUpdate[msg.sender].isData = false;
            playerLastUpdate[msg.sender].value = block.timestamp;
            playerLastUpdate[msg.sender].amount = totalAmount;
        }
    }

    function claim() external nonReentrant {
        require(!PausePool, "Pool is in Pause state.");
        require(!PauseClaim, "Claim is in Pause state.");

        // Calculate the rewards they are owed, and pay them out.
        (uint256 _MyReward, uint256 _DaoReward, uint _PoolReward) = calculateRewards(msg.sender);

        rewardsToken.mintTo(StakingPool[playerNode[msg.sender].poolID], _PoolReward);
        rewardsToken.mintTo(msg.sender, _MyReward);
        rewardsToken.mintTo(DaoAddress, _DaoReward);

        // Update the playerLastUpdate mapping
        playerLastUpdate[msg.sender].isData = true;
        playerLastUpdate[msg.sender].value = block.timestamp;
    }

    function claimAgent(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant{
        require(!PausePool, "Pool is in Pause state.");
        require(!PauseClaim, "Claim is in Pause state.");

        // Calculate the rewards they are owed, and pay them out.
        (uint256 _MyReward, uint256 _DaoReward,  uint _PoolReward, uint256 _AgentReward) = calculateAgentRewards(msg.sender);

        rewardsToken.mintTo(StakingPool[playerNode[_user].poolID], _PoolReward);
        rewardsToken.mintTo(_user, _MyReward);
        rewardsToken.mintTo(DaoAddress, _DaoReward);
        rewardsToken.mintTo(msg.sender, _AgentReward);
        
        // Update the playerLastUpdate mapping
        playerLastUpdate[_user].isData = true;
        playerLastUpdate[_user].value = block.timestamp;
    }

    // ===== Internal ===== \\

    // Calculate the rewards the player is owed since last time they were paid out
    // This is calculated using block.timestamp and the playerLastUpdate.
    // If playerLastUpdate or playerNode is not set, then the player has no rewards.
    function calculateRewards(address _player)
        public
        view
        returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward)
            {
                // If playerLastUpdate or playerNode is not set, then the player has no rewards.
                if (
                    !playerLastUpdate[_player].isData || !playerNode[_player].isData
                ) {
                    return (0,0,0);
                }

                // Calculate the time difference between now and the last time they staked/withdrew/claimed their rewards
                uint256 timeDifference = block.timestamp - playerLastUpdate[_player].value;

                // Calculate the rewards they are owed
                // R1, All NFT have the same value
                uint256 TotalRewards = (((timeDifference * rewardPerHour) * playerNode[_player].amount) * INVERSE_BASIS_POINT) / 60;
                // Cal DAO Reward
                uint256 DAOReward = ((TotalRewards * DaoRoyalty[StakingSection-1]) / INVERSE_BASIS_POINT) / 100;
                // Cal Agent Reward
                uint256 PoolReward = ((TotalRewards * PoolRoyalty) / INVERSE_BASIS_POINT) / 100;
                // Cal Player Reward
                uint256 PlayerReward = (TotalRewards / INVERSE_BASIS_POINT) - (DAOReward + PoolReward);

                // Return the rewards
                return (PlayerReward, DAOReward, PoolReward);
            }

    function calculateAgentRewards(address _player)
        public
        view
        returns (uint256 _PlayerReward, uint256 _DaoReward, uint256 _PoolReward, uint256 _AgentReward)
            {
                // If playerLastUpdate or playerNode is not set, then the player has no rewards.
                if (
                    !playerLastUpdate[_player].isData || !playerNode[_player].isData
                ) {
                    return (0,0,0,0);
                }

                // Calculate the time difference between now and the last time they staked/withdrew/claimed their rewards
                uint256 timeDifference = block.timestamp - playerLastUpdate[_player].value;

                // Calculate the rewards they are owed
                // R1, All NFT have the same value
                uint256 TotalRewards = (((timeDifference * rewardPerHour) * playerNode[_player].amount) * INVERSE_BASIS_POINT) / 3600;
                // Cal DAO Reward
                uint256 DAOReward = ((TotalRewards * DaoRoyalty[StakingSection-1]) / INVERSE_BASIS_POINT) / 100;
                // Cal Agent Reward
                uint256 PoolReward = ((TotalRewards * PoolRoyalty) / INVERSE_BASIS_POINT) / 100;
                // Cal Agent Reward
                uint256 AgentReward = (TotalRewards * AgentRoyalty) / INVERSE_BASIS_POINT / 100;
                // Cal Player Reward
                uint256 PlayerReward = (TotalRewards / INVERSE_BASIS_POINT) - (DAOReward + AgentReward + PoolReward) ;

                // Return the rewards
                return (PlayerReward, DAOReward, PoolReward, AgentReward);
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

    function setrewardPerHour(uint256 _rewardPerHour) external onlyRole(DEFAULT_ADMIN_ROLE){
        rewardPerHour = _rewardPerHour;
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
    function getStakePlayers() public view returns (address[] memory) {
        require(msg.sender != _owner, "This can only be called by the contract owner");
        return StakePlayers;
    }

    function getStakePlayer(uint256 _playerSeq) public
    view
    returns (address _playerAddress)
    {
        require(msg.sender != _owner, "This can only be called by the contract owner");
        return StakePlayers[_playerSeq];
    }

    function getStakingPool(uint256 _PoolSeq)
    public
    view
    returns (address _poolAddress)
    {
        require(msg.sender != _owner, "This can only be called by the contract owner");
        return StakingPool[_PoolSeq];
    }

    function getStakePlayerCount()
    public
    view
    returns (uint256 _playerCount)
    {
        return StakePlayers.length;
    }

}