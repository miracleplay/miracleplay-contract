// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract PointTournament {
    struct Player {
        uint id;
        address payable account;
        uint score;
        bool isRegistered;
    }

    Player[] public players;
    mapping(address => uint) public playerIdByAccount;

    address payable public organizer;
    uint public registrationDeadline;
    uint public tournamentEndTime;
    bool public tournamentEnded;

    event Registered(address account);
    event ScoreUpdated(address account, uint score);
    event TournamentEnded();

    modifier onlyOrganizer() {
        require(msg.sender == organizer, "Only organizer can call this function");
        _;
    }

    modifier registrationOpen() {
        require(block.timestamp <= registrationDeadline, "Registration deadline passed");
        _;
    }

    modifier tournamentNotStarted() {
        require(block.timestamp < tournamentEndTime, "Tournament has already started");
        _;
    }

    modifier tournamentEndedOrNotStarted() {
        require(tournamentEnded || block.timestamp < tournamentEndTime, "Tournament has ended");
        _;
    }

    uint public registerStartTime;
    uint public registerEndTime;

    constructor(uint _registrationDeadline, uint _tournamentDurationDays, uint _registerStartTime, uint _registerEndTime) {
        organizer = payable(msg.sender);
        registrationDeadline = _registrationDeadline;
        tournamentEndTime = block.timestamp + (_tournamentDurationDays * 1 days);
        registerStartTime = _registerStartTime;
        registerEndTime = _registerEndTime;
    }

    function register() public payable registrationOpen {
        require(msg.value > 0, "Registration fee must be greater than 0");
        require(block.timestamp >= registerStartTime, "Registration has not started yet");
        require(block.timestamp <= registerEndTime, "Registration deadline passed");

        Player memory player = Player({
            id: players.length,
            account: payable(msg.sender),
            score: 0,
            isRegistered: true
        });
        players.push(player);
        playerIdByAccount[msg.sender] = player.id;

        emit Registered(msg.sender);
    }


    function updateScore(address _account, uint _score) public onlyOrganizer tournamentNotStarted tournamentEndedOrNotStarted {
        require(playerIdByAccount[_account] > 0, "Player not registered");
        Player storage player = players[playerIdByAccount[_account]];

        player.score += _score;
        emit ScoreUpdated(_account, player.score);
    }

    function endTournament() public onlyOrganizer tournamentNotStarted {
        tournamentEnded = true;
        emit TournamentEnded();
    }

    function getRanking() public view returns (address[] memory, uint[] memory) {
        uint len = players.length;
        address[] memory addrs = new address[](len);
        uint[] memory scores = new uint[](len);

        for (uint i = 0; i < len; i++) {
            addrs[i] = players[i].account;
            scores[i] = players[i].score;
        }

        return (addrs, scores);
    }
}
