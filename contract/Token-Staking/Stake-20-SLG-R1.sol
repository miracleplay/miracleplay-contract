// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingContract is ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public totalStaked;
    uint256 public totalRewards;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(address indexed user, uint256 reward);

    uint256 public constant DURATION = 365 days;

    uint256 public rewardRate;
    uint256 public lastUpdate;

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardPerYear) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);

        rewardRate = _rewardPerYear.div(DURATION);
        lastUpdate = block.timestamp;
    }

    function stake(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");
        require(stakingToken.balanceOf(msg.sender) >= amount, "Insufficient balance");

        updateReward(msg.sender);

        stakingToken.transferFrom(msg.sender, address(this), amount);

        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(amount);
        totalStaked = totalStaked.add(amount);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");

        updateReward(msg.sender);

        stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(amount);
        totalStaked = totalStaked.sub(amount);

        stakingToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claim() public nonReentrant {
        updateReward(msg.sender);

        require(rewards[msg.sender] > 0, "No rewards available");

        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;

        rewardToken.transfer(msg.sender, reward);

        emit RewardPaid(msg.sender, reward);
    }

    function exit() public nonReentrant {
        withdraw(stakedBalance[msg.sender]);
        claim();
    }

    function updateReward(address account) private nonReentrant {
        uint256 currentTime = block.timestamp;
        uint256 duration = currentTime.sub(lastUpdate);

        if (totalStaked > 0) {
            uint256 reward = totalRewards.mul(duration).mul(stakedBalance[account]).div(totalStaked).div(1e18);
            rewards[account] = rewards[account].add(reward);
        }

        lastUpdateTime[account] = currentTime;
        lastUpdate = currentTime;
    }

    function addReward(uint256 amount) public {
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        totalRewards = totalRewards.add(amount);

        emit RewardAdded(msg.sender, amount);
    }
}