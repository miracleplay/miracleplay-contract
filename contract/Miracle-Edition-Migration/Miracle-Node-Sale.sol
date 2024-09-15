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
}

contract MiracleNodeSales is PermissionsEnumerable, Multicall, ContractMetadata  {
    address public deployer;
    address public admin;
    IERC20 public token;
    uint256 public nodePrice;
    uint256 public totalNodesAvailable;
    uint256 public totalNodesSold;

    event NodePurchased(address indexed buyer, uint256 indexed nodeCount, uint256 price);
    event NodePriceUpdated(uint256 newPrice);
    event TokenUpdated(address newToken);
    event TotalNodesUpdated(uint256 newTotalNodes);
    event TokenAndPriceUpdated(address newToken, uint256 newPrice);

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    constructor(string memory _contractURI, address _deployer) {
        admin = _deployer;
        deployer = _deployer;
        _setupContractURI(_contractURI);
        totalNodesAvailable = 0;
        totalNodesSold = 0;
    }

    // 노드 구매 기능
    function purchaseNode(uint256 nodeCount) external {
        uint256 cost = nodePrice * nodeCount;
        require(token.allowance(msg.sender, address(this)) >= cost, "Token allowance too low");
        require(totalNodesSold + nodeCount <= totalNodesAvailable, "Not enough nodes available for purchase");

        token.transferFrom(msg.sender, address(this), cost);
        totalNodesSold += nodeCount;

        emit NodePurchased(msg.sender, nodeCount, cost);
    }

    // 현재 노드 가격 조회
    function getNodePrice() external view returns (uint256) {
        return nodePrice;
    }

    // 구매 가능한 노드 수량 조회
    function getAvailableNodes() external view returns (uint256) {
        return totalNodesAvailable - totalNodesSold;
    }

    // 총 판매된 노드 수량 조회
    function getTotalNodesSold() external view returns (uint256) {
        return totalNodesSold;
    }

    // 관리자 기능: 토큰 변경
    function setToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token = IERC20(_token);
        emit TokenUpdated(_token);
    }

    // 관리자 기능: 노드 가격 설정
    function setNodePrice(uint256 _nodePrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nodePrice = _nodePrice;
        emit NodePriceUpdated(_nodePrice);
    }

    // 관리자 기능: 총 판매 가능 노드 수량 설정
    function setTotalNodesAvailable(uint256 _totalNodesAvailable) external onlyRole(DEFAULT_ADMIN_ROLE) {
        totalNodesAvailable = _totalNodesAvailable;
        emit TotalNodesUpdated(_totalNodesAvailable);
    }

    // 관리자 기능: 토큰 및 가격 변경
    function setTokenAndPrice(address _token, uint256 _nodePrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token = IERC20(_token);
        nodePrice = _nodePrice;
        emit TokenAndPriceUpdated(_token, _nodePrice);
    }
}
