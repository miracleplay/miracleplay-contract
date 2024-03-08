// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MiraclePass V1.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

// Pass Info 
// 1 = Premium / 2 = Platinum
contract MiraclePassControl is PermissionsEnumerable, Multicall{
    struct Pass {
        bool hasPlatinum;
        bool hasPremium;
        uint256 platinumExpiryDate;
        uint256 premiumExpiryDate;
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

    // Platinum Pass
    function getPlatinumPassPrice(address tokenAddress) public view returns (uint256) {
        require(supportedTokens[tokenAddress], "Token not supported");
        return passPrices[tokenAddress][2];
    }

    function buyPlatinumPass(address _tokenAddress) public {
        require(!hasValidPlatinumPass(msg.sender), "Already owns a valid Platinum pass");
        require(supportedTokens[_tokenAddress], "Token not supported");
        uint256 price = passPrices[_tokenAddress][2];

        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), price), "Token Transfer failed");

        _issuePlatinumPass(msg.sender);
    }

    function _issuePlatinumPass(address user) internal {
        passInfo[user].hasPlatinum = true;
        passInfo[user].platinumExpiryDate = block.timestamp + DURATION;
    }

    function hasValidPlatinumPass(address user) public view returns (bool) {
        return passInfo[user].hasPlatinum && block.timestamp <= passInfo[user].platinumExpiryDate;
    }

    function getRemainingPlatinumPass(address user) public view returns (uint256) {
        if (passInfo[user].hasPlatinum && passInfo[user].platinumExpiryDate > block.timestamp) {
            return passInfo[user].platinumExpiryDate - block.timestamp;
        } else {
            return 0;
        }
    }

    // Premium Pass
    function getPremiumPassPrice(address tokenAddress) public view returns (uint256) {
        require(supportedTokens[tokenAddress], "Token not supported");
        return passPrices[tokenAddress][1];
    }

    function buyPremiumPass(address _tokenAddress) public {
        require(!hasValidPremiumPass(msg.sender), "Already owns a valid dPremium pass");
        require(supportedTokens[_tokenAddress], "Token not supported");
        uint256 price = passPrices[_tokenAddress][1];

        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), price), "Token Transfer failed");

        _issuePremiumPass(msg.sender);
    }

    function _issuePremiumPass(address user) internal {
        passInfo[user].hasPremium = true;
        passInfo[user].premiumExpiryDate = block.timestamp + DURATION;
    }

    function hasValidPremiumPass(address user) public view returns (bool) {
        return passInfo[user].hasPremium && block.timestamp <= passInfo[user].premiumExpiryDate;
    }

    function getRemainingPremiumPass(address user) public view returns (uint256) {
        if (passInfo[user].hasPremium && passInfo[user].premiumExpiryDate > block.timestamp) {
            return passInfo[user].premiumExpiryDate - block.timestamp;
        } else {
            return 0;
        }
    }

    function checkBothPasses(address user) public view returns (bool[] memory) {
        bool[] memory passesStatus = new bool[](2);
        passesStatus[0] = hasValidPlatinumPass(user);
        passesStatus[1] = hasValidPremiumPass(user);
        return passesStatus;
    }

    function revokePlatinumPass(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        passInfo[user].hasPlatinum = false;
    }

    function revokePremiumPass(address user) public onlyRole(DEFAULT_ADMIN_ROLE) {
        passInfo[user].hasPremium = false;
    }
}