// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;


//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//                                                                                                             

import "@openzeppelin/contracts/utils/math/Math.sol";

pragma solidity 0.8.17;

contract Tournament {

    struct Player {
        uint id;
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

    bool public tournamentStarted;

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
        require(!tournamentStarted, "The tournament has already started")
        require(!playerNameExists[_name], "Name already registered");
        require(players.length < maxPlayersPerMatch * 2 ** (rounds.length + 1), "Max number of players reached");

        Player memory player = Player({
            id: nextPlayerId,
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
            Match memory tournamentMatch = Match({
                player1Id: playerIds[j * 2],
                player2Id: playerIds[j * 2 + 1],
                winnerId: 0,
                isPlayed: false
            });
            matches.push(tournamentMatch);
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

        Match storage tournamentMatch = matches[_matchId];
        require(!tournamentMatch.isPlayed, "Match already played");

        tournamentMatch.winnerId = _winnerId;
        tournamentMatch.isPlayed = true;

        // Add winner to players array
        bool winnerAdded = false;
        for (uint i = 0; i < players.length; i++) {
            if (players[i].id == _winnerId) {
                winnerAdded = true;
                break;
            }
        }
        if (!winnerAdded) {
            Player memory winner = Player({
                id: _winnerId,
                isRegistered: true;
            });
            players.push(winner);
        }

        // Check if all matches in the round have been played
        bool roundCompleted = true;
        for (uint j = 0; j < rounds[nextRoundId - 1].matchIds.length; j++) {
            uint matchId = rounds[nextRoundId - 1].matchIds[j];
            if (!matches[matchId].isPlayed) {
                roundCompleted = false;
                break;
            }
        }

        // If all matches in the round have been played, mark the round as completed and create new matches for the next round
        if (roundCompleted) {
            rounds[nextRoundId - 1].isCompleted = true;
            createMatches();
        }
    }

    function advanceToNextRound() public onlyOrganizer {
        uint currentRoundId = rounds.length - 1;
        require(rounds[currentRoundId].isCompleted == true, "Current round is not completed yet");
        require(rounds.length < maxRounds(), "Max number of rounds reached");

        createMatches();
    }

    function getPlayerById(uint _playerId) public view returns (uint, bool) {
        require(playerIdExists[_playerId], "Invalid player id");
        Player memory player = players[_playerId];
        return (player.id, player.isRegistered);
    }

    function getMatchById(uint _matchId) public view returns (uint, uint, uint, bool) {
        require(_matchId < matches.length, "Invalid match id");
        Match memory tournamentMatch = matches[_matchId];
        return (tournamentMatch.player1Id, tournamentMatch.player2Id, tournamentMatch.winnerId, tournamentMatch.isPlayed);
    }


    function getRoundById(uint _roundId) public view returns (uint, uint[] memory, bool) {
        require(_roundId < rounds.length, "Invalid round id");
        Round memory round = rounds[_roundId];
        return (round.id, round.matchIds, round.isCompleted);
    }

    function getTotalPlayers() public view returns (uint) {
        return players.length;
    }

    function maxRounds() public view returns (uint) {
        return (players.length > 1) ? (uint)(Math.log2(players.length) - 1) : 0;
    }

    function shuffle(uint[] memory arr) internal view {
        for (uint i = arr.length - 1; i >= 0; i--) {
            uint j = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, i))) % arr.length;
            uint temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }

}
