// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingContract is Ownable {
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public rewardRate;

    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => Stake) public stakes;

    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate
    ) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Staking amount must be greater than 0");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 reward = _pendingReward(msg.sender);
        stakes[msg.sender].rewardDebt = reward;

        stakes[msg.sender].amount += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Unstaking amount must be greater than 0");
        require(stakes[msg.sender].amount >= amount, "Unstaking amount exceeds staked balance");

        uint256 reward = _pendingReward(msg.sender);
        stakes[msg.sender].rewardDebt = reward;

        stakes[msg.sender].amount -= amount;
        totalStaked -= amount;

        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external {
        uint256 reward = _pendingReward(msg.sender);
        require(reward > 0, "No reward to claim");

        stakes[msg.sender].rewardDebt = 0;
        rewardToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function _pendingReward(address _user) internal view returns (uint256) {
        Stake storage stake = stakes[_user];
        uint256 reward = stake.amount * rewardRate - stake.rewardDebt;
        return reward;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }
}