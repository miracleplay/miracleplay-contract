// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;    

import "./Miracle-Escrow-G1.sol";

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   

contract ScoreTournament {

    address public EscrowAddr;

    struct Player {
        uint id;
        address account;
        uint score;
        bool isRegistered;
        uint rank;
    }

    struct Tournament {
        Player[] players;
        mapping(address => uint) playerIdByAccount;
        mapping(uint => address) rankToAccount;
        mapping(address => uint) accountToRank;
        address organizer;
        uint registerStartTime;
        uint registerEndTime;
        uint tournamentStartTime;
        uint tournamentEndTime;
        uint prizeCount;
        bool tournamentEnded;
        string tournamentURI;
    }

    address admin;
    mapping(uint => Tournament) public tournamentMapping;

    event CreateTournament(uint tournamentId);
    event Registered(address account);
    event ScoreUpdated(address account, uint score);
    event TournamentEnded(uint tournamentId);

    constructor(address adminAddress) {
        admin = adminAddress;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyEscrow(){
        require(msg.sender == EscrowAddr,  "Only escorw contract can call this function");
        _;
    }

    modifier registrationOpen(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp >= tournament.registerStartTime, "Registration has not started yet");
        require(block.timestamp <= tournament.registerEndTime, "Registration deadline passed");
        _;
    }

    modifier onlyOrganizer(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(msg.sender == tournament.organizer, "Only organizer can call this function");
        _;
    }

    modifier tournamentNotStarted(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp < tournament.tournamentEndTime, "Tournament has already started");
        require(block.timestamp > tournament.tournamentStartTime, "Tournament is not start");
        _;
    }

    modifier tournamentEndedOrNotStarted(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(tournament.tournamentEnded || block.timestamp < tournament.tournamentEndTime, "Tournament has ended");
        _;
    }

    function connectEscrow(address _escrowAddr) public onlyAdmin {
        EscrowAddr = _escrowAddr;
    }

    function createTournament(uint _tournamentId, uint _registerStartTime, uint _registerEndTime, uint _tournamentStartTime, uint _tournamentEndTime, uint _prizeCount, string memory _tournamentURI) public onlyEscrow {
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.organizer = payable(msg.sender);
        newTournament.registerStartTime = _registerStartTime;
        newTournament.registerEndTime = _registerEndTime;
        newTournament.tournamentStartTime = _tournamentStartTime;
        newTournament.tournamentEndTime = _tournamentEndTime;
        newTournament.tournamentEnded = false;
        newTournament.prizeCount = _prizeCount;
        newTournament.tournamentURI = _tournamentURI;

        emit CreateTournament(_tournamentId);
    }

    function register(uint tournamentId) public payable registrationOpen(tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp >= tournament.registerStartTime, "Registration has not started yet");
        require(block.timestamp <= tournament.registerEndTime, "Registration deadline passed");
        uint playerId = tournament.players.length;

        Player memory player = Player({
            id: playerId,
            account: payable(msg.sender),
            score: 0,
            isRegistered: true,
            rank: 0
        });

        tournament.players.push(player);
        tournament.playerIdByAccount[msg.sender] = playerId;

        emit Registered(msg.sender);
    }

    function updateScore(uint tournamentId, address _account, uint _score) public onlyAdmin tournamentNotStarted(tournamentId) tournamentEndedOrNotStarted(tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(tournament.playerIdByAccount[_account] > 0, "Player not registered");
        Player storage _player = tournament.players[tournament.playerIdByAccount[_account]];

        _player.score += _score;
        emit ScoreUpdated(_account, _player.score);
    }

    function calculateRanking(uint tournamentId) public onlyAdmin {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(tournament.tournamentEnded, "Tournament has not ended yet");
        uint len = tournament.players.length;

        for (uint i = 0; i < len; i++) {
            tournament.rankToAccount[i] = tournament.players[i].account;
        }

        uint[] memory scores = new uint[](len);
        for (uint i = 0; i < len; i++) {
            scores[i] = tournament.players[i].score;
        }

        // sort scores and rearrange the rank mapping
        for (uint i = 0; i < len - 1; i++) {
            for (uint j = i + 1; j < len; j++) {
                if (scores[i] < scores[j]) {
                    uint tempScore = scores[i];
                    scores[i] = scores[j];
                    scores[j] = tempScore;

                    address tempAddr = tournament.rankToAccount[i];
                    tournament.rankToAccount[i] = tournament.rankToAccount[j];
                    tournament.rankToAccount[j] = tempAddr;
                }
            }
        }

        for (uint i = 0; i < len; i++) {
            tournament.accountToRank[tournament.rankToAccount[i]] = i + 1;
        }

        // store the rank and score in the Player struct
        for (uint i = 0; i < len; i++) {
            tournament.players[i].score = scores[i];
            tournament.players[i].isRegistered = false;
            uint rank = tournament.accountToRank[tournament.players[i].account];
            tournament.players[i] = Player(tournament.players[i].id, tournament.players[i].account, tournament.players[i].score, tournament.players[i].isRegistered, rank);
        }

        emit TournamentEnded(tournamentId);
    }

    function endTournament(uint tournamentId) public onlyAdmin tournamentNotStarted(tournamentId){
        calculateRanking(tournamentId);
        Tournament storage tournament = tournamentMapping[tournamentId];
        uint _prizeCount = tournament.prizeCount;
        address[] memory prizeAddr = new address[](_prizeCount);
        for(uint i = 0; i < _prizeCount; i++){
            prizeAddr[i] = tournament.rankToAccount[i];
        }
        TournamentEscrow(EscrowAddr).updateWithdrawals(tournamentId, prizeAddr);
        tournament.tournamentEnded = true;
    }
}