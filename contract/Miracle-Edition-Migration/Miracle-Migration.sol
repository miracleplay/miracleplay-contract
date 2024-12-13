// SPDX-License-Identifier: MIT
// EditionMigration 1.3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract EditionMigration is PermissionsEnumerable, Multicall, ContractMetadata, ERC1155Holder {
    uint256 public maxTokenId = 0;
    IERC1155 public erc1155Token; // ERC-1155 token contract address
    address public deployer;

    // Migration state variables
    bool public isMigrationPaused;
    bool public isWithdrawPaused;
    uint256 public migrationPausedTime;

    // Mapping to track the total amount of tokens migrated per user per token ID
    mapping(address => mapping(uint256 => uint256)) public migratedTokens;

    // Array to store all migrated users
    address[] public migratedUsers;

    // Mapping to track if a user has already been added to the array
    mapping(address => bool) private hasUserMigrated;

    // Events
    event Migration(address indexed user, uint256 indexed tokenId, uint256 amount, uint256 timestamp);
    event MigrationPaused(address indexed admin, uint256 timestamp);
    event MigrationResumed(address indexed admin, uint256 timestamp);
    event Withdrawal(address indexed user, uint256 indexed tokenId, uint256 amount, uint256 timestamp);

    error ExistingMigratedTokens(address user, uint256 tokenId, uint256 amount);
    error InvalidTokenId(uint256 tokenId);

    // Constructor to initialize the contract without setting the ERC-1155 token address
    constructor(string memory _contractURI, address _deployer, address _erc1155TokenAddress, uint256 _maxTokenId) {
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        deployer = _deployer;
        _setupContractURI(_contractURI);
        erc1155Token = IERC1155(_erc1155TokenAddress);
        maxTokenId = _maxTokenId;
        isMigrationPaused = false;
        isWithdrawPaused = false;
    }

    // Modifier to check if migration is active
    modifier whenMigrationActive() {
        require(!isMigrationPaused, "Migration is currently paused");
        _;
    }

    // Modifier to check if migration is active
    modifier whenNotPaused() {
    require(!isMigrationPaused && !isWithdrawPaused, "Migration or withdrawal is currently paused");
    _;
    }

    // Function to pause migration (only admin)
    function pauseMigration() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isMigrationPaused, "Migration is already paused");
        isMigrationPaused = true;
        migrationPausedTime = block.timestamp;
        emit MigrationPaused(msg.sender, block.timestamp);
    }

    // Function to resume migration (only admin)
    function resumeMigration() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isMigrationPaused, "Migration is not paused");
        isMigrationPaused = false;
        emit MigrationResumed(msg.sender, block.timestamp);
    }

    // Function to pause withdrawal (only admin)
    function pauseWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isWithdrawPaused, "Withdrawal is already paused");
        isWithdrawPaused = true;
        emit MigrationPaused(msg.sender, block.timestamp);
    }

    // Function to resume withdrawal (only admin)
    function resumeWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isWithdrawPaused, "Withdrawal is not paused");
        isWithdrawPaused = false;
        emit MigrationResumed(msg.sender, block.timestamp);
    }

    // Function to set or update the ERC-1155 token contract address (only callable by admin)
    function setERC1155Token(address _erc1155TokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_erc1155TokenAddress != address(0), "Invalid ERC-1155 token address");
        erc1155Token = IERC1155(_erc1155TokenAddress);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    // Function to migrate the user's ERC-1155 tokens to the contract
    function migrate(uint256 tokenId) external whenMigrationActive {
        require(address(erc1155Token) != address(0), "ERC-1155 token address not set");
        if (tokenId >= maxTokenId) revert InvalidTokenId(tokenId);

        // Check if user has any existing migrated tokens
        for (uint256 i = 0; i < maxTokenId; i++) {
            if (migratedTokens[msg.sender][i] > 0) {
                revert ExistingMigratedTokens(msg.sender, i, migratedTokens[msg.sender][i]);
            }
        }

        uint256 userBalance = erc1155Token.balanceOf(msg.sender, tokenId);
        require(userBalance > 0, "You do not own any of this token");
        require(erc1155Token.isApprovedForAll(msg.sender, address(this)), "Contract not approved to transfer tokens");

        erc1155Token.safeTransferFrom(msg.sender, address(this), tokenId, userBalance, "");
        migratedTokens[msg.sender][tokenId] = userBalance;

        if (!hasUserMigrated[msg.sender]) {
            migratedUsers.push(msg.sender);
            hasUserMigrated[msg.sender] = true;
        }

        emit Migration(msg.sender, tokenId, userBalance, block.timestamp);
    }

    // Modified withdraw function to withdraw all tokens of a specific tokenId
    function withdraw(uint256 tokenId) external whenNotPaused {
        require(address(erc1155Token) != address(0), "ERC-1155 token address not set");
        if (tokenId >= maxTokenId) revert InvalidTokenId(tokenId);

        uint256 amount = migratedTokens[msg.sender][tokenId];
        require(amount > 0, "No tokens to withdraw");

        migratedTokens[msg.sender][tokenId] = 0;
        erc1155Token.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");

        bool hasOtherTokens = false;
        for (uint256 i = 0; i < migratedUsers.length; i++) {
            if (migratedUsers[i] == msg.sender) {
                for (uint256 j = 0; j < maxTokenId; j++) {
                    if (migratedTokens[msg.sender][j] > 0) {
                        hasOtherTokens = true;
                        break;
                    }
                }
                if (!hasOtherTokens) {
                    migratedUsers[i] = migratedUsers[migratedUsers.length - 1];
                    migratedUsers.pop();
                    hasUserMigrated[msg.sender] = false;
                }
                break;
            }
        }

        emit Withdrawal(msg.sender, tokenId, amount, block.timestamp);
    }

    // Function to get the number of tokens migrated by a specific user for a given token ID
    function getMigratedUser(address user, uint256 tokenId) external view returns (uint256) {
        return migratedTokens[user][tokenId];
    }

    // Function to get total number of users who have migrated tokens
    function getTotalMigratedUsers() external view returns (uint256) {
        return migratedUsers.length;
    }

    // Function to get user address by index
    function getMigratedUserByIndex(uint256 index) external view returns (address) {
        require(index < migratedUsers.length, "Index out of bounds");
        return migratedUsers[index];
    }

    // Function to check if a user has migrated any tokens
    function getHasUserMigratedTokens(address user) external view returns (bool) {
        return hasUserMigrated[user];
    }

    // Function to get migration status and pause time
    function getMigrationStatus() external view returns (bool isPaused, uint256 pauseTime) {
        return (isMigrationPaused, migrationPausedTime);
    }
}