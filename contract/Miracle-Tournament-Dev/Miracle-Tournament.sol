// SPDX-License-Identifier: MIT
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentManager V1.0
pragma solidity ^0.8.0;
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract  MiracleTournamentManager is PermissionsEnumerable, Multicall, ContractMetadata{
    address public deployer;
    uint256 private developerFeePercent;
    uint256 private winnerClubFeePercent;
    uint256 private platformFeePercent;
    address private developerFeeAddress;
    address private winnerClubFeeAddress;
    address private platformFeeAddress;

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    struct Tournament {
        uint256 id;
        address creator;
        address prizeTokenAddress;
        address entryTokenAddress;
        uint256 prizeAmount;
        uint256 entryFee;
        uint256 maxParticipants;
        bool isActive;
        bool isCancelled;
        address[] participants;
        uint256[] prizeDistribution;
        mapping(address => uint256) winnerPrizes; // Each winner's prize amount
        bool isPrizesSet; // Indicates if the prize distribution is set
        bool isPrizesDistributed; // Indicates if the prizes have been distributed by admin
    }

    mapping(uint256 => Tournament) private tournaments;

    constructor(address admin, string memory _contractURI) {
        deployer = admin;
        _setupContractURI(_contractURI);

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(FACTORY_ROLE, admin);

        _setupRole(FACTORY_ROLE, 0x8914b41C3D0491E751d4eA3EbfC04c42D7275A75);
        _setupRole(FACTORY_ROLE, 0x2fB586cD6bF507998e0816897D812d5dF2aF7677);
        _setupRole(FACTORY_ROLE, 0x7C7f65a0f86a556aAA04FD9ceDb1AA6D943C35c3);
        _setupRole(FACTORY_ROLE, 0xd278a5A5B9A83574852d25F08420029972fd2c6f);
        _setupRole(FACTORY_ROLE, 0x7c35582e6b953b0D7980ED3444363B5c99d1ded3);
        _setupRole(FACTORY_ROLE, 0xe463D4fdBc692D9016949881E6a5e18d815C4537);
        _setupRole(FACTORY_ROLE, 0x622DfbD67fa2e87aa8c774e14fda2791656f282b);
        _setupRole(FACTORY_ROLE, 0xbE810123C22046d93Afb018d7c4b7248df0088BE);
        _setupRole(FACTORY_ROLE, 0xc184A36eac1EA5d62829cc80e8e57E7c4994D40B);
        _setupRole(FACTORY_ROLE, 0xDCa74207a0cB028A2dE3aEeDdC7A9Be52109a785);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    // Tournament creation
    function createTournament(
        uint256 _tournamentId,
        address _prizeTokenAddress,
        address _entryTokenAddress,
        uint256 _prizeAmount,
        uint256 _entryFee,
        uint256[] memory _prizeDistribution,
        uint256 _maxParticipants
    ) external {
        require(tournaments[_tournamentId].id == 0, "Tournament ID already exists.");

        IERC20 prizeToken = IERC20(_prizeTokenAddress);
        prizeToken.transferFrom(msg.sender, address(this), _prizeAmount);

        Tournament storage tournament = tournaments[_tournamentId];
        tournament.id = _tournamentId;
        tournament.creator = msg.sender;
        tournament.prizeTokenAddress = _prizeTokenAddress;
        tournament.entryTokenAddress = _entryTokenAddress;
        tournament.prizeAmount = _prizeAmount;
        tournament.entryFee = _entryFee;
        tournament.maxParticipants = _maxParticipants;
        tournament.isActive = true;
        tournament.isPrizesSet = false;
        tournament.isPrizesDistributed = false;

        updatePrizeDistribution(_tournamentId, _prizeDistribution);
    }

    // Update prize distribution
    function updatePrizeDistribution(uint256 _tournamentId, uint256[] memory _prizeDistribution) internal {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.id != 0, "Tournament does not exist.");
        require(!tournament.isPrizesSet, "Prizes already set.");

        uint256 totalPrize = 0;
        for (uint256 i = 0; i < _prizeDistribution.length; i++) {
            totalPrize += _prizeDistribution[i];
        }
        require(totalPrize == tournament.prizeAmount, "Total prize distribution must equal prizeAmount.");

        tournament.prizeDistribution = _prizeDistribution;
    }

    function updatePrizeDistributionByFactory(uint256 _tournamentId, uint256[] memory _prizeDistribution) external onlyRole(FACTORY_ROLE) {
        updatePrizeDistribution(_tournamentId, _prizeDistribution);
    }

    // Participate in a tournament
    function participateInTournament(uint256 _tournamentId) external {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");
        require(tournament.participants.length < tournament.maxParticipants, "Maximum participants reached.");

        if (tournament.entryFee > 0) {
            IERC20 entryToken = IERC20(tournament.entryTokenAddress);
            entryToken.transferFrom(msg.sender, address(this), tournament.entryFee);
        }

        tournament.participants.push(msg.sender);
    }

    // Remove participant
    function removeParticipant(uint256 _tournamentId, address _participant) external onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");

        for (uint256 i = 0; i < tournament.participants.length; i++) {
            if (tournament.participants[i] == _participant) {
                tournament.participants[i] = tournament.participants[tournament.participants.length - 1];
                tournament.participants.pop();
                if (tournament.entryFee > 0) {
                    IERC20 entryToken = IERC20(tournament.entryTokenAddress);
                    entryToken.transfer(_participant, tournament.entryFee);
                }
                break;
            }
        }
    }

    // Shuffle participants
    function shuffleParticipants(uint256 _tournamentId) external onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament must be active to shuffle participants.");
        
        uint256 numParticipants = tournament.participants.length;
        for (uint256 i = 0; i < numParticipants; i++) {
            uint256 n = i + uint256(keccak256(abi.encodePacked(
                block.timestamp,
                block.prevrandao,   // Replace block.difficulty with block.prevrandao
                msg.sender,
                _tournamentId,
                i
            ))) % (numParticipants - i);
            
            address temp = tournament.participants[n];
            tournament.participants[n] = tournament.participants[i];
            tournament.participants[i] = temp;
        }
    }

    // Cancel tournament
    function cancelTournament(uint256 _tournamentId) external onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");

        for (uint256 i = 0; i < tournament.participants.length; i++) {
            if (tournament.entryFee > 0) {
                IERC20 entryToken = IERC20(tournament.entryTokenAddress);
                entryToken.transfer(tournament.participants[i], tournament.entryFee);
            }
        }

        IERC20 prizeToken = IERC20(tournament.prizeTokenAddress);
        prizeToken.transfer(tournament.creator, tournament.prizeAmount);

        tournament.isActive = false;
        tournament.isCancelled = true;
    }

    // End tournament and calculate claimable prizes
    function endTournamentC(uint256 _tournamentId, address[] memory _winners) external onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");
        require(!tournament.isPrizesSet, "Prizes already set.");
        require(!tournament.isPrizesDistributed, "Prizes already distributed.");

        uint256 totalPrize = tournament.prizeAmount;
        uint256 totalEntryFee = tournament.entryFee * tournament.participants.length;

        // Step 1: Transfer and distribute fees (prize and entry fees)
        TransferFees(totalPrize, totalEntryFee, tournament.prizeTokenAddress, tournament.entryTokenAddress);

        // Step 2 and 3: Calculate and set prizes for claim
        setDistributePrizes(_tournamentId, _winners);

        // Finalize tournament state
        tournament.isActive = false;
        tournament.isPrizesSet = true;
    }

    // End tournament and automatically handle fees, prize setting, and distribution
    function endTournamentA(uint256 _tournamentId, address[] memory _winners) external onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");
        require(!tournament.isPrizesSet, "Prizes already set.");
        require(!tournament.isPrizesDistributed, "Prizes already distributed.");

        uint256 totalPrize = tournament.prizeAmount;
        uint256 totalEntryFee = tournament.entryFee * tournament.participants.length;

        // Step 1: Transfer fees (both prize and entry fees)
        TransferFees(totalPrize, totalEntryFee, tournament.prizeTokenAddress, tournament.entryTokenAddress);

        // Step 2 and 3: Calculate and directly distribute prizes
        distributePrizes(_tournamentId, _winners);

        // Finalize tournament state
        tournament.isActive = false;
        tournament.isPrizesDistributed = true;
    }

    // Transfer and distribute fees (Prize and Entry fees)
    function TransferFees(uint256 totalPrize, uint256 totalEntryFee, address prizeTokenAddress, address entryTokenAddress) internal {
        IERC20 prizeToken = IERC20(prizeTokenAddress);
        IERC20 entryToken = IERC20(entryTokenAddress);

        // Distribute prize fees
        uint256 developerPrizeFee = (totalPrize * developerFeePercent) / 100;
        uint256 winnerClubPrizeFee = (totalPrize * winnerClubFeePercent) / 100;
        uint256 platformPrizeFee = (totalPrize * platformFeePercent) / 100;

        prizeToken.transfer(developerFeeAddress, developerPrizeFee);
        prizeToken.transfer(winnerClubFeeAddress, winnerClubPrizeFee);
        prizeToken.transfer(platformFeeAddress, platformPrizeFee);

        // Distribute entry fee
        uint256 developerEntryFee = (totalEntryFee * developerFeePercent) / 100;
        uint256 winnerClubEntryFee = (totalEntryFee * winnerClubFeePercent) / 100;
        uint256 platformEntryFee = (totalEntryFee * platformFeePercent) / 100;

        entryToken.transfer(developerFeeAddress, developerEntryFee);
        entryToken.transfer(winnerClubFeeAddress, winnerClubEntryFee);
        entryToken.transfer(platformFeeAddress, platformEntryFee);
    }

    // Calculate the adjusted prize for winners after fee deduction
    function calculateAdjustedPrize(uint256 totalPrize) internal view returns (uint256) {
        uint256 remainingPrize = totalPrize - (totalPrize * (developerFeePercent + winnerClubFeePercent + platformFeePercent)) / 100;
        return remainingPrize;
    }

    // Set distribute prizes (Version 2 - Claim)
    function setDistributePrizes(uint256 _tournamentId, address[] memory _winners) internal {
        Tournament storage tournament = tournaments[_tournamentId];
        require(!tournament.isActive, "Tournament must be ended.");
        require(!tournament.isPrizesDistributed, "Prizes have already been distributed.");
        require(tournament.isPrizesSet, "Prizes have not been set.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");

        uint256 totalPrize = tournament.prizeAmount;
        uint256 remainingPrize = calculateAdjustedPrize(totalPrize);

        // Set prize for each winner based on remaining prize
        for (uint256 i = 0; i < _winners.length; i++) {
            uint256 adjustedPrize = (remainingPrize * tournament.prizeDistribution[i]) / totalPrize;
            tournament.winnerPrizes[_winners[i]] = adjustedPrize;
        }

        tournament.isPrizesDistributed = true;
    }

    // Distribute prizes by admin (Version 1 - Auto distribute)
    function distributePrizes(uint256 _tournamentId, address[] memory _winners) internal {
        Tournament storage tournament = tournaments[_tournamentId];
        require(!tournament.isActive, "Tournament must be ended before distributing prizes.");
        require(!tournament.isPrizesDistributed, "Prizes have already been distributed.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");

        uint256 totalPrize = tournament.prizeAmount;
        uint256 remainingPrize = calculateAdjustedPrize(totalPrize);
        IERC20 prizeToken = IERC20(tournament.prizeTokenAddress);

        for (uint256 i = 0; i < _winners.length; i++) {
            uint256 adjustedPrize = (remainingPrize * tournament.prizeDistribution[i]) / totalPrize;
            prizeToken.transfer(_winners[i], adjustedPrize);
        }

        tournament.isPrizesDistributed = true;
    }

    // Winner claims their prize (Version 2)
    function claimPrize(uint256 _tournamentId) external {
        Tournament storage tournament = tournaments[_tournamentId];
        require(!tournament.isActive, "Tournament must be ended to claim prizes.");
        require(tournament.isPrizesSet, "Prizes have not been set.");
        require(!tournament.isPrizesDistributed, "Prizes already distributed by admin.");

        uint256 prizeAmount = tournament.winnerPrizes[msg.sender];
        require(prizeAmount > 0, "No prize to claim.");

        tournament.winnerPrizes[msg.sender] = 0; // Prevent double claim

        IERC20 prizeToken = IERC20(tournament.prizeTokenAddress);
        prizeToken.transfer(msg.sender, prizeAmount);
    }

    // View functions to retrieve data
    function getTournamentInfo(uint256 _tournamentId) external view returns (
        address creator,
        address prizeTokenAddress,
        address entryTokenAddress,
        uint256 prizeAmount,
        uint256 entryFee,
        uint256 maxParticipants,
        bool isActive,
        bool isCancelled
    ) {
        Tournament storage tournament = tournaments[_tournamentId];
        return (
            tournament.creator,
            tournament.prizeTokenAddress,
            tournament.entryTokenAddress,
            tournament.prizeAmount,
            tournament.entryFee,
            tournament.maxParticipants,
            tournament.isActive,
            tournament.isCancelled
        );
    }

    function getTournamentParticipants(uint256 _tournamentId) external view returns (address[] memory) {
        Tournament storage tournament = tournaments[_tournamentId];
        return tournament.participants;
    }

    function getTournamentPrizeDistribution(uint256 _tournamentId) external view returns (uint256[] memory) {
        Tournament storage tournament = tournaments[_tournamentId];
        return tournament.prizeDistribution;
    }

    function getTournamentFees() external view returns (
        uint256 _developerFeePercent,
        uint256 _winnerClubFeePercent,
        uint256 _platformFeePercent,
        address _developerFeeAddress,
        address _winnerClubFeeAddress,
        address _platformFeeAddress
    ) {
        return (
            developerFeePercent,
            winnerClubFeePercent,
            platformFeePercent,
            developerFeeAddress,
            winnerClubFeeAddress,
            platformFeeAddress
        );
    }

    // Fee management functions
    function setDeveloperFee(address _feeAddress, uint256 _feePercent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        developerFeeAddress = _feeAddress;
        developerFeePercent = _feePercent;
    }

    function setWinnerClubFee(address _feeAddress, uint256 _feePercent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        winnerClubFeeAddress = _feeAddress;
        winnerClubFeePercent = _feePercent;
    }

    function setPlatformFee(address _feeAddress, uint256 _feePercent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        platformFeeAddress = _feeAddress;
        platformFeePercent = _feePercent;
    }
}
