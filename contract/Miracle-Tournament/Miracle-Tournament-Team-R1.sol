// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.5.0/contracts/utils/math/Math.sol";

contract MiracleTournament {
    struct Player {
        uint id;
        string name;
        bool isRegistered;
    }

    struct Team {
        uint id;
        string name;
        uint[] playerIds;
        bool isRegistered;
    }

    struct Match {
        uint team1Id;
        uint team2Id;
        uint winnerId;
        bool isPlayed;
    }

    struct Round {
        uint id;
        uint[] matchIds;
        bool isCompleted;
    }

    Player[] public players;
    Team[] public teams;
    Match[] public matches;
    Round[] public rounds;

    mapping(string => bool) public playerNameExists;
    mapping(uint => bool) public playerIdExists;
    mapping(address => uint) public playerAddressToId;

    mapping(string => bool) public teamNameExists;
    mapping(uint => bool) public teamIdExists;

    address public organizer;
    uint public maxPlayersPerMatch;
    uint public registrationDeadline;
    uint public nextPlayerId;
    uint public nextTeamId;
    uint public nextMatchId;
    uint public nextRoundId;

    modifier onlyOrganizer() {
        require(msg.sender == organizer, "Only organizer can call this function");
        _;
    }

    modifier registrationOpen() {
        require(block.timestamp <= registrationDeadline, "Registration deadline passed");
        _;
    }

    constructor(uint _maxPlayersPerMatch, uint _registrationDeadline) {
        organizer = msg.sender;
        maxPlayersPerMatch = _maxPlayersPerMatch;
        registrationDeadline = _registrationDeadline;
    }

    function registerPlayer(string memory _name) public registrationOpen {
        require(!playerNameExists[_name], "Name already registered");

        Player memory player = Player({
            id: nextPlayerId,
            name: _name,
            isRegistered: true
        });
        players.push(player);

        playerNameExists[_name] = true;
        playerIdExists[nextPlayerId] = true;
        playerAddressToId[msg.sender] = nextPlayerId;

        nextPlayerId++;
    }

    function registerTeam(string memory _name, uint[] memory _playerIds) public registrationOpen {
        require(!teamNameExists[_name], "Name already registered");
        require(_playerIds.length <= maxPlayersPerMatch, "Too many players in the team");
        require(_playerIds.length > 1, "At least 2 players are required in the team");
        require(players.length >= _playerIds.length, "Not enough players to create a team");

        uint[] memory validPlayerIds = new uint[](_playerIds.length);
        for (uint i = 0; i < _playerIds.length; i++) {
            require(playerIdExists[_playerIds[i]], "Invalid player id");
            validPlayerIds[i] = _playerIds[i];
        }

        Team memory team = Team({
            id: nextTeamId,
            name: _name,
            playerIds: validPlayerIds,
            isRegistered: true
        });

        teams.push(team);

        teamNameExists[_name] = true;
        teamIdExists[team.id] = true;

        for (uint j = 0; j < validPlayerIds.length; j++) {
            uint playerId = validPlayerIds[j];
            Player storage player = players[playerId];
            player.isRegistered =            false;
        }
        
        nextTeamId++;
    }

    function createRound() public onlyOrganizer {
        require(matches.length > 0, "No matches to create round");

        uint[] memory matchIds = new uint[](matches.length);
        for (uint i = 0; i < matches.length; i++) {
            matchIds[i] = i;
        }

        shuffle(matchIds);

        Round memory round = Round({
            id: nextRoundId,
            matchIds: matchIds,
            isCompleted: false
        });

        rounds.push(round);

        nextRoundId++;
    }

    function startRound(uint _roundId) public onlyOrganizer {
        require(_roundId < rounds.length, "Invalid round id");
        require(rounds[_roundId].isCompleted == false, "Round already completed");

        Round storage round = rounds[_roundId];

        for (uint i = 0; i < round.matchIds.length; i++) {
            uint matchId = round.matchIds[i];
            Match storage currentMatch = matches[matchId];

            if (currentMatch .isPlayed == false) {
                require(teams[currentMatch .team1Id].isRegistered && teams[currentMatch .team2Id].isRegistered, "One or both teams unregistered");

                emit MatchStarted(_roundId, matchId, currentMatch .team1Id, currentMatch .team2Id);

                currentMatch .isPlayed = true;
            }
        }
    }

    function reportWinner(uint _matchId, uint _winnerId) public onlyOrganizer {
        require(_matchId < matches.length, "Invalid match id");
        require(_winnerId == matches[_matchId].team1Id || _winnerId == matches[_matchId].team2Id, "Invalid winner id");
        require(matches[_matchId].isPlayed == true, "Match not played");

        matches[_matchId].winnerId = _winnerId;

        emit MatchCompleted(_matchId, _winnerId);
    }

    function completeRound(uint _roundId) public onlyOrganizer {
        require(_roundId < rounds.length, "Invalid round id");
        require(rounds[_roundId].isCompleted == false, "Round already completed");

        Round storage round = rounds[_roundId];

        for (uint i = 0; i < round.matchIds.length; i++) {
            uint matchId = round.matchIds[i];
            Match storage currentMatch  = matches[matchId];

            if (currentMatch .isPlayed == true) {
                require(currentMatch .winnerId == matches[matchId].team1Id || currentMatch .winnerId == matches[matchId].team2Id, "Invalid winner id");

                emit MatchCompleted(matchId, currentMatch.winnerId);
            }
        }

        round.isCompleted = true;
    }

    function getRoundMatchIds(uint _roundId) public view returns (uint[] memory) {
        require(_roundId < rounds.length, "Invalid round id");

        Round memory round = rounds[_roundId];

        return round.matchIds;
    }

    function getPlayerById(uint _playerId) public view returns (uint, string memory, bool, uint) {
        require(playerIdExists[_playerId], "Invalid player id");
        Player memory player = players[_playerId];
        uint teamId = getTeamIdByPlayerId(_playerId);
        return (player.id, player.name, player.isRegistered, teamId);
    }

    function getTeamIdByPlayerId(uint _playerId) public view returns (uint) {
        for (uint i = 0; i < teams.length; i++) {
            for (uint j = 0; j < teams[i].playerIds.length; j++) {
                if (teams[i].playerIds[j] == _playerId) {
                    return teams[i].id;
                }
            }
        }
        return 0;
    }

    function shuffle(uint[] memory arr) internal pure {
        uint n = arr.length;
        for (uint i = 0; i < n; i++) {
            uint j = i + uint(keccak256(abi.encodePacked(i))) % (n - i);
            (arr[i], arr[j]) = (arr[j], arr[i]);
        }
    }

    function getNumberOfRounds() public view returns (uint) {
        uint numRounds = 0;
        uint numTeams = teams.length;
        while (numTeams > 1) {
            numRounds++;
            numTeams = (numTeams % 2 == 0) ? numTeams / 2 : (numTeams + 1) / 2;
        }
        return numRounds;
    }

    function getPot() public view returns (uint) {
        return address(this).balance;
    }

    event MatchStarted(uint roundId, uint matchId, uint team1Id, uint team2Id);
    event MatchCompleted(uint matchId, uint winnerId);
}


