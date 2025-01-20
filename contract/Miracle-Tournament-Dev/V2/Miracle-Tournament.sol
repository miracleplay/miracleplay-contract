// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TournamentManagerClaimable {

    address public admin;
    uint256 public developerFeePercent;
    uint256 public winnerClubFeePercent;
    uint256 public platformFeePercent;
    address public developerFeeAddress;
    address public winnerClubFeeAddress;
    address public platformFeeAddress;

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
        bool isPrizesSet;
    }

    mapping(uint256 => Tournament) public tournaments;

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
    }

    // Update prize distribution
    function updatePrizeDistribution(uint256 _tournamentId, uint256[] memory _prizeDistribution) external onlyAdmin {
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

    // Calculate and distribute fees
    function calculateFees(uint256 totalPrize, address prizeTokenAddress) internal {
        IERC20 prizeToken = IERC20(prizeTokenAddress);

        uint256 developerFee = (totalPrize * developerFeePercent) / 100;
        uint256 winnerClubFee = (totalPrize * winnerClubFeePercent) / 100;
        uint256 platformFee = (totalPrize * platformFeePercent) / 100;

        prizeToken.transfer(developerFeeAddress, developerFee);
        prizeToken.transfer(winnerClubFeeAddress, winnerClubFee);
        prizeToken.transfer(platformFeeAddress, platformFee);
    }

    // Calculate the adjusted prize for winners after fee deduction
    function calculateAdjustedPrize(uint256 totalPrize) internal view returns (uint256) {
        uint256 remainingPrize = totalPrize - (totalPrize * (developerFeePercent + winnerClubFeePercent + platformFeePercent)) / 100;
        return remainingPrize;
    }

    // End tournament and set claimable prizes
    function endTournament(uint256 _tournamentId, address[] memory _winners) external onlyAdmin {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");
        require(!tournament.isPrizesSet, "Prizes already set.");

        uint256 totalPrize = tournament.prizeAmount;

        // Calculate and distribute fees
        calculateFees(totalPrize, tournament.prizeTokenAddress);

        // Calculate remaining prize after fees
        uint256 remainingPrize = calculateAdjustedPrize(totalPrize);

        // Set prize for each winner based on remaining prize
        for (uint256 i = 0; i < _winners.length; i++) {
            uint256 adjustedPrize = (remainingPrize * tournament.prizeDistribution[i]) / totalPrize; // Adjust prize based on remaining prize
            tournament.winnerPrizes[_winners[i]] = adjustedPrize;
        }

        tournament.isActive = false;
        tournament.isPrizesSet = true;
    }

    // Winner claims their prize
    function claimPrize(uint256 _tournamentId) external {
        Tournament storage tournament = tournaments[_tournamentId];
        require(!tournament.isActive, "Tournament must be ended to claim prizes.");
        require(tournament.isPrizesSet, "Prizes have not been set.");
        uint256 prizeAmount = tournament.winnerPrizes[msg.sender];
        require(prizeAmount > 0, "No prize to claim.");

        tournament.winnerPrizes[msg.sender] = 0; // Prevent double claim

        IERC20 prizeToken = IERC20(tournament.prizeTokenAddress);
        prizeToken.transfer(msg.sender, prizeAmount);
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
