// SPDX-License-Identifier: MIT
// MultiEditionMigration 1.0.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MiracleEditionMigration is PermissionsEnumerable, Multicall, ContractMetadata, ERC1155Holder {
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

    // 사용자별 토큰 수량을 기록하기 위한 구조체 추가
    struct TokenAmount {
        uint256 tokenId;
        uint256 amount;
    }

    // 사용자별 토큰 수량 매핑 추가
    mapping(address => TokenAmount[]) public userMigratedTokenAmounts;

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

    function migrate() external whenMigrationActive {
        require(address(erc1155Token) != address(0), "ERC-1155 token address not set");
        require(!hasUserMigrated[msg.sender], "Must withdraw existing tokens before new migration");
        require(erc1155Token.isApprovedForAll(msg.sender, address(this)), "Contract not approved to transfer tokens");

        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        // Check balances and prepare arrays
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < 3; i++) {  // 0~2까지 체크
            uint256 balance = erc1155Token.balanceOf(msg.sender, i);
            if (balance > 0) {
                tokenIds[i] = i;
                amounts[i] = balance;
                totalBalance += balance;

                // 토큰 수량 기록
                userMigratedTokenAmounts[msg.sender].push(TokenAmount({
                    tokenId: i,
                    amount: balance
                }));
            }
        }

        // Revert if user has no tokens
        require(totalBalance > 0, "No tokens to migrate");

        // Process migration for tokens with non-zero balance
        for (uint256 i = 0; i < 3; i++) {
            if (amounts[i] > 0) {
                require(!isTokenMigrated[i], "Token already migrated");

                erc1155Token.safeTransferFrom(msg.sender, address(this), i, amounts[i], "");

                isTokenMigrated[i] = true;
                tokenOwner[i] = msg.sender;
                userMigratedTokenIds[msg.sender].push(i);
            }
        }

        migratedUsers.push(msg.sender);
        hasUserMigrated[msg.sender] = true;

        emit TokensMigrated(msg.sender, tokenIds, amounts, block.timestamp);
    }

    function withdraw() external whenWithdrawActive {
        require(hasUserMigrated[msg.sender], "No tokens to withdraw");

        TokenAmount[] memory tokenAmounts = userMigratedTokenAmounts[msg.sender];
        require(tokenAmounts.length > 0, "No tokens to withdraw");

        uint256[] memory tokenIds = new uint256[](tokenAmounts.length);
        uint256[] memory amounts = new uint256[](tokenAmounts.length);

        for (uint256 i = 0; i < tokenAmounts.length; i++) {
            TokenAmount memory tokenAmount = tokenAmounts[i];
            tokenIds[i] = tokenAmount.tokenId;
            amounts[i] = tokenAmount.amount;

            require(tokenOwner[tokenAmount.tokenId] == msg.sender, "Not the owner of token");

            erc1155Token.safeTransferFrom(
                address(this), 
                msg.sender, 
                tokenAmount.tokenId, 
                tokenAmount.amount, 
                ""
            );

            isTokenMigrated[tokenAmount.tokenId] = false;
            delete tokenOwner[tokenAmount.tokenId];
        }

        delete userMigratedTokenAmounts[msg.sender];
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
}