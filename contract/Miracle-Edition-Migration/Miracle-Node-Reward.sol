// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardManager is Ownable {
    IERC20 public rewardToken;
    address public daoAddress;

    struct RewardInfo {
        bool isRegistered;
        bool isClaimed;
        uint256 amount;
        uint256 calculationTime;
    }

    mapping(address => mapping(uint256 => RewardInfo)) public rewards;

    event RewardUpdated(address indexed user, uint256 indexed week, uint256 amount, uint256 calculationTime);
    event RewardClaimed(address indexed user, uint256 indexed week, uint256 amount, uint256 fee);
    event RewardDeposited(uint256 amount);
    event RewardWithdrawn(uint256 amount);

    constructor(address _rewardToken, address _daoAddress) {
        require(_rewardToken != address(0), "Invalid reward token address");
        require(_daoAddress != address(0), "Invalid DAO address");
        rewardToken = IERC20(_rewardToken);
        daoAddress = _daoAddress;
    }

    // 관리자가 리워드 토큰 예치
    function depositReward(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        rewardToken.transferFrom(msg.sender, address(this), amount);
        emit RewardDeposited(amount);
    }

    // 관리자가 리워드 토큰 출금
    function withdrawReward(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        rewardToken.transfer(msg.sender, amount);
        emit RewardWithdrawn(amount);
    }

    // 리워드 업데이트
    function updateReward(
        address user,
        uint256 week,
        uint256 amount,
        uint256 calculationTime
    ) external onlyOwner {
        require(user != address(0), "Invalid user address");
        RewardInfo storage reward = rewards[user][week];
        require(!reward.isRegistered, "Reward already registered");

        rewards[user][week] = RewardInfo({
            isRegistered: true,
            isClaimed: false,
            amount: amount,
            calculationTime: calculationTime
        });
        emit RewardUpdated(user, week, amount, calculationTime);
    }

    // 리워드 클레임
    function claimReward(uint256 week) external {
        RewardInfo storage reward = rewards[msg.sender][week];
        require(reward.isRegistered, "Reward not registered");
        require(!reward.isClaimed, "Reward already claimed");

        uint256 timeElapsed = block.timestamp - reward.calculationTime;
        uint256 rewardAmount = reward.amount;
        uint256 fee;
        if (timeElapsed >= 4 weeks) {
            fee = 0;
        } else if (timeElapsed >= 3 weeks) {
            fee = (rewardAmount * 25) / 100;
        } else if (timeElapsed >= 2 weeks) {
            fee = (rewardAmount * 50) / 100;
        } else if (timeElapsed >= 1 weeks) {
            fee = (rewardAmount * 75) / 100;
        } else {
            fee = rewardAmount;
        }

        uint256 claimAmount = rewardAmount - fee;
        reward.isClaimed = true;

        if (fee > 0) {
            rewardToken.transfer(daoAddress, fee);
        }
        if (claimAmount > 0) {
            rewardToken.transfer(msg.sender, claimAmount);
        }

        emit RewardClaimed(msg.sender, week, claimAmount, fee);
    }

    function getRewardInfoBatch(address user, uint256[] calldata weeks) external view returns (RewardInfo[] memory){
        require(user != address(0), "Invalid user address");
        uint256 length = weeks.length;
        RewardInfo[] memory batchRewards = new RewardInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            batchRewards[i] = rewards[user][weeks[i]];
        }

        return batchRewards;
    }

    // 리워드 조회
    function getRewardInfo(address user, uint256 week) external view returns (RewardInfo memory) {
        return rewards[user][week];
    }


}
