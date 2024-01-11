// SPDX-License-Identifier: MIT
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
// ERC 1155 Staking with advance function
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@thirdweb-dev/contracts/token/TokenERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERC1155Staking is Ownable , ReentrancyGuard{
    IERC1155 public immutable erc1155Token;
    TokenERC20 public immutable rewardsToken;
    uint256 public stakingTokenId;

    address public daoAddress;
    address public feeManagerWallet;
    uint256 public DAO_FEE_PERCENTAGE;
    uint256 public MANAGER_FEE_PERCENTAGE = 5;
    uint256 public AGENT_FEE_PERCENTAGE = 1;

    struct StakingInfo {
        uint256 amount;
        uint256 reward;
        uint256 startTime;
    }

    mapping(address => StakingInfo) public stakings;
    address[] public stakers;
    mapping(address => uint256) private stakerIndex;
    
    uint256 public constant MAX_NFT_STAKED = 10000;
    uint256 public constant MAX_REWARD = 1000000000 * 10**18;
    uint256 public constant STAKING_PERIOD = 5 * 365 days;
    uint256 public poolStartTime;
    uint256 public totalRewardsDistributed;

    constructor(IERC1155 _erc1155Token, uint256 _stakingTokenId, uint256 _poolStartTime, uint256 _boforeRewardsDistributed, address _erc20Token, address _daoAddress, address _feeManagerWallet, uint256 _DAO_FEE_PERCENTAGE) {
        erc1155Token = _erc1155Token;
        stakingTokenId = _stakingTokenId;
        poolStartTime = _poolStartTime;
        totalRewardsDistributed = _boforeRewardsDistributed;
        rewardsToken = TokenERC20(_erc20Token);
        daoAddress = _daoAddress;
        feeManagerWallet = _feeManagerWallet;
        DAO_FEE_PERCENTAGE = _DAO_FEE_PERCENTAGE;
    }

    function stake(uint256 _amount) external nonReentrant{
        require(erc1155Token.balanceOf(msg.sender, stakingTokenId) >= _amount, "Not enough ERC1155 tokens");
        erc1155Token.safeTransferFrom(address(this), msg.sender, stakingTokenId, _amount, "");
        stakings[msg.sender] = StakingInfo(_amount, 0, block.timestamp);
        if (stakings[msg.sender].amount == 0) {
            stakerIndex[msg.sender] = stakers.length;
            stakers.push(msg.sender);
        }
    }

    function withdraw(uint256 _amount) external nonReentrant {
        StakingInfo storage info = stakings[msg.sender];
        require(info.amount >= _amount, "Insufficient staked amount");
        require(_amount > 0, "Amount must be greater than 0");
        _claimReward(msg.sender, false);
        info.amount -= _amount;
        erc1155Token.safeTransferFrom(address(this), msg.sender, stakingTokenId, _amount, "");

        if (info.amount == 0) {
            removeStaker(msg.sender);
        }
    }

    function removeStaker(address _staker) private {
        uint256 index = stakerIndex[_staker];
        stakers[index] = stakers[stakers.length - 1];
        stakerIndex[stakers[index]] = index;
        stakers.pop();
        delete stakings[msg.sender];
        delete stakerIndex[_staker];
    }

    function calculateReward(address _user) public view returns (uint256) {
        StakingInfo storage info = stakings[_user];
        if (block.timestamp > poolStartTime + STAKING_PERIOD || totalRewardsDistributed >= MAX_REWARD) {
            return 0;
        }
        
        uint256 totalStakingTime = block.timestamp - info.startTime;
        uint256 rewardPerMinute = MAX_REWARD / (STAKING_PERIOD / 1 minutes);
        uint256 userReward = (info.amount / MAX_NFT_STAKED) * rewardPerMinute * totalStakingTime;

        uint256 payableReward = totalRewardsDistributed + userReward > MAX_REWARD ? 
                                MAX_REWARD - totalRewardsDistributed : userReward;
        return payableReward;
    }

    function claimReward() external nonReentrant{
        _claimReward(msg.sender, false);
    }

    function claimAgentReward(address _user) external onlyOwner {
        _claimReward(_user, true);
    }

    function _claimReward(address _user, bool isAdmin) internal {
        uint256 reward = calculateReward(_user);
        require(reward > 0, "No reward available");

        uint256 daoFee = (reward * DAO_FEE_PERCENTAGE) / 100;
        uint256 feeWalletFee = (reward * MANAGER_FEE_PERCENTAGE) / 100;
        uint256 adminFee = isAdmin ? (reward * AGENT_FEE_PERCENTAGE) / 100 : 0;

        if (daoFee > 0) {
            rewardsToken.mintTo(daoAddress, daoFee);
        }
        if (feeWalletFee > 0) {
            rewardsToken.mintTo(feeManagerWallet, feeWalletFee);
        }
        if (isAdmin && adminFee > 0) {
            rewardsToken.mintTo(owner(), adminFee);
        }

        uint256 userReward = reward - daoFee - feeWalletFee - adminFee;
        if (userReward > 0) {
            rewardsToken.mintTo(_user, userReward);
        }
    }

    // Admin functions
    function unstakeUser(address _user) external onlyOwner {
        StakingInfo storage info = stakings[_user];
        erc1155Token.safeTransferFrom(address(this), _user, stakingTokenId, info.amount, "");
        if (info.amount == 0) {
            removeStaker(_user);
        }
    }

    function adminUnstakeAll() external onlyOwner {
        for (uint256 i = stakers.length; i > 0; i--) {
            address staker = stakers[i - 1];
            uint256 amount = stakings[staker].amount;
            if (amount > 0) {
                erc1155Token.safeTransferFrom(address(this), staker, stakingTokenId, amount, "");
                totalRewardsDistributed -= stakings[staker].reward;
                removeStaker(staker);
            }
        }
    }

    function confiscateERC1155FromUser(address _user) external onlyOwner {
        StakingInfo storage info = stakings[_user];
        erc1155Token.safeTransferFrom(address(this), owner(), stakingTokenId, info.amount, "");
        removeStaker(_user);
    }

    function setDaoAddress(address _daoAddress) external onlyOwner {
        daoAddress = _daoAddress;
    }

    function setManagerFeeWallet(address _feeManagerWallet) external onlyOwner {
        feeManagerWallet = _feeManagerWallet;
    }

    function setDAOFeePercentage(uint256 _daoFeePercentage) external onlyOwner {
        DAO_FEE_PERCENTAGE = _daoFeePercentage;
    }

    function setFeeManagerPercentage(uint256 _managerFeePercentage) external onlyOwner {
        MANAGER_FEE_PERCENTAGE = _managerFeePercentage;
    }

    function setAgentFeePercentage(uint256 _agentFeePercentage) external onlyOwner {
        AGENT_FEE_PERCENTAGE = _agentFeePercentage;
    }

    function setPoolStartTime(uint256 _poolStartTime) external onlyOwner {
        poolStartTime = _poolStartTime;
    }
}
