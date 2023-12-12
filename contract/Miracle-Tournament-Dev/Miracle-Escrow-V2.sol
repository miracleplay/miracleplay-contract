// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

// import "./Miracle-Tournament.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentEscrow V2.0              
//   Deploy by Server

contract MiracleTournamentEscrow is ContractMetadata, ERC1155Holder, ERC721Holder {
    uint256 tournamentID;
    address public deployer;
    address public organizer;
    // Royalty setting
    // Developer royalty
    uint public RoyaltyPrizeDev; 
    uint public RoyaltyregfeeDev;
    address public royaltyAddrDev;
    // Flatform royalty
    uint public RoyaltyPrizeFlp;
    uint public RoyaltyregfeeFlp;
    address public royaltyAddrFlp;
    // Battle point
    IERC20 public BattlePointToken;

    struct Tournament {
        address organizer;
        TournamentStatus tournamentStatus;
        TournamentJoinfee joinFee;
        TournamentJoinInfo tournamentJoinInfo;
        string tournamentURI;
    }

    struct TournamentJoinfee {
        address feeTokenAddress;
        uint feeAmount;
        uint feeBalance;
    }

    struct TournamentStatus {
        bool tournamentCreated;
        bool tournamentEnded;
        bool tournamentCanceled;
    }

    struct TournamentJoinInfo {
        uint joinStartTime;
        uint joinEndTime;
        uint playersLimit;
    }

    struct TournamentEscrow {
        uint prizeCount;
        mapping(uint => TournamentPrizeAssets) ranksPrize;
        createTotalAssets createAssets;
    }

    struct TournamentPrizeAssets {
        PrizeAssetsERC20 Token;
        PrizeAssetsERC721 NFT;
        PrizeAssetsERC1155 Edition;
    }

    struct PrizeAssetsERC20{
        address tokenAddress;
        uint amount;
    }

    struct PrizeAssetsERC721{
        address NFTAddress;
        uint NFTId;
    }

    struct PrizeAssetsERC1155{
        address EditionAddress;
        uint EditionId;
        uint EditionAmount;
    }



}