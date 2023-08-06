// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

interface IERC1155{
    function mintTo(address _to, uint256 _tokenId, string calldata _uri, uint256 _amount) external;
}

contract MintTest{
IERC1155 public NexusPointEdition;

    constructor(IERC1155 _NexusPointEdition) {
        NexusPointEdition = _NexusPointEdition;
    }


    function DoMint() public {
        IERC1155(NexusPointEdition).mintTo(msg.sender, 0, "ipfs://QmU8VWBXDuPBChtzLsoftSupp4VqBrGP7JC5PKtDfp85pJ/0", 1);
    }
}