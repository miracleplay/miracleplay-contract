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

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract  MiracleTournamentManager {

    address private admin;
    uint256 private developerFeePercent;
    uint256 private winnerClubFeePercent;
    uint256 private platformFeePercent;
    address private developerFeeAddress;
    address private winnerClubFeeAddress;
    address private platformFeeAddress;

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

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function.");
        _;
    }

    constructor() {
        admin = msg.sender;
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

    function updatePrizeDistributionByAdmin(uint256 _tournamentId, uint256[] memory _prizeDistribution) external onlyAdmin {
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
    function removeParticipant(uint256 _tournamentId, address _participant) external onlyAdmin {
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

    // Shuffle participants (Admin only)
    function shuffleParticipants(uint256 _tournamentId) external onlyAdmin {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament must be active to shuffle participants.");
        uint256 numParticipants = tournament.participants.length;
        for (uint256 i = 0; i < numParticipants; i++) {
            uint256 n = i + uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))) % (numParticipants - i);
            address temp = tournament.participants[n];
            tournament.participants[n] = tournament.participants[i];
            tournament.participants[i] = temp;
        }
    }

    // Cancel tournament
    function cancelTournament(uint256 _tournamentId) external {
        Tournament storage tournament = tournaments[_tournamentId];
        require(msg.sender == admin || msg.sender == tournament.creator, "Only admin or creator can cancel.");
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
    function endTournamentC(uint256 _tournamentId, address[] memory _winners) external onlyAdmin {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");
        require(!tournament.isPrizesSet, "Prizes already set.");

        uint256 totalPrize = tournament.prizeAmount;
        uint256 totalEntryFee = tournament.entryFee * tournament.participants.length;

        // Step 1: Transfer and distribute fees (prize and entry fees)
        TransferFees(totalPrize, totalEntryFee, tournament.prizeTokenAddress, tournament.entryTokenAddress);

        // Set the tournament as ended but wait for manual prize distribution
        tournament.isActive = false;
        tournament.isPrizesSet = true;

        // Step 2: setDistributePrizes
        // Step 3: distributePrizes or claimPrize
    }

    // End tournament and automatically handle fees, prize setting, and distribution
    function endTournamentA(uint256 _tournamentId, address[] memory _winners) external onlyAdmin {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");
        require(!tournament.isPrizesSet, "Prizes already set.");

        uint256 totalPrize = tournament.prizeAmount;
        uint256 totalEntryFee = tournament.entryFee * tournament.participants.length;

        // Step 1: Transfer fees (both prize and entry fees)
        TransferFees(totalPrize, totalEntryFee, tournament.prizeTokenAddress, tournament.entryTokenAddress);

        // Step 2 and 3: Calculate and directly distribute prizes
        uint256 remainingPrize = calculateAdjustedPrize(totalPrize);
        IERC20 prizeToken = IERC20(tournament.prizeTokenAddress);

        for (uint256 i = 0; i < _winners.length; i++) {
            uint256 adjustedPrize = (remainingPrize * tournament.prizeDistribution[i]) / totalPrize;
            prizeToken.transfer(_winners[i], adjustedPrize);  // Directly transfer the prize
        }

        // Finalize tournament state
        tournament.isActive = false;
        tournament.isPrizesSet = true;
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

    // Set distribute prizes (manual distribution)
    function setDistributePrizes(uint256 _tournamentId, address[] memory _winners) external onlyAdmin {
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

    // Distribute prizes by admin (Version 1)
    function distributePrizes(uint256 _tournamentId, address[] memory _winners) external onlyAdmin {
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
    function setDeveloperFee(address _feeAddress, uint256 _feePercent) external onlyAdmin {
        developerFeeAddress = _feeAddress;
        developerFeePercent = _feePercent;
    }

    function setWinnerClubFee(address _feeAddress, uint256 _feePercent) external onlyAdmin {
        winnerClubFeeAddress = _feeAddress;
        winnerClubFeePercent = _feePercent;
    }

    function setPlatformFee(address _feeAddress, uint256 _feePercent) external onlyAdmin {
        platformFeeAddress = _feeAddress;
        platformFeePercent = _feePercent;
    }
}
