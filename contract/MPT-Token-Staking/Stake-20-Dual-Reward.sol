// SPDX-License-Identifier: MIT

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   Miracleplay ERC-20 to ERC-20 staking v1.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

interface IMintableERC20 is IERC20 {
    function mintTo(address to, uint256 amount) external;
}

contract DualRewardAPRStaking is PermissionsEnumerable, ContractMetadata {
    address public deployer;
    IERC20 public stakingToken;
    IMintableERC20 public rewardToken1;
    IMintableERC20 public rewardToken2;

    uint256 private reward1APR;
    uint256 private reward2APR;

    uint256 private totalStakedTokens;

    bool public PausePool;

    struct Staker {
        uint256 stakedAmount;
        uint256 lastUpdateTime;
        uint256 reward1Earned;
        uint256 reward2Earned;
    }

    mapping(address => Staker) public stakers;

    constructor(
        address _adminAddr,
        address _stakingToken,
        address _rewardToken1,
        address _rewardToken2,
        uint256 _reward1APR,
        uint256 _reward2APR,
        string memory _contractURI
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddr);
        stakingToken = IERC20(_stakingToken);
        rewardToken1 = IMintableERC20(_rewardToken1);
        rewardToken2 = IMintableERC20(_rewardToken2);
        reward1APR = (_reward1APR * 1e18 / 100) / 31536000;
        reward2APR = (_reward2APR * 1e18 / 100) / 31536000;
        PausePool = false;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function stake(uint256 amount) external {
        updateRewards(msg.sender);
        stakers[msg.sender].stakedAmount += amount;
        totalStakedTokens += amount;
        require(stakingToken.transferFrom(msg.sender, address(this), amount));
    }

    function withdraw(uint256 amount) external {
        require(stakers[msg.sender].stakedAmount >= amount, "Not enough balance");
        updateRewards(msg.sender);
        stakers[msg.sender].stakedAmount -= amount;
        totalStakedTokens -= amount;
        require(stakingToken.transfer(msg.sender, amount));
    }

    function claimRewards() external {
        require(!PausePool, "Pool is in pause state.");
        updateRewards(msg.sender);

        uint256 reward1 = stakers[msg.sender].reward1Earned;
        uint256 reward2 = stakers[msg.sender].reward2Earned;

        if (reward1 > 0) {
            rewardToken1.transfer(msg.sender, reward1);
            stakers[msg.sender].reward1Earned = 0;
        }

        if (reward2 > 0) {
            rewardToken2.mintTo(msg.sender, reward2);
            stakers[msg.sender].reward2Earned = 0;
        }
    }

    function updateRewards(address staker) internal {
        Staker storage user = stakers[staker];
        uint256 timeElapsed = block.timestamp - user.lastUpdateTime;
        user.reward1Earned += timeElapsed * reward1APR * user.stakedAmount;
        user.reward2Earned += timeElapsed * reward2APR * user.stakedAmount;
        user.lastUpdateTime = block.timestamp;
    }

    function setToken1APR(uint256 _rate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        reward1APR = (_rate * 1e18 / 100) / 31536000;
    }

    function setToken2APR(uint256 _rate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        reward2APR = (_rate * 1e18 / 100) / 31536000;
    }

    function getCurrentToken1APR() public view returns (uint256) {
        uint256 annualReward = reward1APR * 31536000;
        uint256 aprWithDecimal = (annualReward * 100) / 1e18;
        uint256 remainder = (annualReward * 100) % 1e18;
        if (remainder > 0) {
            aprWithDecimal += 1;
        }
        return aprWithDecimal;
    }

    function getCurrentToken2APR() public view returns (uint256) {
        uint256 annualReward = reward2APR * 31536000;
        uint256 aprWithDecimal = (annualReward * 100) / 1e18;
        uint256 remainder = (annualReward * 100) % 1e18;
        if (remainder > 0) {
            aprWithDecimal += 1;
        }
        return aprWithDecimal;
    }

    function getRemindToken1() public view returns (uint256) {
        uint256 totalBalance = IERC20(rewardToken1).balanceOf(address(this));
        return totalBalance - totalStakedTokens;
    }

    function getRemindToken2() public view returns (uint256) {
        return IERC20(rewardToken2).balanceOf(address(this));
    }

    function calculateRewards(address staker) public view returns (uint256 reward1, uint256 reward2) {
        Staker memory user = stakers[staker];
        uint256 timeElapsed = block.timestamp - user.lastUpdateTime;
        reward1 = user.reward1Earned + ((timeElapsed * reward1APR * user.stakedAmount) / 1e18);
        reward2 = user.reward2Earned + ((timeElapsed * reward2APR * user.stakedAmount) / 1e18);
    }

    function getTotalStakedBalance() public view returns (uint256) {
        return totalStakedTokens;
    }
    
    function emergencyWithdrawRewardToken1() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint amount = getRemindToken1();
        IERC20(rewardToken1).transfer(msg.sender, amount);
    }

    function emergencyWithdrawRewardToken2() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint amount = getRemindToken2();
        IERC20(rewardToken1).transfer(msg.sender, amount);
    }
}
