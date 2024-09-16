// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract MiracleNodeSales is PermissionsEnumerable, Multicall, ContractMetadata  {
    address public deployer;
    IERC20 public token;
    uint256 public nodePrice;
    uint256 public totalNodesAvailable;
    uint256 public totalNodesSold;

    event NodePurchased(address indexed buyer, uint256 indexed nodeCount, address tokenUsed, uint256 tokenAmount);
    event NodePriceUpdated(uint256 newPrice);
    event TokenUpdated(address newToken);
    event TotalNodesUpdated(uint256 newTotalNodes);
    event TokenAndPriceUpdated(address newToken, uint256 newPrice);
    event TotalNodesSoldReset();

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    constructor(string memory _contractURI, address _deployer) {
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        deployer = _deployer;
        _setupContractURI(_contractURI);
        totalNodesAvailable = 0;
        totalNodesSold = 0;
    }

    // Function to purchase nodes
    function purchaseNode(uint256 nodeCount) external {
        uint256 cost = nodePrice * nodeCount;
        require(token.allowance(msg.sender, address(this)) >= cost, "Token allowance too low");
        require(totalNodesSold + nodeCount <= totalNodesAvailable, "Not enough nodes available for purchase");

        token.transferFrom(msg.sender, address(this), cost);
        totalNodesSold += nodeCount;

        emit NodePurchased(msg.sender, nodeCount, address(token), cost);
    }

    // Function to get the current node price
    function getNodePrice() external view returns (uint256) {
        return nodePrice;
    }

    // Function to get the available number of nodes for purchase
    function getAvailableNodes() external view returns (uint256) {
        return totalNodesAvailable - totalNodesSold;
    }

    // Function to get the total number of sold nodes
    function getTotalNodesSold() external view returns (uint256) {
        return totalNodesSold;
    }

    // Function to get the current token used for node purchases
    function getToken() external view returns (address) {
        return address(token);
    }

    // Admin function to update the token used for node purchases
    function setToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token = IERC20(_token);
        emit TokenUpdated(_token);
    }

    // Admin function to update the node price
    function setNodePrice(uint256 _nodePrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nodePrice = _nodePrice;
        emit NodePriceUpdated(_nodePrice);
    }

    // Admin function to update the total number of nodes available for sale
    function setTotalNodesAvailable(uint256 _totalNodesAvailable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        totalNodesAvailable = _totalNodesAvailable;
        emit TotalNodesUpdated(_totalNodesAvailable);
    }

    // Admin function to update both the token and the price for node purchases
    function setTokenAndPrice(address _token, uint256 _nodePrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token = IERC20(_token);
        nodePrice = _nodePrice;
        emit TokenAndPriceUpdated(_token, _nodePrice);
    }

    // Admin function to withdraw specific tokens from the contract
    function withdrawTokens(address _tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20 withdrawToken = IERC20(_tokenAddress);
        uint256 balance = withdrawToken.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        withdrawToken.transfer(msg.sender, balance);
    }

    // Admin function to reset the total number of nodes sold
    function resetTotalNodesSold() external onlyRole(DEFAULT_ADMIN_ROLE) {
        totalNodesSold = 0;
        emit TotalNodesSoldReset();
    }
}
