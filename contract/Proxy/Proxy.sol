//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6bd6b76d1156e20e45d1016f355d154141c7e5b9/contracts/access/Ownable.sol";

contract ProxyStorage is Ownable {
    address public implementation;
}

contract Proxy is ProxyStorage {

    constructor(address _implementation) {
        setImplementation(_implementation);
    }

    function setImplementation(address _implementation) public onlyOwner() {
        implementation = _implementation;
    }

    fallback () external {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())

            let result := delegatecall (
                gas(),
                sload(implementation.slot),
                ptr,
                calldatasize(),
                0,
                0
            )

            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 {
                revert(ptr, size)
            }
            default {
                return(ptr, size)
            }
        }       
    }
}