// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TournamentManagerAutoDistribute {

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
        bool isPrizesDistributed; // Flag to check if prizes have been distributed
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
        tournament.isPrizesDistributed = false;
    }

    // Update prize distribution
    function updatePrizeDistribution(uint256 _tournamentId, uint256[] memory _prizeDistribution) external onlyAdmin {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.id != 0, "Tournament does not exist.");

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

    // End tournament and handle fees (this function only handles fees)
    function endTournament(uint256 _tournamentId) external onlyAdmin {
        Tournament storage tournament = tournaments[_tournamentId];
        require(tournament.isActive, "Tournament is not active.");
        require(!tournament.isPrizesDistributed, "Prizes have already been distributed.");

        uint256 totalPrize = tournament.prizeAmount;
        IERC20 prizeToken = IERC20(tournament.prizeTokenAddress);

        // Calculate total fee percentages
        uint256 totalFeePercent = developerFeePercent + winnerClubFeePercent + platformFeePercent;
        require(totalFeePercent <= 100, "Total fee percent exceeds 100");

        // Calculate fees
        uint256 developerFee = (totalPrize * developerFeePercent) / 100;
        uint256 winnerClubFee = (totalPrize * winnerClubFeePercent) / 100;
        uint256 platformFee = (totalPrize * platformFeePercent) / 100;

        // Transfer fees
        prizeToken.transfer(developerFeeAddress, developerFee);
        prizeToken.transfer(winnerClubFeeAddress, winnerClubFee);
        prizeToken.transfer(platformFeeAddress, platformFee);

        // Mark the tournament as ended
        tournament.isActive = false;
    }

    // Distribute prizes (this function can be called in separate transactions to avoid gas limit issues)
    function distributePrizes(uint256 _tournamentId, address[] memory _winners) external onlyAdmin {
        Tournament storage tournament = tournaments[_tournamentId];
        require(!tournament.isActive, "Tournament must be ended before distributing prizes.");
        require(!tournament.isPrizesDistributed, "Prizes have already been distributed.");
        require(_winners.length == tournament.prizeDistribution.length, "Winners and prize distribution length mismatch.");

        uint256 totalPrize = tournament.prizeAmount;
        uint256 remainingPrize = totalPrize - (totalPrize * (developerFeePercent + winnerClubFeePercent + platformFeePercent)) / 100;
        IERC20 prizeToken = IERC20(tournament.prizeTokenAddress);

        // Adjust prize distribution according to remaining prize
        for (uint256 i = 0; i < _winners.length; i++) {
            uint256 adjustedPrize = (remainingPrize * tournament.prizeDistribution[i]) / totalPrize; // Adjust prize based on remaining prize
            prizeToken.transfer(_winners[i], adjustedPrize);
        }

        tournament.isPrizesDistributed = true;
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
