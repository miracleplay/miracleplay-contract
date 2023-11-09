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

contract TokenSwap {
    address public owner;
    IERC20 public tokenA;
    IERC20 public tokenB;

    constructor(address _tokenA, address _tokenB) {
        owner = msg.sender;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // 소유자가 B 토큰을 예치하는 함수
    function depositTokenB(uint256 amount) public onlyOwner {
        require(tokenB.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }

    // 사용자가 A 토큰을 보내면 B 토큰을 반환하는 함수
    function swapTokenAForTokenB(uint256 amount) public {
        require(tokenA.transferFrom(msg.sender, address(this), amount), "Transfer of token A failed");
        require(tokenB.transfer(msg.sender, amount), "Transfer of token B failed");
    }

    // 소유자가 A 토큰을 인출하는 함수
    function withdrawTokenA(uint256 amount) public onlyOwner {
        require(tokenA.transfer(owner, amount), "Withdrawal of token A failed");
    }

    // 소유자가 B 토큰을 인출하는 함수
    function withdrawTokenB(uint256 amount) public onlyOwner {
        require(tokenB.transfer(owner, amount), "Withdrawal of token B failed");
    }
}
