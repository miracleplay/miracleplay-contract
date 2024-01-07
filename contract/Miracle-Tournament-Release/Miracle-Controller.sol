// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MasterController {
    address public owner;
    address[] public erc20Whitelist;
    address[] public erc721Whitelist;
    address[] public erc1155Whitelist;

    mapping(address => bool) private erc20Listed;
    mapping(address => bool) private erc721Listed;
    mapping(address => bool) private erc1155Listed;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // Add to ERC20 Whitelist
    function addToERC20Whitelist(address _token) public onlyOwner {
        require(!erc20Listed[_token], "Token already whitelisted");
        erc20Whitelist.push(_token);
        erc20Listed[_token] = true;
    }

    // Remove from ERC20 Whitelist
    function removeFromERC20Whitelist(address _token) public onlyOwner {
        require(erc20Listed[_token], "Token not in whitelist");
        remove(erc20Whitelist, _token);
        erc20Listed[_token] = false;
    }

    // Add to ERC721 Whitelist
    function addToERC721Whitelist(address _token) public onlyOwner {
        require(!erc721Listed[_token], "Token already whitelisted");
        erc721Whitelist.push(_token);
        erc721Listed[_token] = true;
    }

    // Remove from ERC721 Whitelist
    function removeFromERC721Whitelist(address _token) public onlyOwner {
        require(erc721Listed[_token], "Token not in whitelist");
        remove(erc721Whitelist, _token);
        erc721Listed[_token] = false;
    }

    // Add to ERC1155 Whitelist
    function addToERC1155Whitelist(address _token) public onlyOwner {
        require(!erc1155Listed[_token], "Token already whitelisted");
        erc1155Whitelist.push(_token);
        erc1155Listed[_token] = true;
    }

    // Remove from ERC1155 Whitelist
    function removeFromERC1155Whitelist(address _token) public onlyOwner {
        require(erc1155Listed[_token], "Token not in whitelist");
        remove(erc1155Whitelist, _token);
        erc1155Listed[_token] = false;
    }

    // Internal function to remove an address from an array
    function remove(address[] storage array, address _token) internal {
        uint length = array.length;
        for (uint i = 0; i < length; i++) {
            if (array[i] == _token) {
                array[i] = array[length - 1];
                array.pop();
                break;
            }
        }
    }
}
