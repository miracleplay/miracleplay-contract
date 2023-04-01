// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@thirdweb-dev/contracts/base/Staking20Base.sol";
import "@thirdweb-dev/contracts/token/TokenERC20.sol";

contract StakingContract is Staking20Base {
    constructor(
        uint256 _timeUnit,
        uint256 _rewardRatioNumerator,
        uint256 _rewardRatioDenominator,
        address _stakingToken,
        address _rewardToken,
        address _nativeTokenWrapper
    ) Staking20Base(
        _timeUnit, // In number of seconds. For e.g., if you want to give out rewards per hour, then enter 3600 as the number of seconds, because the time unit is 1 hour in this case.
        _rewardRatioNumerator, //For e.g., if reward ratio is 1/20, this implies that there will be 1 Reward token given out for every 20 tokens staked. The numerator and denominator of the reward ratio should be set separately (1 and 20 in this case respectively).
        _rewardRatioDenominator, //For e.g., if reward ratio is 1/20, this implies that there will be 1 Reward token given out for every 20 tokens staked. The numerator and denominator of the reward ratio should be set separately (1 and 20 in this case respectively).
        _stakingToken,
        _rewardToken,
        _nativeTokenWrapper
    ) {}

    function _mintRewards(address _staker, uint256 _rewards) internal override {
        TokenERC20 tokenContract = TokenERC20(rewardToken);
        tokenContract.mintTo(_staker, _rewards);
    }

    function calculateRewards(address _player) external view virtual returns (uint256 rewards) {
        rewards = _calculateRewards(_player);
    }

    function sizeOfPool() external view returns (uint256 size) {
        return stakingTokenBalance; 
    }
    
}