pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VotingContract {
    address public owner;
    uint256 public startTime;
    uint256 public endTime;
    IERC20 public votingToken;
    address[] private candidateList;
    mapping(address => uint256) private votes;
    address[] private winners;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    constructor(address _votingToken) {
        owner = msg.sender;
        votingToken = IERC20(_votingToken);
    }

    function setVotingPeriod(uint256 _startTime, uint256 _endTime) public onlyOwner {
        require(_startTime < _endTime, "Start time must be before end time.");
        startTime = _startTime;
        endTime = _endTime;
    }

    function registerCandidate(address _candidate) public onlyOwner {
        candidateList.push(_candidate);
        votes[_candidate] = 0;
    }

    function getCandidates() public view returns (address[] memory) {
        return candidateList;
    }

    function vote(address _candidate) public {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting is not active.");
        require(votes[_candidate] >= 0, "Not a valid candidate.");
        require(votingToken.transferFrom(msg.sender, address(this), 1), "Token transfer failed.");

        votes[_candidate] += 1;
    }

    function endVoting() public onlyOwner {
        require(block.timestamp > endTime, "Voting not ended.");
        _burnTokens();
        _sortWinners();
    }

    function _burnTokens() private {
        uint256 balance = votingToken.balanceOf(address(this));
        require(votingToken.transfer(address(0), balance), "Token burn failed.");
    }

    function _sortWinners() private {
        winners = new address[](candidateList.length);
        for (uint i = 0; i < candidateList.length; i++) {
            winners[i] = candidateList[i];
        }

        for (uint i = 0; i < winners.length; i++) {
            for (uint j = i + 1; j < winners.length; j++) {
                if (votes[winners[j]] > votes[winners[i]]) {
                    (winners[i], winners[j]) = (winners[j], winners[i]);
                }
            }
        }
    }

    function getWinners() public view returns (address[] memory) {
        return winners;
    }

    function resetVoting() public onlyOwner {
        require(block.timestamp > endTime, "Voting is still in progress.");

        for (uint i = 0; i < candidateList.length; i++) {
            delete votes[candidateList[i]];
        }
        delete candidateList;
        delete winners;
        startTime = 0;
        endTime = 0;
    }
}
