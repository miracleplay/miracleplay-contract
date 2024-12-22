// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TDiscordToken is ERC20, Ownable {
    uint8 private constant _decimals = 18;
    uint256 private constant _totalSupply = 1_000_000_000 * 10**18; // 1,000,000,000 tokens

    constructor() ERC20("tDummy Token", "tDMY") Ownable(msg.sender) {
        _mint(msg.sender, _totalSupply);
    }

    function decimals() public pure override returns (uint8) {
        return _decimals;
    }
}