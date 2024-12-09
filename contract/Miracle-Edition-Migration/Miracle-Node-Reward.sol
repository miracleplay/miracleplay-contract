// SPDX-License-Identifier: MIT
// RewardManager 1.0.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract RewardManager is PermissionsEnumerable, Multicall, ContractMetadata {
    IERC20 public rewardToken;
    address public daoAddress;
    address public deployer;
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

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

    constructor(string memory _contractURI, address _deployer, address _rewardToken, address _daoAddress) {
        require(_rewardToken != address(0), "Invalid reward token address");
        require(_daoAddress != address(0), "Invalid DAO address");
        deployer = _deployer;
        rewardToken = IERC20(_rewardToken);
        daoAddress = _daoAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function depositReward(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, "Amount must be greater than zero");
        rewardToken.transferFrom(msg.sender, address(this), amount);
        emit RewardDeposited(amount);
    }

    function withdrawReward(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, "Amount must be greater than zero");
        rewardToken.transfer(msg.sender, amount);
        emit RewardWithdrawn(amount);
    }

    function updateReward(address user, uint256 week, uint256 amount, uint256 calculationTime) external onlyRole(FACTORY_ROLE) {
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

    function updateRewardBatch(address[] calldata _users, uint256[] calldata _weeks, uint256[] calldata _amounts, uint256[] calldata _calculationTimes) external onlyRole(FACTORY_ROLE) {
        require(
            _users.length == _weeks.length &&
            _users.length == _amounts.length &&
            _users.length == _calculationTimes.length,
            "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            uint256 week = _weeks[i];
            uint256 amount = _amounts[i];
            uint256 calculationTime = _calculationTimes[i];

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
    }

    function claimReward(uint256 week) external {
        RewardInfo storage reward = rewards[msg.sender][week];
        require(reward.isRegistered, "Reward not registered");
        require(!reward.isClaimed, "Reward already claimed");

        uint256 timeElapsed = block.timestamp - reward.calculationTime;
        uint256 rewardAmount = reward.amount;
        uint256 fee;
        if (timeElapsed >= 3 weeks) {
            fee = 0;
        } else if (timeElapsed >= 2 weeks) {
            fee = (rewardAmount * 25) / 100;
        } else if (timeElapsed >= 1 weeks) {
            fee = (rewardAmount * 50) / 100;
        } else {
            fee = (rewardAmount * 75) / 100;
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

    function claimRewardAgent(address user, uint256 week) external onlyRole(FACTORY_ROLE) {
        require(user != address(0), "Invalid user address");
        RewardInfo storage reward = rewards[user][week];
        require(reward.isRegistered, "Reward not registered");
        require(!reward.isClaimed, "Reward already claimed");

        uint256 timeElapsed = block.timestamp - reward.calculationTime;
        uint256 rewardAmount = reward.amount;
        uint256 fee;

        if (timeElapsed >= 3 weeks) {
            fee = 0;
        } else if (timeElapsed >= 2 weeks) {
            fee = (rewardAmount * 25) / 100;
        } else if (timeElapsed >= 1 weeks) {
            fee = (rewardAmount * 50) / 100;
        } else {
            fee = (rewardAmount * 75) / 100;
        }

        uint256 claimAmount = rewardAmount - fee;
        reward.isClaimed = true;

        if (fee > 0) {
            rewardToken.transfer(daoAddress, fee);
        }
        if (claimAmount > 0) {
            rewardToken.transfer(user, claimAmount);
        }

        emit RewardClaimed(user, week, claimAmount, fee);
    }

    function claimRewardAgentBatch(address[] calldata _users, uint256[] calldata _weeks) external onlyRole(FACTORY_ROLE) {
        require(_users.length == _weeks.length, "Input arrays length mismatch");

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            uint256 week = _weeks[i];

            require(user != address(0), "Invalid user address");

            RewardInfo storage reward = rewards[user][week];
            require(reward.isRegistered, "Reward not registered");
            require(!reward.isClaimed, "Reward already claimed");

            uint256 timeElapsed = block.timestamp - reward.calculationTime;
            uint256 rewardAmount = reward.amount;
            uint256 fee;

            if (timeElapsed >= 3 weeks) {
                fee = 0;
            } else if (timeElapsed >= 2 weeks) {
                fee = (rewardAmount * 25) / 100;
            } else if (timeElapsed >= 1 weeks) {
                fee = (rewardAmount * 50) / 100;
            } else {
                fee = (rewardAmount * 75) / 100;
            }

            uint256 claimAmount = rewardAmount - fee;
            reward.isClaimed = true;

            if (fee > 0) {
                rewardToken.transfer(daoAddress, fee);
            }
            if (claimAmount > 0) {
                rewardToken.transfer(user, claimAmount);
            }

            emit RewardClaimed(user, week, claimAmount, fee);
        }
    }

    function getRewardInfoBatch(address user, uint256[] calldata _weeks) external view returns (RewardInfo[] memory){
        require(user != address(0), "Invalid user address");
        uint256 length = _weeks.length;
        RewardInfo[] memory batchRewards = new RewardInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            batchRewards[i] = rewards[user][_weeks[i]];
        }

        return batchRewards;
    }

    function getRewardClaimableBatch(address user, uint256[] calldata _weeks) external view returns (bool[] memory){
        require(user != address(0), "Invalid user address");
        uint256 length = _weeks.length;
        bool[] memory claimableStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            RewardInfo storage reward = rewards[user][_weeks[i]];
            if (reward.isRegistered && !reward.isClaimed && block.timestamp >= reward.calculationTime + 4 weeks) {
                claimableStatuses[i] = true;
            } else {
                claimableStatuses[i] = false;
            }
        }

        return claimableStatuses;
    }

    function getRewardInfo(address user, uint256 week) external view returns (RewardInfo memory) {
        return rewards[user][week];
    }
}
