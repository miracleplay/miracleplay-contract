// SPDX-License-Identifier: MIT
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
// ERC 1155 Staking Advance v2.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/drop/DropERC1155.sol";
import "@thirdweb-dev/contracts/openzeppelin-presets/utils/ERC1155/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/token/TokenERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";

contract ERC1155Staking is ReentrancyGuard, PermissionsEnumerable, ERC1155Holder, ContractMetadata{
    address public deployer;
    // ERC1155 token interface, representing the stakable NFTs.
    DropERC1155 public immutable erc1155Token;
    // ERC20 token interface, representing the rewards token.
    TokenERC20 public immutable rewardsToken;
    // The specific ID of the ERC1155 token that is eligible for staking.
    uint256 public stakingTokenId;
    // Address of the DAO (Decentralized Autonomous Organization) for fee distribution.
    address public daoAddress;
    // Wallet address for managing additional fees.
    address public ManagerWallet;
    // Percentage of the reward allocated as a fee to the DAO.
    uint256 public DAO_FEE_PERCENTAGE;
    // Percentage of the reward allocated as a fee to the fee manager.
    uint256 public MANAGER_FEE_PERCENTAGE = 5;
    // Percentage of the reward allocated as a fee to agents (if applicable).
    uint256 public AGENT_FEE_PERCENTAGE = 1;
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

    bytes32 private constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    constructor(address _erc1155Token, uint256 _stakingTokenId, uint256 _poolStartTime, uint256 _boforeRewardsDistributed, address _erc20Token, address _daoAddress, address _ManagerWallet, uint256 _DAO_FEE_PERCENTAGE, string memory _contractURI) {
        erc1155Token = DropERC1155(_erc1155Token);
        stakingTokenId = _stakingTokenId;
        poolStartTime = _poolStartTime;
        totalRewardsDistributed = _boforeRewardsDistributed;
        rewardsToken = TokenERC20(_erc20Token);
        daoAddress = _daoAddress;
        ManagerWallet = _ManagerWallet;
        DAO_FEE_PERCENTAGE = _DAO_FEE_PERCENTAGE;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
        deployer = msg.sender;
        _setupContractURI(_contractURI);
    }

    // Staking function: Allows a user to stake ERC-1155 tokens.
    function stake(uint256 _amount) external nonReentrant {
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
        }

        // Record the staked amount, reward, and start time in the user's staking info.
        stakings[msg.sender] = StakingInfo(_amount, 0, block.timestamp);
    }

    // Withdraw function: Allows a user to withdraw staked ERC-1155 tokens.
    function withdraw(uint256 _amount) external nonReentrant {
        // Access the user's staking information.
        StakingInfo storage info = stakings[msg.sender];
        // Ensure the user has enough staked tokens to withdraw the requested amount.
        require(info.amount >= _amount, "Insufficient staked amount");
        // The requested amount must be greater than 0.
        require(_amount > 0, "Amount must be greater than 0");
        // Claim any rewards before withdrawing the tokens.
        _claimReward(msg.sender, false);
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

    // Public function to calculate the reward for a given user.
    function calculateReward(address _user) public view returns (uint256) {
        // Access the staking information of the user.
        StakingInfo storage info = stakings[_user];
        // Check if the staking period has ended or the maximum reward has been distributed.
        // If yes, no more rewards are available.
        if (block.timestamp > poolStartTime + STAKING_PERIOD || totalRewardsDistributed >= MAX_REWARD) {
            return 0;
        }
        // Calculate the total time the user's tokens have been staked.
        uint256 totalStakingTime = block.timestamp - info.updateTime;
        // Determine the reward per minute based on the maximum reward and staking period.
        uint256 rewardPerSecond = getRewardPerSec();
        // Calculate the user's reward based on their staked amount and the total staking time.
        uint256 userReward = info.amount * rewardPerSecond * totalStakingTime;
        // Calculate the payable reward, ensuring it does not exceed the maximum reward limit.
        uint256 payableReward = totalRewardsDistributed + userReward > MAX_REWARD ? 
                                MAX_REWARD - totalRewardsDistributed : userReward;
        // Return the calculated payable reward.
        return payableReward;
    }

    function claimReward() external nonReentrant{
        _claimReward(msg.sender, false);
    }

    function claimAgentReward(address _user) external onlyRole(FACTORY_ROLE) {
        _claimReward(_user, true);
    }

    // Internal function to handle reward claiming for a user.
    function _claimReward(address _user, bool isAdmin) internal {
        // Calculate the current reward for the user.
        uint256 reward = calculateReward(_user);
        // Ensure there is a reward available to claim.
        require(reward > 0, "No reward available");
        // Access the staking information of the user.
        StakingInfo storage info = stakings[_user];
        // Calculate the DAO fee based on the reward and the DAO fee percentage.
        uint256 daoFee = (reward * DAO_FEE_PERCENTAGE) / 100;
        // Calculate the fee for the fee manager wallet based on the reward and the manager fee percentage.
        uint256 feeWalletFee = (reward * MANAGER_FEE_PERCENTAGE) / 100;
        // If the claim is made by an admin, calculate the admin fee.
        uint256 adminFee = isAdmin ? (reward * AGENT_FEE_PERCENTAGE) / 100 : 0;
        // Mint the DAO fee to the DAO address if applicable.
        if (daoFee > 0) {
            rewardsToken.mintTo(daoAddress, daoFee);
        }

        // Mint the fee manager's fee to the fee manager wallet if applicable.
        if (feeWalletFee > 0) {
            rewardsToken.mintTo(ManagerWallet, feeWalletFee);
        }

        // If claimed by an admin, mint the admin fee to the owner's address if applicable.
        if (isAdmin && adminFee > 0) {
            rewardsToken.mintTo(msg.sender, adminFee);
        }

        // Calculate the user's net reward after deducting fees.
        uint256 userReward = reward - daoFee - feeWalletFee - adminFee;
        // Mint the net reward to the user if applicable.
        if (userReward > 0) {
            rewardsToken.mintTo(_user, userReward);
        }
        info.updateTime = block.timestamp;
    }

    // Admin functions
    // Administrative function to unstake tokens on behalf of a user.
    function unstakeUser(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Access the staking information of the specified user.
        StakingInfo storage info = stakings[_user];
        // Ensure the user has staked tokens before proceeding.
        require(info.amount > 0, "User has no staked tokens");
        // Claim any rewards before withdrawing the tokens.
        _claimReward(_user, false);
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
                // Safely transfer the staked ERC-1155 tokens from this contract back to the staker.
                erc1155Token.safeTransferFrom(address(this), staker, stakingTokenId, amount, "");
                // Subtract the staker's reward from the total rewards distributed.
                totalRewardsDistributed -= stakings[staker].reward;
                // Claim any rewards before withdrawing the tokens.
                _claimReward(staker, false);
                // Remove the staker from the stakers list.
                removeStaker(staker);
            }
        }
    }

    // Administrative function to confiscate staked ERC-1155 tokens from a specific user.
    function confiscateERC1155FromUser(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Access the staking information of the specified user.
        StakingInfo storage info = stakings[_user];
        // Ensure the user has staked tokens before proceeding.
        require(info.amount > 0, "User has no staked tokens");
        // Safely transfer the staked ERC-1155 tokens from this contract to the owner.
        erc1155Token.safeTransferFrom(address(this), msg.sender, stakingTokenId, info.amount, "");
        // Remove the user from the stakers list and reset their staking information.
        removeStaker(_user);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function setDaoAddress(address _daoAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        daoAddress = _daoAddress;
    }

    function setManagerFeeWallet(address _ManagerWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ManagerWallet = _ManagerWallet;
    }

    function setDAOFeePercentage(uint256 _daoFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        DAO_FEE_PERCENTAGE = _daoFeePercentage;
    }

    function setFeeManagerPercentage(uint256 _managerFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MANAGER_FEE_PERCENTAGE = _managerFeePercentage;
    }

    function setAgentFeePercentage(uint256 _agentFeePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AGENT_FEE_PERCENTAGE = _agentFeePercentage;
    }

    function setPoolStartTime(uint256 _poolStartTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        poolStartTime = _poolStartTime;
    }

    function getStakersCount() public view returns (uint256) {
        return stakers.length;
    }

    function getRewardPerSec() public pure returns (uint256) {
        return ((MAX_REWARD / STAKING_PERIOD) / MAX_NFT_STAKED);
    }

    function getRemainingStakingTime() public view returns (uint256) {
        uint256 endTime = poolStartTime + STAKING_PERIOD;
        if (block.timestamp >= endTime) {
            return 0;
        } else {
            return endTime - block.timestamp;
        }
    }

}