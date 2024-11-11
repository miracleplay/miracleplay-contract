// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   Miracle Token Shop V1.0.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IMintableToken {
    function mintTo(address to, uint256 amount) external;
}

contract MiracleStoreEscrow is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;

    struct Item {
        uint256 price;
        address tokenAddress;
        address mintTokenAddress;
        uint256 mintAmount;
        string name;
        bool exists;
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

        IERC20 paymentToken = IERC20(tokenAddress);
        require(paymentToken.transferFrom(msg.sender, address(this), item.price), "Token transfer failed");

        // 민팅 로직 추가
        IMintableToken mintToken = IMintableToken(item.mintTokenAddress);
        mintToken.mintTo(msg.sender, item.mintAmount);

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

    function getItem(uint256 itemId, address tokenAddress) external view returns (uint256 price, string memory name, bool exists, address mintTokenAddress, uint256 mintAmount) {
        Item memory item = items[itemId][tokenAddress];
        return (item.price, item.name, item.exists, item.mintTokenAddress, item.mintAmount);
    }
}
