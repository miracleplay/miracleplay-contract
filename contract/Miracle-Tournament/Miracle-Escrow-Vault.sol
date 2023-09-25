// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "./Miracle-Tournament-R5.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentEscrowVault V1.0    

contract MiracleTournamentEscrow is ContractMetadata {

    address public admin;
    address payable public tournamentAddr;

    uint public RoyaltyPrizeDev; // Royalty rate
    uint public RoyaltyregfeeDev; // Royalty rate
    uint public RoyaltyPrizeFlp; // Royalty rate
    uint public RoyaltyregfeeFlp; // Royalty rate
    
    address public royaltyAddrDev;
    address public royaltyAddrFlp;
    
    IERC1155 public NexusPointEdition;
    uint public NexusPointID;

    struct Tournament {
        address organizer;
        IERC20 prizeToken;
        IERC20 feeToken;
        uint prizeAmount;
        uint joinFee;
        uint feeBalance;
        uint256[] prizeAmountArray;
        bool tournamentCreated;
        bool tournamentEnded;
        bool tournamentCanceled;
        string tournamentURI;
        uint PlayersLimit;
    }

    mapping(uint => Tournament) public tournamentMapping;

    constructor(address adminAddr, address _royaltyAddrDev, address _royaltyAddrFlp, IERC1155 _NexusPointEdition, uint _NexusPointID, string memory _contractURI) {
        admin = adminAddr;
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrFlp = _royaltyAddrFlp;
        // Set default dev royalty 
        RoyaltyPrizeDev = 5;
        RoyaltyregfeeDev = 5;
        // Set default platform royalty 
        RoyaltyPrizeFlp = 5;
        RoyaltyregfeeFlp = 5;
        deployer = adminAddr;
        NexusPointEdition = _NexusPointEdition;
        NexusPointID = _NexusPointID;
        // Bubble shooter : ipfs://QmVxtz27K6oCPeDZKHDoXGpqu3eYcDmXTXkQ66bn5z5uEm/BubbleShooterEscrowR5.json
        // Miracle bingo : ipfs://QmVxtz27K6oCPeDZKHDoXGpqu3eYcDmXTXkQ66bn5z5uEm/MiracleBingoEscrowR5.json
        _setupContractURI("ipfs://QmVxtz27K6oCPeDZKHDoXGpqu3eYcDmXTXkQ66bn5z5uEm/MiracleBingoEscrowR5.json");
    }

}