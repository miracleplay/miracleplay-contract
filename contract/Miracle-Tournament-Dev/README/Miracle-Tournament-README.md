# MiracleTournament.sol

## Overview
This contract represents a tournament system where users can create tournaments, register participants, update scores, and distribute prizes based on rankings.

## Contract Details
- Solidity Version: ^0.8.17
- License: UNLICENSED

## Dependencies
This contract relies on the following external dependencies:
- [Miracle-Escrow-R2.sol](./Miracle-Escrow-R2.sol)
- [PermissionsEnumerable.sol](https://github.com/thirdweb-dev/contracts/blob/master/extension/PermissionsEnumerable.sol)
- [Multicall.sol](https://github.com/thirdweb-dev/contracts/blob/master/extension/Multicall.sol)
- [ContractMetadata.sol](https://github.com/thirdweb-dev/contracts/blob/master/extension/ContractMetadata.sol)

## Usage
1. Create Tournament:
   - Function: `createTournament(uint _tournamentId, uint8 _tournamentType, address _organizer, uint _registerStartTime, uint _registerEndTime, uint _prizeCount)`
   - Description: Creates a new tournament with the specified parameters.
   - Parameters:
     - `_tournamentId`: The unique identifier for the tournament.
     - `_tournamentType`: The type of the tournament (1 for Total Score Tournament, 2 for Top Score Tournament).
     - `_organizer`: The address of the tournament organizer.
     - `_registerStartTime`: The start time for participant registration.
     - `_registerEndTime`: The end time for participant registration.
     - `_prizeCount`: The number of prizes to be awarded in the tournament.

2. Register:
   - Function: `register(uint tournamentId, address _player)`
   - Description: Registers a participant for the specified tournament.
   - Parameters:
     - `tournamentId`: The unique identifier of the tournament.
     - `_player`: The address of the participant to register.

3. Update Score:
   - Function: `updateScore(uint tournamentId, string calldata _uri)`
   - Description: Updates the score information for the specified tournament.
   - Parameters:
     - `tournamentId`: The unique identifier of the tournament.
     - `_uri`: The URI of the updated score information.

4. End Tournament:
   - Function: `endTournament(uint _tournamentId, address[] calldata _rankers)`
   - Description: Ends the specified tournament and distributes prizes based on the rankings.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.
     - `_rankers`: An array of addresses representing the ranked participants eligible for prizes.

5. Cancel Tournament:
   - Function: `cancelTournament(uint _tournamentId)`
   - Description: Cancels the specified tournament and refunds registration fees to participants.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.

6. Get Tournament Information:
   - Function: `getAllTournamentCount()`, `getOnGoingTournamentsCount()`, `getEndedTournamentsCount()`, `getOnGoingTournaments()`, `getEndedTournaments()`
   - Description: These functions provide information about the tournaments, such as the total count of tournaments, the count of ongoing tournaments, and the list of ongoing and ended tournaments.

7. Get Participant Information:
   - Function: `getPlayerCount(uint _tournamentId)`, `getPlayers(uint _tournamentId)`
   - Description: These functions retrieve information about the participants in a specific tournament, such as the count of participants and the list of participant addresses.

## Events
- `CreateTournament(uint tournamentId)`: Triggered when a new tournament is created.
- `Registered(uint tournamentId, address account)`: Triggered when a participant is registered for a tournament.
- `NewPersonalRecord(uint tournamentId, address account, uint score)`: Triggered when a participant achieves a new personal score record.
- `ScoreUpdated(uint tournamentId, string uri)`: Triggered when the score information is updated for a tournament.
- `TournamentEnded(uint tournamentId)`: Triggered when a tournament is ended.
- `TournamentCanceled(uint tournamentId)`: Triggered when a tournament is canceled.
