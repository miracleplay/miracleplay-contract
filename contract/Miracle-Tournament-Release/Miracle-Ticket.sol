// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TournamentTicketNFT is ERC721Enumerable, Ownable {
    struct TicketDetails {
        uint256 tier;
        uint256 issuedAt;
        uint256 gameId;
    }

    uint256 public nextTokenId;
    mapping(uint256 => TicketDetails) public ticketDetails;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public ticketPrices;

    address public token1;
    address public token2;

    constructor(address _token1, address _token2) ERC721("TournamentTicket", "TTK") {
        token1 = _token1;
        token2 = _token2;
    }

    function setTicketPrices(uint256 gameId, uint256 tier, uint256 priceToken1, uint256 priceToken2) public onlyOwner {
        ticketPrices[gameId][tier][token1] = priceToken1;
        ticketPrices[gameId][tier][token2] = priceToken2;
    }

    function buyTicket(address to, uint256 tier, uint256 gameId) public {
        uint256 priceToken1 = ticketPrices[gameId][tier][token1];
        uint256 priceToken2 = ticketPrices[gameId][tier][token2];

        require(priceToken1 > 0 && priceToken2 > 0, "Ticket price not set");

        IERC20(token1).transferFrom(msg.sender, address(this), priceToken1);
        IERC20(token2).transferFrom(msg.sender, address(this), priceToken2);

        uint256 tokenId = nextTokenId++;
        _mint(to, tokenId);
        ticketDetails[tokenId] = TicketDetails(tier, block.timestamp, gameId);
    }

    function getTicketPrice(uint256 gameId, uint256 tier) public view returns (uint256, uint256) {
        return (ticketPrices[gameId][tier][token1], ticketPrices[gameId][tier][token2]);
    }

    function getOwnedTickets(address owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        for (uint256 i = 0; i < ownerTokenCount; i++) {
            ownedTokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ownedTokenIds;
    }

    function getValidOwnedTicketsByGame(address owner, uint256 gameId) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(owner);
        uint256[] memory tempOwnedTokenIds = new uint256[](ownerTokenCount);
        uint256 validTicketCount = 0;
        for (uint256 i = 0; i < ownerTokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            if (ticketDetails[tokenId].gameId == gameId && isTicketValid(tokenId)) {
                tempOwnedTokenIds[validTicketCount] = tokenId;
                validTicketCount++;
            }
        }
        uint256[] memory validOwnedTokenIds = new uint256[](validTicketCount);
        for (uint256 i = 0; i < validTicketCount; i++) {
            validOwnedTokenIds[i] = tempOwnedTokenIds[i];
        }
        return validOwnedTokenIds;
    }

    function isTicketValid(uint256 tokenId) public view returns (bool) {
        TicketDetails memory details = ticketDetails[tokenId];
        return block.timestamp <= details.issuedAt + 30 days;
    }
}