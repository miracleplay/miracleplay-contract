// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract EditionMigration is PermissionsEnumerable, Multicall, ContractMetadata, ERC1155Holder {
    IERC1155 public erc1155Token; // ERC-1155 token contract address
    address public deployer;

    // Mapping to track the total amount of tokens migrated per user per token ID
    mapping(address => mapping(uint256 => uint256)) public migratedTokens;

    // Event emitted when migration occurs
    event Migration(address indexed user, uint256 indexed tokenId, uint256 amount);

    // Constructor to set the ERC-1155 contract address
    constructor(address _erc1155TokenAddress, string memory _contractURI, address _deployer) {
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        erc1155Token = IERC1155(_erc1155TokenAddress);
        deployer = _deployer;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    // Function to migrate the user's ERC-1155 tokens to the contract
    function migrate(uint256 tokenId) external {
        uint256 userBalance = erc1155Token.balanceOf(msg.sender, tokenId);
        
        // If the user does not own any of the specified token, revert the transaction
        require(userBalance > 0, "You do not own any of this token");

        // Check if the user has approved the contract to transfer their tokens
        require(erc1155Token.isApprovedForAll(msg.sender, address(this)), "Contract not approved to transfer tokens");

        // Transfer the user's ERC-1155 tokens to the contract
        erc1155Token.safeTransferFrom(msg.sender, address(this), tokenId, userBalance, "");

        // Record the number of tokens migrated by the user
        migratedTokens[msg.sender][tokenId] += userBalance;

        // Emit the migration event
        emit Migration(msg.sender, tokenId, userBalance);
    }

    // Function to get the number of tokens migrated by a specific user for a given token ID
    function getMigratedTokens(address user, uint256 tokenId) external view returns (uint256) {
        return migratedTokens[user][tokenId];
    }
}
