// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SLGStakingToSLP is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public slgToken;
    IERC20 public slpToken;

    mapping(address => uint256) private _stakes;
    mapping(address => uint256) private _rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(IERC20 _slgToken, IERC20 _slpToken) {
        slgToken = _slgToken;
        slpToken = _slpToken;
    }

    function stake(uint256 amount) external {
        _stakes[msg.sender] += amount;
        slgToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(_stakes[msg.sender] >= amount, "SLGStaking: Cannot withdraw more than staked");
        _stakes[msg.sender] -= amount;
        slgToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external {
        uint256 reward = _rewards[msg.sender];
        require(reward > 0, "SLGStaking: No reward to claim");
        _rewards[msg.sender] = 0;
        slpToken.safeTransfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function _addReward(address account, uint256 amount) internal {
        _rewards[account] += amount;
    }

    function distributeRewards(address[] calldata stakers, uint256[] calldata rewards) external onlyOwner {
        require(stakers.length == rewards.length, "SLGStaking: Stakers and rewards length mismatch");

        for (uint256 i = 0; i < stakers.length; i++) {
            _addReward(stakers[i], rewards[i]);
        }
    }

    function getStake(address account) external view returns (uint256) {
        return _stakes[account];
    }

    function getReward(address account) external view returns (uint256) {
        return _rewards[account];
    }
}