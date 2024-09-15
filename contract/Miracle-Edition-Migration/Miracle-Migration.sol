// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MiracleEditionMigration is PermissionsEnumerable, Multicall, ContractMetadata {
    IERC1155 public erc1155Token; // ERC-1155 token contract address
    address public deployer;

    // Event emitted when migration occurs
    event Migration(address indexed user, uint256 indexed tokenId, uint256 amount);

    // Mapping to track the total amount of tokens burned for each token ID
    mapping(uint256 => uint256) public totalBurnedPerToken;

    // Constructor to set the ERC-1155 contract address
    constructor(address _erc1155TokenAddress, string memory _contractURI, address _deployer) {
        erc1155Token = IERC1155(_erc1155TokenAddress);
        deployer = _deployer;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    // Function to migrate the user's ERC-1155 tokens by transferring to address(0) using safeTransferFrom
    function migrate(uint256 tokenId) external {
        uint256 userBalance = erc1155Token.balanceOf(msg.sender, tokenId);
        
        // If the user does not own any of the specified token, revert the transaction
        require(userBalance > 0, "You do not own any of this token");

        // Check if the user has approved the contract to transfer their tokens
        require(erc1155Token.isApprovedForAll(msg.sender, address(this)), "Contract not approved to transfer tokens");

        // Transfer the user's ERC-1155 tokens to address(0) to "burn" them using safeTransferFrom
        erc1155Token.safeTransferFrom(msg.sender, address(0), tokenId, userBalance, "");

        // Record the number of tokens burned (transferred to address(0))
        totalBurnedPerToken[tokenId] += userBalance;

        // Emit the migration event
        emit Migration(msg.sender, tokenId, userBalance);
    }

    // Function to view the total number of tokens burned for a specific token ID
    function getTotalBurned(uint256 tokenId) external view returns (uint256) {
        return totalBurnedPerToken[tokenId];
    }
}
