# MiracleTournamentEscrow.sol

## Overview
This contract serves as an escrow contract for managing tournament funds and prize distributions. It allows organizers to create tournaments, lock prize and fee tokens, distribute prizes, and handle fee withdrawals.

## Contract Details
- Solidity Version: ^0.8.17
- License: UNLICENSED

## Dependencies
This contract relies on the following external dependencies:
- [Miracle-Tournament-R2.sol](./Miracle-Tournament-R2.sol)
- [@thirdweb-dev/contracts/extension/ContractMetadata.sol](https://github.com/thirdweb-dev/contracts/blob/master/extension/ContractMetadata.sol)

## Usage
1. Connect Tournament Contract:
   - Function: `connectTournament(address payable _miracletournament)`
   - Description: Connects the tournament contract to the escrow contract.
   - Parameters:
     - `_miracletournament`: The address of the tournament contract.

2. Create Tournament Escrow:
   - Function: `createTournamentEscrow(uint _tournamentId, uint8 _tournamentType, address _prizeToken, address _feeToken, uint _prizeAmount, uint _joinFee, uint _registerStartTime, uint _registerEndTime, uint256[] memory _prizeAmountArray, string memory _tournamentURI)`
   - Description: Creates a tournament escrow for the specified tournament.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.
     - `_tournamentType`: The type of the tournament.
     - `_prizeToken`: The address of the token used for the tournament prizes.
     - `_feeToken`: The address of the token used for the registration fees.
     - `_prizeAmount`: The total amount of prize tokens to be locked in the escrow.
     - `_joinFee`: The registration fee amount for each participant.
     - `_registerStartTime`: The start time for participant registration.
     - `_registerEndTime`: The end time for participant registration.
     - `_prizeAmountArray`: An array of individual prize amounts to be distributed.
     - `_tournamentURI`: The URI of the tournament.

3. Register:
   - Function: `register(uint _tournamentId)`
   - Description: Registers the caller as a participant for the specified tournament.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.

4. Unlock Prize Tokens:
   - Function: `unlockPrize(uint _tournamentId, address[] memory _withdrawAddresses)`
   - Description: Unlocks the prize tokens for distribution to the specified addresses.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.
     - `_withdrawAddresses`: An array of addresses to receive the prize tokens.

5. Unlock Registration Fee Tokens:
   - Function: `unlockRegFee(uint _tournamentId)`
   - Description: Unlocks the registration fee tokens after the tournament ends.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.

6. Withdraw Registration Fee:
   - Function: `feeWithdraw(uint _tournamentId)`
   - Description: Allows the organizer to withdraw the accumulated registration fees.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.

7. Withdraw Prize:
   - Function: `prizeWithdraw(uint _tournamentId)`
   - Description: Allows participants to withdraw their individual prize amounts.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.

8. Cancel Prize Withdrawal:
   - Function: `cancelPrizeWithdraw(uint _tournamentId)`
   - Description: Allows the organizer to cancel the prize withdrawal and receive the total prize amount.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.

9. Cancel Registration Fee Withdrawal:
   - Function: `cancelRegFeeWithdraw(uint _tournamentId)`
   - Description: Allows participants to cancel their registration fee withdrawal and receive their fee amount.
   - Parameters:
     - `_tournamentId`: The unique identifier of the tournament.

10. Emergency Withdraw:
    - Function: `emergencyWithdraw(uint _tournamentId)`
    - Description: Allows the contract admin to perform an emergency withdrawal of both prize and fee tokens.
    - Parameters:
      - `_tournamentId`: The unique identifier of the tournament.

11. Set Royalty Address:
    - Function: `setRoyaltyAddress(address _royaltyAddr)`
    - Description: Sets the address for royalty payments.
    - Parameters:
      - `_royaltyAddr`: The address to receive royalty payments.

12. Set Prize Royalty Rate:
    - Function: `setPrizeRoyaltyRate(uint _royaltyRate)`
    - Description: Sets the royalty rate for prize distributions.
    - Parameters:
      - `_royaltyRate`: The royalty rate in percentage.

13. Set Registration Fee Royalty Rate:
    - Function: `setRegfeeRoyaltyRate(uint _royaltyRate)`
    - Description: Sets the royalty rate for registration fee withdrawals.
    - Parameters:
      - `_royaltyRate`: The royalty rate in percentage.

14. Check Available Prize:
    - Function: `availablePrize(uint _tournamentId, address player) external view returns(uint _amount)`
    - Description: Retrieves the available prize amount for a specific participant in a tournament.
    - Parameters:
      - `_tournamentId`: The unique identifier of the tournament.
      - `player`: The address of the participant.

## Events
- `CreateTournament(uint tournamentId)`: Triggered when a tournament escrow is created.
- `LockPrizeToken(uint tournamentId, uint prizeAmount)`: Triggered when prize tokens are locked in the escrow.
- `LockFeeToken(uint tournamentId, uint feeAmount)`: Triggered when registration fee tokens are locked in the escrow.
- `UnlockPrizeToken(uint tournamentId, address[] _withdrawAddresses)`: Triggered when prize tokens are unlocked for distribution.
- `UnlockFeeToken(uint tournamentId, uint feeBalance)`: Triggered when registration fee tokens are unlocked.
- `
