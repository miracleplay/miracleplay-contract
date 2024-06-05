// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    string private _imageUrl;
    string private _description;

    constructor(
        string memory name,
        string memory symbol,
        string memory imageUrl,
        string memory description,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _imageUrl = imageUrl;
        _description = description;
        _mint(msg.sender, initialSupply * (10 ** decimals()));
    }

    function imageUrl() public view returns (string memory) {
        return _imageUrl;
    }

    function description() public view returns (string memory) {
        return _description;
    }

    function setImageUrl(string memory newImageUrl) public onlyOwner {
        _imageUrl = newImageUrl;
    }

    function setDescription(string memory newDescription) public onlyOwner {
        _description = newDescription;
    }
}
