// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MiracleStoreEscrow is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address public platformAddress;

    struct Item {
        uint256 price;
        address tokenAddress;
        string name;
        bool exists;
        address developerAddress;
        // Fees are calculated as a percentage, based on 10000 (e.g. 3% is 300). This allows accurate fee calculations without decimal calculations.
        uint256 platformFeePercent;
        uint256 developerFeePercent;
    }

    constructor(string memory _contractURI, address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(FACTORY_ROLE, admin);
        _setupRole(FACTORY_ROLE, 0x9DD6D483bd17ce22b4d1B16c4fdBc0d106d3669d);
        deployer = admin;
        _setupContractURI(_contractURI);
    }

    mapping(uint256 => mapping(address => Item)) public items;
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    event ItemSet(uint256 indexed itemId, address indexed tokenAddress, uint256 price, string name);
    event ItemPurchased(uint256 indexed itemId, address indexed buyer, address indexed tokenAddress, uint256 price);
    event ItemRemoved(uint256 indexed itemId, address indexed tokenAddress);
    event TokensWithdrawn(address indexed tokenAddress, uint256 amount, address indexed to);

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function setItem(
        uint256 itemId, 
        address tokenAddress, 
        uint256 price, 
        string memory name,
        address developerAddress,
        uint256 platformFeePercent,
        uint256 developerFeePercent
    ) external onlyRole(FACTORY_ROLE) {
        require(price > 0, "Price must be greater than zero");
        require(platformFeePercent + developerFeePercent <= 10000, "Total fee percentage cannot exceed 100%");
        items[itemId][tokenAddress] = Item(
            price, 
            tokenAddress, 
            name, 
            true,
            developerAddress,
            platformFeePercent,
            developerFeePercent
        );
        emit ItemSet(itemId, tokenAddress, price, name);
    }

    function removeItem(uint256 itemId, address tokenAddress) external onlyRole(FACTORY_ROLE) {
        require(items[itemId][tokenAddress].exists, "Item does not exist");
        delete items[itemId][tokenAddress];
        emit ItemRemoved(itemId, tokenAddress);
    }

    function setPlatformAddress(address _platformAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        platformAddress = _platformAddress;
    }

    function purchaseItem(uint256 itemId, address tokenAddress) external payable {
        Item memory item = items[itemId][tokenAddress];
        require(item.exists, "Item does not exist");

        uint256 platformFee = (item.price * item.platformFeePercent) / 10000;
        uint256 developerFee = (item.price * item.developerFeePercent) / 10000;

        if (tokenAddress == address(0)) {
            require(msg.value == item.price, "Incorrect Native Coin amount");
            
            (bool platformSuccess, ) = platformAddress.call{value: platformFee}("");
            require(platformSuccess, "Platform fee transfer failed");
            
            (bool developerSuccess, ) = item.developerAddress.call{value: developerFee}("");
            require(developerSuccess, "Developer fee transfer failed");
        } else {
            IERC20 token = IERC20(tokenAddress);
            require(token.transferFrom(msg.sender, address(this), item.price), "Token transfer failed");
            
            require(token.transfer(platformAddress, platformFee), "Platform fee transfer failed");
            
            require(token.transfer(item.developerAddress, developerFee), "Developer fee transfer failed");
        }

        emit ItemPurchased(itemId, msg.sender, tokenAddress, item.price);
    }

    function updateItemPrice(uint256 itemId, address tokenAddress, uint256 newPrice) external onlyRole(FACTORY_ROLE) {
        require(items[itemId][tokenAddress].exists, "Item does not exist");
        require(newPrice > 0, "Price must be greater than zero");
        items[itemId][tokenAddress].price = newPrice;
        emit ItemSet(itemId, tokenAddress, newPrice, items[itemId][tokenAddress].name);
    }

    function withdrawTokens(address tokenAddress, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenAddress == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Native Coin transfer failed");
        } else {
            IERC20 token = IERC20(tokenAddress);
            require(token.balanceOf(address(this)) >= amount, "Insufficient balance in contract");
            require(token.transfer(msg.sender, amount), "Token transfer failed");
        }
        emit TokensWithdrawn(tokenAddress, amount, msg.sender);
    }

    function getItem(uint256 itemId, address tokenAddress) external view returns (
        uint256 price, 
        string memory name, 
        bool exists,
        address developerAddress,
        uint256 platformFeePercent,
        uint256 developerFeePercent
    ) {
        Item memory item = items[itemId][tokenAddress];
        return (
            item.price, 
            item.name, 
            item.exists,
            item.developerAddress,
            item.platformFeePercent,
            item.developerFeePercent
        );
    }
}