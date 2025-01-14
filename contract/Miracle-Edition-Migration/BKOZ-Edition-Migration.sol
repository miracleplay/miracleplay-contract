// SPDX-License-Identifier: MIT
// SingleEditionMigration 1.0.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract BKOZEditionMigration is PermissionsEnumerable, Multicall, ContractMetadata, ERC1155Holder {
    IERC1155 public erc1155Token;
    address public deployer;

    bool public isMigrationPaused;
    bool public isWithdrawPaused;
    uint256 public migrationPausedTime;

    mapping(address => uint256[]) public userMigratedTokenIds;
    mapping(uint256 => bool) public isTokenMigrated;
    mapping(uint256 => address) public tokenOwner;

    address[] public migratedUsers;
    mapping(address => bool) public hasUserMigrated;

    mapping(address => mapping(uint256 => uint256)) public userTokenAmounts;

    event TokensMigrated(address indexed user, uint256[] tokenIds, uint256[] amounts, uint256 timestamp);
    event MigrationPaused(address indexed admin, uint256 timestamp);
    event MigrationResumed(address indexed admin, uint256 timestamp);
    event WithdrawalPaused(address indexed admin, uint256 timestamp);
    event WithdrawalResumed(address indexed admin, uint256 timestamp);
    event TokensWithdrawn(address indexed user, uint256[] tokenIds, uint256[] amounts, uint256 timestamp);

    constructor(string memory _contractURI, address _deployer, address _erc1155TokenAddress) {
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        deployer = _deployer;
        erc1155Token = IERC1155(_erc1155TokenAddress);
        _setupContractURI(_contractURI);
        isMigrationPaused = false;
        isWithdrawPaused = false;
    }

    modifier whenMigrationActive() {
        require(!isMigrationPaused, "Migration is currently paused");
        _;
    }

    modifier whenWithdrawActive() {
        require(!isWithdrawPaused, "Withdrawal is currently paused");
        _;
    }

    function pauseMigration() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isMigrationPaused, "Migration is already paused");
        isMigrationPaused = true;
        migrationPausedTime = block.timestamp;
        emit MigrationPaused(msg.sender, block.timestamp);
    }

    function resumeMigration() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isMigrationPaused, "Migration is not paused");
        isMigrationPaused = false;
        emit MigrationResumed(msg.sender, block.timestamp);
    }

    function pauseWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isWithdrawPaused, "Withdrawal is already paused");
        isWithdrawPaused = true;
        emit WithdrawalPaused(msg.sender, block.timestamp);
    }

    function resumeWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isWithdrawPaused, "Withdrawal is not paused");
        isWithdrawPaused = false;
        emit WithdrawalResumed(msg.sender, block.timestamp);
    }

    function setERC1155Token(address _erc1155TokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_erc1155TokenAddress != address(0), "Invalid ERC-1155 token address");
        erc1155Token = IERC1155(_erc1155TokenAddress);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function migrate(uint256 tokenId) external whenMigrationActive {
        require(address(erc1155Token) != address(0), "ERC-1155 token address not set");
        require(erc1155Token.isApprovedForAll(msg.sender, address(this)), "Contract not approved to transfer tokens");
        require(tokenId == 0 || tokenId == 1, "Invalid token ID. Only 0 and 1 are allowed");

        uint256 balance = erc1155Token.balanceOf(msg.sender, tokenId);
        require(balance > 0, "No tokens to migrate");

        erc1155Token.safeTransferFrom(msg.sender, address(this), tokenId, balance, "");

        userTokenAmounts[msg.sender][tokenId] += balance;

        if (!isTokenMigrated[tokenId]) {
            isTokenMigrated[tokenId] = true;
            tokenOwner[tokenId] = msg.sender;
            userMigratedTokenIds[msg.sender].push(tokenId);
        }

        if (!hasUserMigrated[msg.sender]) {
            migratedUsers.push(msg.sender);
            hasUserMigrated[msg.sender] = true;
        }

        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = tokenId;
        amounts[0] = balance;

        emit TokensMigrated(msg.sender, tokenIds, amounts, block.timestamp);
    }

    function withdraw() external whenWithdrawActive {
        require(hasUserMigrated[msg.sender], "No tokens to withdraw");

        uint256[] memory tokenIds = userMigratedTokenIds[msg.sender];
        require(tokenIds.length > 0, "No tokens to withdraw");
        
        uint256[] memory amounts = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenOwner[tokenId] == msg.sender, "Not the owner of token");
            
            uint256 amount = userTokenAmounts[msg.sender][tokenId];
            require(amount > 0, "No balance for token");

            erc1155Token.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
            amounts[i] = amount;

            isTokenMigrated[tokenId] = false;
            delete tokenOwner[tokenId];
            delete userTokenAmounts[msg.sender][tokenId];
        }

        delete userMigratedTokenIds[msg.sender];

        for (uint256 i = 0; i < migratedUsers.length; i++) {
            if (migratedUsers[i] == msg.sender) {
                migratedUsers[i] = migratedUsers[migratedUsers.length - 1];
                migratedUsers.pop();
                break;
            }
        }
        hasUserMigrated[msg.sender] = false;

        emit TokensWithdrawn(msg.sender, tokenIds, amounts, block.timestamp);
    }

    function getUserMigratedTokens(address user) external view returns (uint256[] memory) {
        return userMigratedTokenIds[user];
    }

    function getTotalMigratedUsers() external view returns (uint256) {
        return migratedUsers.length;
    }

    function getMigratedUserByIndex(uint256 index) external view returns (address) {
        require(index < migratedUsers.length, "Index out of bounds");
        return migratedUsers[index];
    }

    function getMigrationStatus() external view returns (
        bool migrationPaused,
        bool withdrawPaused,
        uint256 pauseTime
    ) {
        return (isMigrationPaused, isWithdrawPaused, migrationPausedTime);
    }

    function getUserTokenAmount(address user, uint256 tokenId) external view returns (uint256) {
        return userTokenAmounts[user][tokenId];
    }
}