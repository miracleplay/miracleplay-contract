//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   Miracle Token Shop V1.1.0
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IMintableToken {
    function mintTo(address to, uint256 amount) external;
}

contract MiracleTokenShop is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    uint256 public COOLDOWN_PERIOD = 7 days; // Cooldown period of 7 days

    struct Item {
        uint256 price;
        address tokenAddress;
        address mintTokenAddress;
        uint256 mintAmount;
        string name;
        bool exists;
    }

    mapping(uint256 => mapping(address => Item)) public items;
    mapping(address => mapping(uint256 => uint256)) public lastPurchaseTime; // Mapping to store last purchase time

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    event ItemSet(uint256 indexed itemId, address indexed tokenAddress, uint256 price, string name);
    event ItemPurchased(uint256 indexed itemId, address indexed buyer, address indexed tokenAddress, uint256 price);
    event ItemRemoved(uint256 indexed itemId, address indexed tokenAddress);
    event TokensWithdrawn(address indexed tokenAddress, uint256 amount, address indexed to);

    constructor(string memory _contractURI, address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(FACTORY_ROLE, admin);
        _setupRole(FACTORY_ROLE, 0x9DD6D483bd17ce22b4d1B16c4fdBc0d106d3669d);
        deployer = admin;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function setItem(
        uint256 itemId,
        address tokenAddress,
        uint256 price,
        address mintTokenAddress,
        uint256 mintAmount,
        string memory name
    ) external onlyRole(FACTORY_ROLE) {
        require(price > 0, "Price must be greater than zero");
        require(tokenAddress != address(0), "Invalid token address");
        require(mintTokenAddress != address(0), "Invalid mint token address");

        items[itemId][tokenAddress] = Item(price, tokenAddress, mintTokenAddress, mintAmount, name, true);
        emit ItemSet(itemId, tokenAddress, price, name);
    }

    function removeItem(uint256 itemId, address tokenAddress) external onlyRole(FACTORY_ROLE) {
        require(items[itemId][tokenAddress].exists, "Item does not exist");
        delete items[itemId][tokenAddress];
        emit ItemRemoved(itemId, tokenAddress);
    }

    function purchaseItem(uint256 itemId, address tokenAddress) external {
        Item memory item = items[itemId][tokenAddress];
        require(item.exists, "Item does not exist");

        // Check cooldown period
        require(block.timestamp >= lastPurchaseTime[msg.sender][itemId] + COOLDOWN_PERIOD, "Cooldown period has not passed");

        IERC20 paymentToken = IERC20(tokenAddress);
        require(paymentToken.transferFrom(msg.sender, address(this), item.price), "Token transfer failed");

        IMintableToken mintToken = IMintableToken(item.mintTokenAddress);
        mintToken.mintTo(msg.sender, item.mintAmount);

        // Update last purchase time
        lastPurchaseTime[msg.sender][itemId] = block.timestamp;

        emit ItemPurchased(itemId, msg.sender, tokenAddress, item.price);
    }

    function updateItemPrice(uint256 itemId, address tokenAddress, uint256 newPrice) external onlyRole(FACTORY_ROLE) {
        require(items[itemId][tokenAddress].exists, "Item does not exist");
        require(newPrice > 0, "Price must be greater than zero");
        items[itemId][tokenAddress].price = newPrice;
        emit ItemSet(itemId, tokenAddress, newPrice, items[itemId][tokenAddress].name);
    }

    function withdrawTokens(address tokenAddress, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance in contract");
        require(token.transfer(msg.sender, amount), "Token transfer failed");
        emit TokensWithdrawn(tokenAddress, amount, msg.sender);
    }

    function updateCooldownPeriod(uint256 newCooldownPeriod) external onlyRole(FACTORY_ROLE) {
        require(newCooldownPeriod > 0, "Cooldown period must be greater than zero");
        COOLDOWN_PERIOD = newCooldownPeriod;
    }

    function getItem(uint256 itemId, address tokenAddress) external view returns (uint256 price, string memory name, bool exists, address mintTokenAddress, uint256 mintAmount) {
        Item memory item = items[itemId][tokenAddress];
        return (item.price, item.name, item.exists, item.mintTokenAddress, item.mintAmount);
    }

    // Function to get the last purchase time of an item by a user
    function getLastPurchaseTime(address user, uint256 itemId) external view returns (uint256) {
        return lastPurchaseTime[user][itemId];
    }

    // Function to get the remaining cooldown time (in seconds) before a user can purchase the same item again
    function getRemainingCooldownTime(address user, uint256 itemId) external view returns (uint256) {
        uint256 lastTime = lastPurchaseTime[user][itemId];
        if (block.timestamp >= lastTime + COOLDOWN_PERIOD) {
            return 0;
        } else {
            return (lastTime + COOLDOWN_PERIOD) - block.timestamp;
        }
    }
}