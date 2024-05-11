// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MiraclePenaltyPass V1.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

// PenaltyPass Info 
// 1 = PenaltyPass
contract MiraclePenaltyPassControl is PermissionsEnumerable, Multicall{
    struct Pass {
        bool hasPenaltyPass;
        uint256 PenaltyPassExpiryDate;
    }

    address public admin;
    mapping(address => bool) public supportedTokens; // 지원하는 토큰 목록
    mapping(address => mapping(uint256 => uint256)) public passPrices; // 토큰 주소 -> (패스 타입 -> 가격)
    mapping(address => Pass) public passInfo;
    uint256 public constant DURATION = 30 days;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }


    function setPassPrice(uint256 passType, address tokenAddress, uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE){
        supportedTokens[tokenAddress] = true;
        passPrices[tokenAddress][passType] = price;
    }

    function withdrawToken(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE){
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(token.transfer(msg.sender, balance), "Transfer failed");
    } 

    // Penalty Pass
    function getPenaltyPassPrice(address tokenAddress) public view returns (uint256) {
        require(supportedTokens[tokenAddress], "Token not supported");
        return passPrices[tokenAddress][1];
    }

    function buyPenaltyPass(address _tokenAddress) public {
        require(!hasValidPenaltyPass(msg.sender), "Already owns a valid Penalty Pass");
        require(supportedTokens[_tokenAddress], "Token not supported");
        uint256 price = passPrices[_tokenAddress][1];

        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), price), "Token Transfer failed");

        _issuePenaltyPass(msg.sender);
    }

    function _issuePenaltyPass(address user) internal {
        passInfo[user].hasPenaltyPass = true;
        passInfo[user].PenaltyPassExpiryDate = block.timestamp + DURATION;
    }

    function hasValidPenaltyPass(address user) public view returns (bool) {
        return passInfo[user].hasPenaltyPass && block.timestamp <= passInfo[user].PenaltyPassExpiryDate;
    }

    function getRemainingPenaltyPass(address user) public view returns (uint256) {
        if (passInfo[user].hasPenaltyPass && passInfo[user].PenaltyPassExpiryDate > block.timestamp) {
            return passInfo[user].PenaltyPassExpiryDate - block.timestamp;
        } else {
            return 0;
        }
    }

    function revokePenaltyPass(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        passInfo[user].hasPenaltyPass = false;
    }
}