// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TournamentAccessControl {
    struct Pass {
        bool hasPlatinum;
        bool hasPremium;
        uint256 platinumExpiryDate;
        uint256 premiumExpiryDate;
    }

    IERC20 public mptToken;
    IERC20 public bptToken;
    uint256 public platinumPriceMPT;
    uint256 public platinumPriceBPT;
    uint256 public premiumPriceMPT;
    uint256 public premiumPriceBPT;
    mapping(address => Pass) public passInfo;
    address public admin;
    uint256 public constant DURATION = 30 days;

    constructor(address _mptToken, address _bptToken) {
        admin = msg.sender;
        mptToken = IERC20(_mptToken);
        bptToken = IERC20(_bptToken);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not an admin");
        _;
    }

    function setPlatinumPassPrices(uint256 _priceMPT, uint256 _priceBPT) public onlyAdmin {
        platinumPriceMPT = _priceMPT;
        platinumPriceBPT = _priceBPT;
    }

    function setpremiumPassPrices(uint256 _priceMPT, uint256 _priceBPT) public onlyAdmin {
        premiumPriceMPT = _priceMPT;
        premiumPriceBPT = _priceBPT;
    }

    // 플래티넘 패스 가격 조회
    function getPlatinumPassPrices() public view returns (uint256, uint256) {
        return (platinumPriceMPT, platinumPriceBPT);
    }

    // 프리미엄 패스 가격 조회
    function getPremiumPassPrices() public view returns (uint256, uint256) {
        return (premiumPriceMPT, premiumPriceBPT);
    }

    // 플래티넘 패스 구매
    function buyPlatinumPass() public {
        require(!hasValidPlatinumPass(msg.sender), "Already owns a valid Platinum pass");
        require(mptToken.transferFrom(msg.sender, address(this), platinumPriceMPT), "MPT Transfer failed");
        require(bptToken.transferFrom(msg.sender, address(this), platinumPriceBPT), "BPT Transfer failed");
        _issuePlatinumPass(msg.sender);
    }

    // 프리미엄 패스 구매
    function buyPremiumPass() public {
        require(!hasValidPremiumPass(msg.sender), "Already owns a valid Premium pass");
        require(mptToken.transferFrom(msg.sender, address(this), premiumPriceMPT), "MPT Transfer failed");
        require(bptToken.transferFrom(msg.sender, address(this), premiumPriceBPT), "BPT Transfer failed");
        _issuePremiumPass(msg.sender);
    }

    // 관리자 플래티넘 패스 발급
    function issuePlatinumPass(address user) public onlyAdmin {
        require(!hasValidPlatinumPass(user), "User already has a valid Platinum pass");
        passInfo[user].hasPlatinum = true;
        passInfo[user].platinumExpiryDate = block.timestamp + DURATION;
    }

    // 관리자 프리미엄 패스 발급
    function issuePremiumPass(address user) public onlyAdmin {
        require(!hasValidPremiumPass(user), "User already has a valid Premium pass");
        passInfo[user].hasPremium = true;
        passInfo[user].premiumExpiryDate = block.timestamp + DURATION;
    }

    // 플래티넘 판매
    function _issuePlatinumPass(address user) internal {
        passInfo[user].hasPlatinum = true;
        passInfo[user].platinumExpiryDate = block.timestamp + DURATION;
    }

    // 프리미엄 판매
    function _issuePremiumPass(address user) internal {
        passInfo[user].hasPremium = true;
        passInfo[user].premiumExpiryDate = block.timestamp + DURATION;
    }

    // 플래티넘 패스 유효성 확인
    function hasValidPlatinumPass(address user) public view returns (bool) {
        return passInfo[user].hasPlatinum && block.timestamp <= passInfo[user].platinumExpiryDate;
    }

    // 프리미엄 패스 유효성 확인
    function hasValidPremiumPass(address user) public view returns (bool) {
        return passInfo[user].hasPremium && block.timestamp <= passInfo[user].premiumExpiryDate;
    }

    // 플래티넘과 프리미엄 패스 보유 여부 동시 확인
    function checkBothPasses(address user) public view returns (bool[] memory) {
        bool[] memory passesStatus = new bool[](2);
        passesStatus[0] = hasValidPlatinumPass(user);
        passesStatus[1] = hasValidPremiumPass(user);
        return passesStatus;
    }

    // 패스 취소 (플래티넘, 프리미엄 별도로 처리)
    function revokePlatinumPass(address user) public onlyAdmin {
        passInfo[user].hasPlatinum = false;
    }

    function revokePremiumPass(address user) public onlyAdmin {
        passInfo[user].hasPremium = false;
    }
}