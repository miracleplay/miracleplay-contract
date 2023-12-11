// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract TokenToTokenSwap {
    address public owner;
    address public admin;
    IERC20 public tokenMZC;
    IERC20 public tokenMUC;

    constructor(address _tokenMZC, address _tokenMUC) {
        owner = msg.sender;
        tokenMZC = IERC20(_tokenMZC);
        tokenMUC = IERC20(_tokenMUC);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // 소유자가 B 토큰을 예치하는 함수
    function depositMUC(uint256 amount) public onlyAdmin {
        require(tokenMUC.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    // 사용자가 A 토큰을 보내면 B 토큰을 반환하는 함수
    function swapMZCForMUC(uint256 amount) public {
        require(tokenMZC.transferFrom(msg.sender, address(this), amount), "Transfer of MZC failed");
        require(tokenMUC.transfer(msg.sender, amount), "Transfer of MUC failed");
    }

    function withdrawMZC(uint256 amount) public onlyAdmin {
        require(tokenMZC.transfer(owner, amount), "Withdrawal of MZC failed");
    }

    function withdrawMUC(uint256 amount) public onlyAdmin {
        require(tokenMUC.transfer(owner, amount), "Withdrawal of MUC failed");
    }
}
