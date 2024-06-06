// SPDX-License-Identifier: MIT
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
// ERC 1155 Governance v1.0
pragma solidity ^0.8.22;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

interface IStakingContract {
    function stakings(address user) external view returns (uint256, uint256, uint256);
}

contract StakingGovernance is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    IStakingContract[] public stakingContracts;
    uint256 public currentRound = 1;
    uint256 public currentStakeReward = 10;
    
    uint256 optionStart = 1;
    uint256 optionEnd = 15;
    
    mapping(uint256 => uint256) public votes; // voteOption => totalPower
    mapping(address => uint256) public voterVotes; // voter => power
    mapping(address => uint256) public voterOptions; // voter => voteOption

    event VoteCasted(uint256 indexed round, address indexed voter, uint256 option, uint256 power);
    event VoteRetracted(uint256 indexed round, address indexed voter, uint256 option, uint256 power);
    event RoundEnded(uint256 round, uint256[] voteTotals);
    event FinalResult(uint256 round, uint256 stakeRewardRate);

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    constructor(string memory _contractURI) {
        deployer = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, 0x9DD6D483bd17ce22b4d1B16c4fdBc0d106d3669d);
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function connectEditionStakings(address[] memory _stakingContractAddresses) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete stakingContracts;
        for (uint i = 0; i < _stakingContractAddresses.length; i++) {
            stakingContracts.push(IStakingContract(_stakingContractAddresses[i]));
        }
    }

    function getVotePower(address user) public view returns (uint256 totalAmount) {
        totalAmount = 0;
        for (uint i = 0; i < stakingContracts.length; i++) {
            (uint256 amount,,) = stakingContracts[i].stakings(user);
            totalAmount += amount;
        }

        // Subtract already used voting power if the user has voted
        totalAmount -= voterVotes[user];

        return totalAmount;
    }

    function vote(uint256 option) public {
        require(option >= optionStart && option <= optionEnd, "Invalid vote option");
        require(voterVotes[msg.sender] == 0, "Already voted");

        uint256 power = getVotePower(msg.sender);
        require(power > 0, "No voting power available");

        votes[option] += power;
        voterVotes[msg.sender] = power;
        voterOptions[msg.sender] = option;

        emit VoteCasted(currentRound, msg.sender, option, power);
    }

    function retractVote() public {
        uint256 option = voterOptions[msg.sender];
        uint256 votedPower = voterVotes[msg.sender];
        require(votedPower > 0, "No vote to retract");

        votes[option] -= votedPower;
        voterVotes[msg.sender] = 0;
        voterOptions[msg.sender] = 0;

        emit VoteRetracted(currentRound, msg.sender, option, votedPower);
    }

    function endRound() external onlyRole(FACTORY_ROLE) {
        uint256[] memory totals = new uint256[](16);
        for (uint256 i = optionStart; i <= optionEnd; i++) {
            totals[i] = votes[i];
            votes[i] = 0; // Reset votes for the next round
        }

        currentRound++;
        emit RoundEnded(currentRound - 1, totals);
    }

    function uploadFinalResult(uint256 stakeRewardRate) external onlyRole(FACTORY_ROLE) {
        currentStakeReward = stakeRewardRate;
        emit FinalResult(currentRound, stakeRewardRate);
    }

    function getCurrentRound() public view returns (uint256 round) {
        return currentRound;
    }

    function getStakeRewardRate() public view returns (uint256 stakeRewardRate) {
        return currentStakeReward * 10;
    }

    function getVoterDetails(address voter) public view returns (uint256 option, uint256 power) {
        return (voterOptions[voter], voterVotes[voter]);
    }

    function getVoteCountForOption(uint256 option) public view returns (uint256) {
        require(option >= optionStart && option <= optionEnd, "Invalid vote option");
        return votes[option];
    }

    function getAllVoteCounts() public view returns (uint256[] memory) {
        uint256[] memory totals = new uint256[](16);
        for (uint256 i = optionStart; i <= optionEnd; i++) {
            totals[i] = votes[i];
        }
        return totals;
    }
}
