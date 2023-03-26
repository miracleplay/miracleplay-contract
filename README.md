# Sevenline-Games-Contract

## 1. Miracle Staking
Miracle Staking is a smart contract platform that allows users to stake their ERC-1155 NFTs in order to earn rewards in a ERC-20 token. The platform also allows for agent rewards and DAO royalties.
### Overview
The Miracle Staking platform consists of several contracts that work together to allow for staking and reward distribution. The main contracts are:
- `SLG-Miracle-Stake.sol`: This is the main staking contract, which allows users to stake their NFTs and earn rewards.
- `TokenERC20.sol`: This is the ERC-20 token contract that is used for rewards.
- `DropERC1155.sol`: This is the ERC-1155 NFT contract that is used for staking.
### Usage
To use the Miracle Staking platform, you will need to follow these steps:
1. Stake your ERC-1155 NFTs: First, you will need to stake your ERC-1155 NFTs in the staking contract. This can be done by calling the `_stake()` function in the `SLG-Miracle-Stake.sol` contract.
2. Earn rewards: Once you have staked your NFTs, you will begin earning rewards in the form of the ERC-20 token. You can claim these rewards by calling the `_claim()` function in the `SLG-Miracle-Stake.sol` contract.
3. Withdraw your NFTs: If you want to withdraw your NFTs, you can do so by calling the `_withdraw()` function in the `SLG-Miracle-Stake.sol` contract.
### Contract Architecture
The Miracle Staking platform consists of several contracts that work together to allow for staking and reward distribution. The main contracts are:
- `Miralce-Stake-Core.sol`: This is the main staking contract, which allows users to stake their NFTs and earn rewards.
- `TokenERC20.sol`: This is the ERC-20 token contract that is used for rewards.
- `DropERC1155.sol`: This is the ERC-1155 NFT contract that is used for staking.
## 2. SLG Token Staking
## 3. Miracle Tounermant
Miracle Tournament is a smart contract platform that allows users to participate in tournaments and compete for prizes. The platform uses a single-elimination format, and allows for multiple rounds of play.
### Overview
The Miracle Tournament platform consists of several contracts that work together to allow for tournament creation, match reporting, and reward distribution. The main contracts are:
- `Tournament.sol` This is the main tournament contract, which allows players to register for the tournament, create matches, report match winners, and advance to the next round.
### Usage
To use the Miracle Tournament platform, you will need to follow these steps:
1. Register as a player: To participate in the tournament, you will need to register as a player by calling the `registerPlayer()` function in the Tournament.sol contract.
2. Create matches: Once there are at least two registered players, the organizer can create matches by calling the `createMatches()` function in the Tournament.sol contract.
3. Report match winners: After a match has been played, the organizer can report the winner by calling the `reportWinner()` function in the Tournament.sol contract.
4. Advance to the next round: Once all matches in a round have been played, the organizer can advance to the next round by calling the `advanceToNextRound()` function in the Tournament.sol contract.
5. View tournament information: To view information about players, matches, and rounds, you can call the `getPlayerById()`, `getMatchById()`, and `getRoundById()` functions in the Tournament.sol contract.
6. Withdraw winnings: After the tournament has ended, the winner can withdraw their winnings by calling the `withdraw()` function in the `Tournament.sol` contract.
### Contract Architecture
The Miracle Tournament platform consists of several contracts that work together to allow for tournament creation, match reporting, and reward distribution. The main contracts are:
- `Tournament.sol`: This is the main tournament contract, which allows players to register for the tournament, create matches, report match winners, and advance to the next round.
## License

Copyright 2023 Sevenline Labs - [Sevenline Labs License](https://www.sevenlinelabs.com)
