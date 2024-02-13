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
    mapping(bytes32 => uint256) public ticketPrices; // 게임ID, 티켓 등급, 토큰 주소 => 가격

    constructor() ERC721("TournamentTicket", "TTK") {}

    function setTicketPrice(uint256 gameId, uint256 tier, address tokenAddress, uint256 price) public onlyOwner {
        bytes32 key = keccak256(abi.encodePacked(gameId, tier, tokenAddress));
        ticketPrices[key] = price;
    }

    function buyTicket(address to, uint256 tier, uint256 gameId, address tokenAddress) public {
        bytes32 priceKey = keccak256(abi.encodePacked(gameId, tier, tokenAddress));
        uint256 ticketPrice = ticketPrices[priceKey];
        
        require(ticketPrice > 0, "Ticket price not set");

        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), ticketPrice), "Payment failed");

        uint256 tokenId = nextTokenId++;
        _mint(to, tokenId);
        ticketDetails[tokenId] = TicketDetails(tier, block.timestamp, gameId);
    }

    function getValidOwnedTicketsByGame(address owner, uint256 gameId) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(owner);
        uint256[] memory tempOwnedTokenIds = new uint256[](ownerTokenCount);
        uint256 validTicketCount = 0;

        for (uint256 i = 0; i < ownerTokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            TicketDetails memory details = ticketDetails[tokenId];
            if (details.gameId == gameId && isTicketValid(tokenId)) {
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

    function getOwnedTickets(address owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);

        for (uint256 i = 0; i < ownerTokenCount; i++) {
            ownedTokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }

        return ownedTokenIds;
    }

    function isTicketValid(uint256 tokenId) public view returns (bool) {
        TicketDetails memory details = ticketDetails[tokenId];
        return block.timestamp <= details.issuedAt + 30 days;
    }
}
