// SPDX-License-Identifier: MIT
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
// ERC 1155 Staking Advance with Governance v2.1.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/base/ERC1155Drop.sol";
import "@thirdweb-dev/contracts/external-deps/openzeppelin/utils/ERC1155/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/base/ERC20Base.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

interface IGovernanceContract {
    function getStakeRewardRate() external view returns (uint256 stakeRewardRate);
}

contract ERC1155StakingG is ReentrancyGuard, PermissionsEnumerable, ERC1155Holder, ContractMetadata, Multicall{
    address public deployer;
    // ERC1155 token interface, representing the stakable NFTs.
    ERC1155Drop public immutable erc1155Token;
    // ERC20 token interface, representing the rewards token.
    ERC20Base public immutable rewardsToken;
    // Get NFT Staking info from NFT Staking
    IGovernanceContract public GovernanceContracts;
    // The specific ID of the ERC1155 token that is eligible for staking.
    uint256 public stakingTokenId;
    // Address of the DAO (Decentralized Autonomous Organization) for fee distribution.
    address public daoAddress;
    // Wallet address for managing additional fees.
    address public ManagerWallet = 0xAf70641d93e3E7fA3790ec75eFaECAE1bC0f7696;
    // Struct to store information about each staking instance.
    struct StakingInfo {
        uint256 amount;     // Amount of tokens staked by the user.
        uint256 reward;     // Reward accumulated by the user.
        uint256 updateTime;  // Timestamp when the user started staking.
    }
    // Mapping from user addresses to their staking information.
    mapping(address => StakingInfo) public stakings;
    // Array of addresses that are currently staking tokens.
    address[] public stakers;
    // Mapping from user addresses to their index in the stakers array.
    mapping(address => uint256) private stakerIndex;
    // Maximum number of NFTs that can be staked in the contract.
    uint256 public constant MAX_NFT_STAKED = 10000;
    // Maximum reward that can be distributed by the contract.
    uint256 public constant MAX_REWARD = 1000000000 * 10**18;
    // Duration for which the staking is active.
    uint256 public constant STAKING_PERIOD = 5 * 365 days;
    // Timestamp when the reward pool starts.
    uint256 public poolStartTime;
    // Total amount of rewards that have been distributed so far.
    uint256 public totalRewardsDistributed;
    // Staking pool STATUS
    bool public POOL_FINISHED;

    // Declare variables to store DAO, manager, and agent fee percentages
    uint256 public DAO_FEE_PERCENTAGE = 10;
    uint256 public MANAGER_FEE_PERCENTAGE = 5;
    uint256 public AGENT_FEE_PERCENTAGE = 1;

    // Define constants for the maximum fee percentages
    uint256 public constant MAX_DAO_FEE_PERCENTAGE = 30;
    uint256 public constant MAX_MANAGER_FEE_PERCENTAGE = 10;
    uint256 public constant MAX_AGENT_FEE_PERCENTAGE = 10;


    bytes32 private constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    constructor(address _erc1155Token, uint256 _stakingTokenId, uint256 _poolStartTime, uint256 _boforeRewardsDistributed, address _erc20Token, address _daoAddress, address _GovernanceContracts, uint256 _DAO_FEE_PERCENTAGE, string memory _contractURI) {
        erc1155Token = ERC1155Drop(_erc1155Token);
        stakingTokenId = _stakingTokenId;
        poolStartTime = _poolStartTime;
        totalRewardsDistributed = _boforeRewardsDistributed;
        rewardsToken = ERC20Base(_erc20Token);
        daoAddress = _daoAddress;
        GovernanceContracts = IGovernanceContract(_GovernanceContracts);

        // Set DAO_FEE_PERCENTAGE with a check
        require(_DAO_FEE_PERCENTAGE <= MAX_DAO_FEE_PERCENTAGE, "DAO fee percentage exceeds maximum limit");
        DAO_FEE_PERCENTAGE = _DAO_FEE_PERCENTAGE;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, 0x9DD6D483bd17ce22b4d1B16c4fdBc0d106d3669d);
        deployer = msg.sender;
        POOL_FINISHED = false;
        _setupContractURI(_contractURI);
    }

    // Staking function: Allows a user to stake ERC-1155 tokens.
    function stake(uint256 _amount) external nonReentrant {
        // Chkck pool status.
        require(!POOL_FINISHED, "Pool has finished.");
        // Check if the user has enough ERC-1155 tokens to stake.
        require(erc1155Token.balanceOf(msg.sender, stakingTokenId) >= _amount, "Not enough ERC1155 tokens");
        // Access the user's staking information.
        StakingInfo storage info = stakings[msg.sender];
        // Safely transfer ERC-1155 tokens from the user to this contract.
        erc1155Token.safeTransferFrom(msg.sender, address(this), stakingTokenId, _amount, "");

        // Update the user's staking information.
        if (info.amount > 0) {
            // Claim any rewards before stake the tokens.
            _claimReward(msg.sender, false);
            // Update the staked amount in the user's staking information.
            info.amount = info.amount + _amount;
        } else {
            // If it's the user's first time staking, add them to the list of stakers.
            stakerIndex[msg.sender] = stakers.length;
            stakers.push(msg.sender);
            // Record the staked amount, reward, and start time in the user's staking info.
            stakings[msg.sender] = StakingInfo(_amount, 0, block.timestamp);
        }
    }

    // Withdraw function: Allows a user to withdraw staked ERC-1155 tokens.
    function withdraw(uint256 _amount) external nonReentrant {
        // Access the user's staking information.
        StakingInfo storage info = stakings[msg.sender];
        // Ensure the user has enough staked tokens to withdraw the requested amount.
        require(info.amount >= _amount, "Insufficient staked amount");
        // The requested amount must be greater than 0.
        require(_amount > 0, "Amount must be greater than 0");
        if(!POOL_FINISHED){
            // Claim any rewards before withdrawing the tokens.
            _claimReward(msg.sender, false);
        }
        // Update the staked amount in the user's staking information.
        info.amount = info.amount - _amount;
        // Safely transfer the requested amount of ERC-1155 tokens back to the user.
        erc1155Token.safeTransferFrom(address(this), msg.sender, stakingTokenId, _amount, "");
        // If the user's staked amount reaches 0, remove them from the stakers list.
        if (info.amount == 0) {
            removeStaker(msg.sender);
        }
    }

    // Private function to remove a staker from the stakers list.
    function removeStaker(address _staker) private {
        // Retrieve the index of the staker in the stakers array.
        uint256 index = stakerIndex[_staker];
        // Replace the staker to be removed with the last staker in the array.
        stakers[index] = stakers[stakers.length - 1];
        // Update the index of the staker that was moved.
        stakerIndex[stakers[index]] = index;
        // Remove the last element (now duplicated) from the stakers array.
        stakers.pop();
        // Delete the staking information of the removed staker.
        delete stakings[_staker];
        // Delete the index information of the removed staker.
        delete stakerIndex[_staker];
    }

    function setGovernanceContracts(address _GovernanceContracts) external {
        GovernanceContracts = IGovernanceContract(_GovernanceContracts);
    }

    function getRewardRate() public view returns (uint256){
        return GovernanceContracts.getStakeRewardRate();
    }

    // Public function to calculate the reward for a given user.
    function calculateReward(address _user) public view returns (uint256) {
        // Access the staking information of the user.
        StakingInfo storage info = stakings[_user];
        // Check if the staking period has ended or the maximum reward has been distributed.
        // If yes, no more rewards are available.
        if (totalRewardsDistributed >= MAX_REWARD || POOL_FINISHED) {
            return 0;
        }

        // Initialize current block timestamp to 0.
        uint nowBlockTime = 0; 
        if (block.timestamp > poolStartTime + STAKING_PERIOD)
        {
            // If the staking period has ended, set the current block time to the end time of the staking period.
            nowBlockTime = poolStartTime + STAKING_PERIOD; 
        }else{
            // If within the staking period, use the current block timestamp.
            nowBlockTime = block.timestamp; 
        }

        uint256 stakingRewardRate = getRewardRate();
        // Calculate the total time the user's tokens have been staked.
        uint256 totalStakingTime = nowBlockTime - info.updateTime;
        // Determine the reward per minute based on the maximum reward and staking period.
        uint256 rewardPerSecond = getRewardPerSec();
        // Calculate the user's reward based on their staked amount and the total staking time.
        uint256 userReward = (info.amount * rewardPerSecond * totalStakingTime * stakingRewardRate) / 100;
        // Calculate the payable reward, ensuring it does not exceed the maximum reward limit.
        uint256 payableReward = totalRewardsDistributed + userReward > MAX_REWARD ? 
                                MAX_REWARD - totalRewardsDistributed : userReward;
        // Return the calculated payable reward.
        return payableReward;
    }

    // External function to calculate the reward for a given user, dao, manager.
    function calculateRewards(address _user) external view returns (uint256 userReward, uint256 daoFee, uint256 managerFee) {
        // Calculate the current reward for the user.
        uint256 reward = calculateReward(_user);
        // Calculate the DAO fee based on the reward and the DAO fee percentage.
        daoFee = (reward * DAO_FEE_PERCENTAGE) / 100;
        // Calculate the fee for the fee manager wallet based on the reward and the manager fee percentage.
        managerFee = (reward * MANAGER_FEE_PERCENTAGE) / 100;
        // Calculate the user's net reward after deducting fees.
        userReward = reward - daoFee - managerFee;

        return (userReward, daoFee, managerFee);
    }

    function claim() external nonReentrant{
        _claimReward(msg.sender, false);
    }

    function claimAgent(address _user) external onlyRole(FACTORY_ROLE) {
        _claimReward(_user, true);
    }

    // Internal function to handle reward claiming for a user.
    function _claimReward(address _user, bool isAdmin) internal {
        require(!POOL_FINISHED, "Pool has finished.");
        // Calculate the current reward for the user.
        uint256 reward = calculateReward(_user);
        // Ensure there is a reward available to claim.
        require(reward > 0, "No reward available");
        // Access the staking information of the user.
        StakingInfo storage info = stakings[_user];
        // Calculate the DAO fee based on the reward and the DAO fee percentage.
        uint256 daoFee = (reward * DAO_FEE_PERCENTAGE) / 100;
        // Calculate the fee for the fee manager wallet based on the reward and the manager fee percentage.
        uint256 managerFee = (reward * MANAGER_FEE_PERCENTAGE) / 100;
        // If the claim is made by an admin, calculate the admin fee.
        uint256 adminFee = isAdmin ? (reward * AGENT_FEE_PERCENTAGE) / 100 : 0;
        // Mint the DAO fee to the DAO address if applicable.
        if (daoFee > 0) {
            rewardsToken.mintTo(daoAddress, daoFee);
        }

        // Mint the fee manager's fee to the fee manager wallet if applicable.
        if (managerFee > 0) {
            rewardsToken.mintTo(ManagerWallet, managerFee);
        }

        // If claimed by an admin, mint the admin fee to the owner's address if applicable.
        if (isAdmin && adminFee > 0) {
            rewardsToken.mintTo(msg.sender, adminFee);
        }

        // Calculate the user's net reward after deducting fees.
        uint256 userReward = reward - daoFee - managerFee - adminFee;
        // Mint the net reward to the user if applicable.
        if (userReward > 0) {
            rewardsToken.mintTo(_user, userReward);
        }
        totalRewardsDistributed = totalRewardsDistributed + reward;
        info.updateTime = block.timestamp;
    }

    // Admin functions
    // Administrative function to unstake tokens on behalf of a user.
    function adminUnstakeUser(address _user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Access the staking information of the specified user.
        StakingInfo storage info = stakings[_user];
        // After the pool is finished, withdrawal is made without paying the reward.
        if(!POOL_FINISHED){
            // Claim any rewards before withdrawing the tokens.
            _claimReward(_user, false);
        }
        // Safely transfer the staked ERC-1155 tokens from this contract back to the user.
        erc1155Token.safeTransferFrom(address(this), _user, stakingTokenId, info.amount, "");
        // Remove the staker from the stakers list.
        removeStaker(_user);
    }

    // Administrative function to unstake all tokens from all users.
    function adminUnstakeAll() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Iterate over all stakers in reverse order to avoid index shifting issues.
        for (uint256 i = stakers.length; i > 0; i--) {
            // Retrieve the address of the current staker.
            address staker = stakers[i - 1];
            // Access the staking information of the current staker.
            uint256 amount = stakings[staker].amount;
            // Check if the staker has a non-zero staked amount.
            if (amount > 0) {
                adminUnstakeUser(staker);
            }
        }
    }

    // Function to set the DAO fee percentage
    // Only accounts with admin privileges can call this function
    function setDAOFeePercentage(uint256 _daoFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure the input fee percentage does not exceed the maximum limit
        require(_daoFeePercentage <= MAX_DAO_FEE_PERCENTAGE, "DAO fee percentage exceeds maximum limit");
        // Set the DAO fee percentage
        DAO_FEE_PERCENTAGE = _daoFeePercentage;
    }

    // Function to set the manager fee percentage
    // Only accounts with admin privileges can call this function
    function setFeeManagerPercentage(uint256 _managerFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure the input fee percentage does not exceed the maximum limit
        require(_managerFeePercentage <= MAX_MANAGER_FEE_PERCENTAGE, "Manager fee percentage exceeds maximum limit");
        // Set the manager fee percentage
        MANAGER_FEE_PERCENTAGE = _managerFeePercentage;
    }

    // Function to set the agent fee percentage
    // Only accounts with admin privileges can call this function
    function setAgentFeePercentage(uint256 _agentFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure the input fee percentage does not exceed the maximum limit
        require(_agentFeePercentage <= MAX_AGENT_FEE_PERCENTAGE, "Agent fee percentage exceeds maximum limit");
        // Set the agent fee percentage
        AGENT_FEE_PERCENTAGE = _agentFeePercentage;
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    // Function to set the DAO address
    // Only accounts with the admin role can call this function
    function setDaoAddress(address _daoAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        daoAddress = _daoAddress;
    }

    // Function to set the manager fee wallet address
    // Only accounts with the admin role can call this function
    function setManagerFeeWallet(address _ManagerWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ManagerWallet = _ManagerWallet;
    }

    // Function to set the pool start time
    // Only accounts with the admin role can call this function
    function setPoolStartTime(uint256 _poolStartTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        poolStartTime = _poolStartTime;
    }

    // Function to set the pool finished status
    // Only accounts with the admin role can call this function
    function setPoolFinished(bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        POOL_FINISHED = status;
    }

    // Function to get the count of stakers
    // This is a view function that does not modify state
    function getStakersCount() public view returns (uint256) {
        return stakers.length;
    }

    // Function to get the reward per second
    // This is a pure function that does not read from or modify state
    function getRewardPerSec() public pure returns (uint256) {
        return ((MAX_REWARD / STAKING_PERIOD) / MAX_NFT_STAKED);
    }

    // Function to get the remaining staking time
    // This is a view function that does not modify state
    function getRemainingStakingTime() public view returns (uint256) {
        uint256 endTime = poolStartTime + STAKING_PERIOD; // Calculate the end time of the staking period
        if (block.timestamp >= endTime) { // Check if the current time is past the end time
            return 0; // If yes, return 0 as remaining time
        } else {
            return endTime - block.timestamp; // If no, return the difference between end time and current time
        }
    }
}