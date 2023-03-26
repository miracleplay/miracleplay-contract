// SPDX-License-Identifier: UNLICENSED

/* 
*This code is subject to the Copyright License
* Copyright (c) 2023 Sevenlinelabs
* All rights reserved.
*/
pragma solidity ^0.8.17;

contract Tournament {

    /**
     * @dev Struct to store player information, including player ID, name, and registration status.
     */
    struct Player {
        uint id;
        string name;
        bool isRegistered;
    }

    /**
     * @dev Struct to store match information, including the IDs of the two players in the match,
     * the ID of the winner, and whether or not the match has been played.
     */
    struct Match {
        uint player1Id;
        uint player2Id;
        uint winnerId;
        bool isPlayed;
    }

    /**
     * @dev Struct to store round information, including the ID of the round, the IDs of all matches in the round,
     * and whether or not the round has been completed.
     */
    struct Round {
        uint id;
        uint[] matchIds;
        bool isCompleted;
    }

    Player[] public players;       // Array to store all players in the tournament.
    Match[] public matches;       // Array to store all matches in the tournament.
    Round[] public rounds;        // Array to store all rounds in the tournament.
    mapping(string => bool) public playerNameExists;  // Mapping to check if a player name already exists.
    mapping(uint => bool) public playerIdExists;      // Mapping to check if a player ID already exists.
    mapping(address => uint) public playerAddressToId; // Mapping to store the ID of a player based on their address.
    address public organizer;     // The address of the tournament organizer.
    uint public maxPlayersPerMatch;   // The maximum number of players per match in the tournament.
    uint public registrationDeadline; // The deadline for player registration in the tournament.
    uint public nextPlayerId;      // The ID to be assigned to the next player to register for the tournament.
    uint public nextMatchId;       // The ID to be assigned to the next match in the tournament.
    uint public nextRoundId;       // The ID to be assigned to the next round in the tournament.



    /**
     * @dev Modifier that allows only the tournament organizer to call a function.
     */
    modifier onlyOrganizer() {
        require(msg.sender == organizer, "Only organizer can call this function");
        _;
    }

    /**
     * @dev Modifier that allows a function to be called only during the player registration period.
     */
    modifier registrationOpen() {
        require(block.timestamp <= registrationDeadline, "Registration deadline passed");
        _;
    }

    /**
     * @dev Constructor function for the tournament contract, which sets the maximum number of players per match
     * and the deadline for player registration.
     * @param _maxPlayersPerMatch The maximum number of players per match in the tournament.
     * @param _registrationDeadline The deadline for player registration in the tournament.
     */
    constructor(uint _maxPlayersPerMatch, uint _registrationDeadline) {
        organizer = msg.sender;
        maxPlayersPerMatch = _maxPlayersPerMatch;
        registrationDeadline = _registrationDeadline;
    }

    /**
     * @dev Function to create matches for the tournament by randomly pairing up registered players.
     * Only the tournament organizer can call this function.
     * The function requires at least two registered players to exist in the tournament.
     * The function shuffles the player IDs to randomly pair up players, and creates a new match for each pair.
     * The function also creates a new round and adds the IDs of the matches to the round.
     * The function updates the IDs for the next match and round, and deletes the existing player list.
     */
    function createMatches() public onlyOrganizer {
        require(players.length >= 2, "Not enough players to create matches");

        // Calculate the number of matches needed for the current round
        uint numberOfMatches = players.length / 2;

        // Create an array of player IDs
        uint[] memory playerIds = new uint[](players.length);
        for (uint i = 0; i < players.length; i++) {
            playerIds[i] = players[i].id;
        }

        // Shuffle the array of player IDs
        shuffle(playerIds);

        // Create a new match for each pair of players
        for (uint j = 0; j < numberOfMatches; j++) {
            Match memory _match = Match({
                player1Id: playerIds[j * 2],
                player2Id: playerIds[j * 2 + 1],
                winnerId: 0,
                isPlayed: false
            });
            matches.push(_match);
        }

        // Create a new round and add the IDs of the matches to the round
        Round memory round = Round({
            id: nextRoundId,
            matchIds: new uint[](numberOfMatches),
            isCompleted: false
        });
        for (uint k = 0; k < numberOfMatches; k++) {
            round.matchIds[k] = nextMatchId + k;
        }
        rounds.push(round);

        // Update the IDs for the next match and round, and delete the existing player list
        nextMatchId += numberOfMatches;
        nextRoundId++;
        delete players;
    }

    /**
     * @dev Function for the tournament organizer to report the winner of a match.
     * The function requires the match ID and the winner's ID as inputs.
     * The function also checks that the winner's ID is valid, that the winner has not already been reported,
     * and that the match has not already been played.
     * The function updates the winner ID and match played status, and checks if all matches in the current round are played.
     * If all matches in the current round are played, the function marks the round as completed and creates matches for the next round,
     * if the maximum number of rounds has not been reached.
     * @param _matchId The ID of the match.
     * @param _winnerId The ID of the winner.
     */
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

    /**
     * @dev Function for the tournament organizer to advance to the next round.
     * The function checks that the current round is completed and that the maximum number of rounds has not been reached.
     * The function then creates matches for the next round.
     */
    function advanceToNextRound() public onlyOrganizer {
        uint currentRoundId = rounds.length - 1;
        require(rounds[currentRoundId].isCompleted == true, "Current round is not completed yet");
        require(rounds.length < maxRounds(), "Max number of rounds reached");

        createMatches();
    }


    /**
     * @dev Function to retrieve player information by player ID.
     * The function requires a valid player ID as input.
     * The function returns the player ID, name, and registration status.
     * @param _playerId The ID of the player.
     * @return A tuple containing the player ID, name, and registration status.
     */
    function getPlayerById(uint _playerId) public view returns (uint, string memory, bool) {
        require(playerIdExists[_playerId], "Invalid player id");
        Player memory player = players[_playerId];
        return (player.id, player.name, player.isRegistered);
    }

    /**
     * @dev Function to retrieve match information by match ID.
     * The function requires a valid match ID as input.
     * The function returns the IDs of the two players in the match, the ID of the winner (if applicable), and whether or not the match has been played.
     * @param _matchId The ID of the match.
     * @return A tuple containing the IDs of the two players in the match, the ID of the winner (if applicable), and whether or not the match has been played.
     */
    function getMatchById(uint _matchId) public view returns (uint, uint, uint, bool) {
        require(_matchId < matches.length, "Invalid match id");
        Match memory _match = matches[_matchId];
        return (_match.player1Id, _match.player2Id, _match.winnerId, _match.isPlayed);
    }

    /**
     * @dev Function to retrieve round information by round ID.
     * The function requires a valid round ID as input.
     * The function returns the round ID, an array of match IDs in the round, and whether or not the round has been completed.
     * @param _roundId The ID of the round.
     * @return A tuple containing the round ID, an array of match IDs in the round, and whether or not the round has been completed.
     */
    function getRoundById(uint _roundId) public view returns (uint, uint[] memory, bool) {
        require(_roundId < rounds.length, "Invalid round id");
        Round memory _round = rounds[_roundId];
        return (_round.id, _round.matchIds, _round.isCompleted);
    }


    /**
     * @dev Function to calculate the maximum number of rounds for the tournament based on the number of registered players.
     * The function returns the maximum number of rounds.
     * @return The maximum number of rounds.
     */
    function maxRounds() public view returns (uint) {
        return (players.length > 1) ? (uint)(log2(players.length) - 1) : 0;
    }

    /**
     * @dev Function to shuffle an array of integers using the Fisher-Yates shuffle algorithm.
     * The function requires an array of integers as input.
     * The function shuffles the array in place using a random number generator based on the current block timestamp and sender address.
     * @param arr The array of integers to be shuffled.
     */
    function shuffle(uint[] memory arr) internal view {
        for (uint i = arr.length - 1; i >= 0; i--) {
            uint j = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, i))) % arr.length;
            uint temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }


    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }
}