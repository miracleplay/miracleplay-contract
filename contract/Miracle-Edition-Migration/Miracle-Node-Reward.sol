// SPDX-License-Identifier: MIT
// Miracle-Node-RewardManager 1.1.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MiracleNodeRewardManager is PermissionsEnumerable, Multicall, ContractMetadata {
    address public daoAddress;
    address public deployer;
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    uint256 public totalMinted;
    uint256 public totalEarlyClaimedPenalty;
    address public managerFeeAddress;
    uint256 public managerFeeRate = 500;  // 500 = 5%
    uint256 public totalManagerFee;

    uint256 private constant MONTH = 30 days; // 30 days = 2592000 seconds

    struct RewardInfo {
        bool isRegistered;
        bool isClaimed;
        uint256 amount;
        uint256 calculationTime;
    }

    mapping(address => mapping(uint256 => RewardInfo)) public rewards;

    event RewardUpdated(address indexed user, uint256 indexed month, uint256 amount, uint256 calculationTime);
    event RewardClaimed(address indexed user, uint256 indexed month, uint256 amount, uint256 fee);
    event RewardDeposited(uint256 amount);
    event RewardWithdrawn(uint256 amount);
    event DaoNodeFeeMinted(uint256 amount);
    event EmergencyWithdrawn(uint256 amount, address to);

    constructor(
        string memory _contractURI,
        address _deployer,
        address _daoAddress,
        address _managerFeeAddress
    ) {
        require(_daoAddress != address(0), "Invalid DAO address");
        require(_managerFeeAddress != address(0), "Invalid manager fee address");
        
        deployer = _deployer;
        daoAddress = _daoAddress;
        managerFeeAddress = _managerFeeAddress;
        
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function updateReward(address user, uint256 month, uint256 amount, uint256 calculationTime) external onlyRole(FACTORY_ROLE) {
        require(user != address(0), "Invalid user address");
        RewardInfo storage reward = rewards[user][month];
        require(!reward.isRegistered, "Reward already registered");

        rewards[user][month] = RewardInfo({
            isRegistered: true,
            isClaimed: false,
            amount: amount,
            calculationTime: calculationTime
        });
        emit RewardUpdated(user, month, amount, calculationTime);
    }

    function updateRewardBatch(
        address[] calldata _users, 
        uint256[] calldata _months, 
        uint256[] calldata _amounts, 
        uint256[] calldata _calculationTimes
    ) external onlyRole(FACTORY_ROLE) {
        require(
            _users.length == _months.length &&
            _users.length == _amounts.length &&
            _users.length == _calculationTimes.length,
            "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            uint256 month = _months[i];
            uint256 amount = _amounts[i];
            uint256 calculationTime = _calculationTimes[i];

            require(user != address(0), "Invalid user address");
            RewardInfo storage reward = rewards[user][month];
            require(!reward.isRegistered, "Reward already registered");

            rewards[user][month] = RewardInfo({
                isRegistered: true,
                isClaimed: false,
                amount: amount,
                calculationTime: calculationTime
            });

            emit RewardUpdated(user, month, amount, calculationTime);
        }
    }

    function _processRewardClaim(address user, uint256 month) internal returns (uint256 claimAmount, uint256 fee) {
        RewardInfo storage reward = rewards[user][month];
        require(reward.isRegistered, "Reward not registered");
        require(!reward.isClaimed, "Reward already claimed");
        require(address(this).balance >= reward.amount, "Insufficient contract balance");

        uint256 timeElapsed = block.timestamp - reward.calculationTime;
        uint256 rewardAmount = reward.amount;

        if (timeElapsed >= 3 * MONTH) {
            fee = 0;
        } else if (timeElapsed >= 2 * MONTH) {
            fee = (rewardAmount * 25) / 100;
        } else if (timeElapsed >= MONTH) {
            fee = (rewardAmount * 50) / 100;
        } else {
            fee = (rewardAmount * 75) / 100;
        }

        uint256 managerFee = (rewardAmount * managerFeeRate) / 10000;
        
        claimAmount = rewardAmount - fee - managerFee;
        reward.isClaimed = true;

        if (fee > 0) {
            (bool feeSuccess, ) = payable(daoAddress).call{value: fee}("");
            require(feeSuccess, "DAO fee transfer failed");
            totalEarlyClaimedPenalty += fee;
        }

        if (managerFee > 0) {
            (bool managerSuccess, ) = payable(managerFeeAddress).call{value: managerFee}("");
            require(managerSuccess, "Manager fee transfer failed");
            totalManagerFee += managerFee;
        }

        if (claimAmount > 0) {
            (bool success, ) = payable(user).call{value: claimAmount}("");
            require(success, "Reward transfer failed");
            totalMinted += claimAmount;
        }

        emit RewardClaimed(user, month, claimAmount, fee);
    }

    function claimReward(uint256 month) external {
        _processRewardClaim(msg.sender, month);
    }

    function claimRewardAgent(address user, uint256 month) external onlyRole(FACTORY_ROLE) {
        require(user != address(0), "Invalid user address");
        _processRewardClaim(user, month);
    }

    function claimRewardAgentBatch(address[] calldata _users, uint256[] calldata _months) external onlyRole(FACTORY_ROLE) {
        require(_users.length == _months.length, "Input arrays length mismatch");

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            require(user != address(0), "Invalid user address");
            _processRewardClaim(user, _months[i]);
        }
    }

    function mintDaoNodeFee(uint256 amount) external onlyRole(FACTORY_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        (bool success, ) = payable(daoAddress).call{value: amount}("");
        require(success, "Transfer failed");
        totalEarlyClaimedPenalty += amount;

        emit DaoNodeFeeMinted(amount);
    }

    function getRewardInfoBatch(address user, uint256[] calldata _months) external view returns (RewardInfo[] memory) {
        require(user != address(0), "Invalid user address");
        uint256 length = _months.length;
        RewardInfo[] memory batchRewards = new RewardInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            batchRewards[i] = rewards[user][_months[i]];
        }

        return batchRewards;
    }

    function getRewardClaimableBatch(address user, uint256[] calldata _months) external view returns (bool[] memory){
        require(user != address(0), "Invalid user address");
        uint256 length = _months.length;
        bool[] memory claimableStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            RewardInfo storage reward = rewards[user][_months[i]];
            if (reward.isRegistered && !reward.isClaimed && block.timestamp >= reward.calculationTime + 4 weeks) {
                claimableStatuses[i] = true;
            } else {
                claimableStatuses[i] = false;
            }
        }

        return claimableStatuses;
    }

    function getRewardInfo(address user, uint256 month) external view returns (RewardInfo memory) {
        return rewards[user][month];
    }

    function getTotalMintedAmount() external view returns (uint256) {
        return totalMinted + totalEarlyClaimedPenalty + totalManagerFee;
    }

    receive() external payable {}

    function deposit() external payable {
        emit RewardDeposited(msg.value);
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Emergency withdraw failed");
        
        emit EmergencyWithdrawn(balance, msg.sender);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
