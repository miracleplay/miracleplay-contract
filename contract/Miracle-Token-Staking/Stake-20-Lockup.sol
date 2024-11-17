// TimeLockedStakingWithAPR V1.0.0
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";


contract TimeLockedStakingWithAPR is PermissionsEnumerable, ContractMetadata, Multicall {
    address public deployer;
    IERC20 public stakingToken;
    uint256 public stakingStartTime;
    uint256 public stakingEndTime;
    uint256 public stakingDuration;
    uint256 public apr;
    bool public isPaused = false;
    uint256 public totalStakedAmount;

    struct Staker {
        uint256 stakedAmount;
        uint256 rewardEarned;
        bool hasClaimed;
    }

    address[] public stakerAddresses;
    mapping(address => Staker) public stakers;

    constructor(address _adminAddr, address _stakingToken, uint256 _stakingStartTime, uint256 _stakingDurationInDays, uint256 _apr, string memory _contractURI) {
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddr);
        stakingToken = IERC20(_stakingToken);
        stakingStartTime = _stakingStartTime;
        stakingDuration = _stakingDurationInDays * 1 days;
        apr = _apr;
        stakingEndTime = stakingStartTime + stakingDuration;
        deployer = _adminAddr;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    modifier onlyDuringStakingPeriod() {
        require(block.timestamp < stakingEndTime, "Staking period has ended");
        _;
    }

    modifier onlyAfterStakingPeriod() {
        require(block.timestamp >= stakingEndTime, "Staking period is not over yet");
        _;
    }

    modifier onlyBeforeStakingStart() {
        require(block.timestamp < stakingStartTime, "Staking period has started");
        _;
    }

    modifier whenNotPaused() {
        require(!isPaused, "Staking is paused");
        _;
    }

    function stake(uint256 amount) external onlyBeforeStakingStart whenNotPaused {
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        if (stakers[msg.sender].stakedAmount == 0) {
            stakerAddresses.push(msg.sender);
        }
        stakers[msg.sender].stakedAmount += amount;
        totalStakedAmount += amount;
    }

    function calculateReward(address staker) public view returns (uint256) {
        Staker storage user = stakers[staker];
        uint256 timeStaked = stakingEndTime - stakingStartTime;
        uint256 annualReward = (user.stakedAmount * apr) / 100;
        uint256 reward = (annualReward * timeStaked) / 365 days;
        return reward;
    }

    function claim() external onlyAfterStakingPeriod whenNotPaused{
        Staker storage user = stakers[msg.sender];
        require(user.stakedAmount > 0, "No staked tokens");
        require(!user.hasClaimed, "Rewards already claimed");

        uint256 reward = calculateReward(msg.sender);
        user.rewardEarned = reward;
        user.hasClaimed = true;

        require(stakingToken.transfer(msg.sender, user.stakedAmount), "Staking token transfer failed");
        require(stakingToken.transfer(msg.sender, reward), "Reward token transfer failed");
    }

    function depositRewards(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    function pauseStaking() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPaused = true;
    }

    function unpauseStaking() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPaused = false;
    }

    function getStakerInfo(address staker) external view returns (uint256 stakedAmount, uint256 rewardEarned, bool hasClaimed) {
        Staker storage user = stakers[staker];
        return (user.stakedAmount, user.rewardEarned, user.hasClaimed);
    }

    function getRewardAmount(address staker) external view returns (uint256) {
        return calculateReward(staker);
    }

    function getStakingTokenBalance() external view returns (uint256) {
        return totalStakedAmount;
    }

    function getRewardTokenBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this)) - totalStakedAmount;
    }

    function getTotalRewards() external view returns (uint256) {
        uint256 timeStaked = stakingEndTime - stakingStartTime;
        uint256 annualReward = (totalStakedAmount * apr) / 100;
        uint256 totalReward = (annualReward * timeStaked) / 365 days;
        return totalReward;
    }

    function getTimeUntilStakingEnds() external view returns (uint256) {
        if (block.timestamp >= stakingEndTime) {
            return 0;
        } else {
            return stakingEndTime - block.timestamp;
        }
    }

    function getStakerCount() external view returns (uint256) {
        return stakerAddresses.length;
    }

    function getStakerAddress(uint256 index) external view returns (address) {
        require(index < stakerAddresses.length, "Index out of bounds");
        return stakerAddresses[index];
    }

    function getStakerAddressWithInfo(uint256 index) external view returns (address stakerAddress, uint256 stakedAmount, uint256 rewardEarned, bool hasClaimed) {
        require(index < stakerAddresses.length, "Index out of bounds");
        address stakerAddress = stakerAddresses[index];
        Staker storage user = stakers[stakerAddress];
        return (stakerAddress, user.stakedAmount, user.rewardEarned, user.hasClaimed);
    }

    function getStakingDuration() external view returns (uint256) {
        return stakingDuration;
    }

    function getAPR() external view returns (uint256) {
        return apr;
    }
}