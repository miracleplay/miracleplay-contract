// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/


pragma solidity 0.8.17;

contract Tournament {

    struct Player {
        uint id;
        string name;
        bool isRegistered;
    }

    struct Match {
        uint player1Id;
        uint player2Id;
        uint winnerId;
        bool isPlayed;
    }

    struct Round {
        uint id;
        uint[] matchIds;
        bool isCompleted;
    }

    Player[] public players;
    Match[] public matches;
    Round[] public rounds;

    mapping(string => bool) public playerNameExists;
    mapping(uint => bool) public playerIdExists;
    mapping(address => uint) public playerAddressToId;

    address public organizer;
    uint public maxPlayersPerMatch;
    uint public registrationDeadline;
    uint public nextPlayerId;
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

    function register(string memory _name) public registrationOpen {
        require(!playerNameExists[_name], "Name already registered");
        require(players.length < maxPlayersPerMatch * 2 ** (rounds.length + 1), "Max number of players reached");

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

    function createMatches() public onlyOrganizer {
        require(players.length >= 2, "Not enough players to create matches");

        uint numberOfMatches = players.length / 2;
        uint[] memory playerIds = new uint[](players.length);

        for (uint i = 0; i < players.length; i++) {
            playerIds[i] = players[i].id;
        }

        shuffle(playerIds);

        for (uint j = 0; j < numberOfMatches; j++) {
            Match memory match = Match({
                player1Id: playerIds[j * 2],
                player2Id: playerIds[j * 2 + 1],
                winnerId: 0,
                isPlayed: false
            });
            matches.push(match);
        }

        Round memory round = Round({
            id: nextRoundId,
            matchIds: new uint[](numberOfMatches),
            isCompleted: false
        });

        for (uint k = 0; k < numberOfMatches; k++) {
            round.matchIds[k] = nextMatchId + k;
        }

        rounds.push(round);

        nextMatchId += numberOfMatches;
        nextRoundId++;
        delete players;
    }

function reportWinner(uint _matchId, uint _winnerId) public onlyOrganizer {
        require(playerIdExists[_winnerId], "Invalid player id");
        require(matches[_matchId].winnerId == 0, "Winner already reported");
        require(matches[_matchId].isPlayed == false, "Match already played");

        matches[_matchId].winnerId = _winnerId;
        matches[_matchId].isPlayed = true;

        uint currentRoundId = rounds.length - 1;
        uint[] memory matchIdsInCurrentRound = rounds[currentRoundId].matchIds;

        bool allMatchesInCurrentRoundArePlayed = true;
        for (uint i = 0; i < matchIdsInCurrentRound.length; i++) {
            if (matches[matchIdsInCurrentRound[i]].isPlayed == false) {
                allMatchesInCurrentRoundArePlayed = false;
                break;
            }
        }

        if (allMatchesInCurrentRoundArePlayed) {
            rounds[currentRoundId].isCompleted = true;
            if (rounds.length < maxRounds()) {
                createMatches();
            }
        }
    }

    function advanceToNextRound() public onlyOrganizer {
        uint currentRoundId = rounds.length - 1;
        require(rounds[currentRoundId].isCompleted == true, "Current round is not completed yet");
        require(rounds.length < maxRounds(), "Max number of rounds reached");

        createMatches();
    }

    function getPlayerById(uint _playerId) public view returns (uint, string memory, bool) {
        require(playerIdExists[_playerId], "Invalid player id");
        Player memory player = players[_playerId];
        return (player.id, player.name, player.isRegistered);
    }

    function getMatchById(uint _matchId) public view returns (uint, uint, uint, bool) {
        require(_matchId < matches.length, "Invalid match id");
        Match memory match = matches[_matchId];
        return (match.player1Id, match.player2Id, match.winnerId, match.isPlayed);
    }

    function getRoundById(uint _roundId) public view returns (uint, uint[] memory, bool) {
        require(_roundId < rounds.length, "Invalid round id");
        Round memory round = rounds[_roundId];
        return (round.id, round.matchIds, round.isCompleted);
    }

    function maxRounds() public view returns (uint) {
        return (players.length > 1) ? (uint)(log2(players.length) - 1) : 0;
    }

    function shuffle(uint[] memory arr) internal pure {
        for (uint i = arr.length - 1; i >= 0; i--) {
            uint j = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, i))) % arr.length;
            uint temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }
}