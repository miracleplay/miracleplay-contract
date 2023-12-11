// SPDX-License-Identifier: MIT

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   Miracleplay Voting with ERC-20 Token v0.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

contract VotingContract is PermissionsEnumerable{
    address public deployer;
    uint256 public startTime;
    uint256 public endTime;
    string public voteContent;
    IERC20 public votingToken;
    uint256 public votingItemCnt;
    mapping(uint256=>uint256) private votes;
    uint256[] private winners;

    event VotingPeriodSet(uint256 startTime, uint256 endTime);
    event VotingItemUpdated(uint256 candidateCount);
    event UserVoted(address indexed user, uint256 _candidate);
    event VotingEnded(uint256[] sortedItemIds);
    event TokensBurned(uint256 amount);

    constructor(address _votingToken, string memory _contentURI, uint256 _startTime, uint256 _endTime, uint256 _votingItemCnt) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setVotingToken(_votingToken);
        _setVotingContent(_contentURI);
        _setVotingPeriod(_startTime, _endTime);
        votingItemCnt = _votingItemCnt;
    }

    // Example of `votingContent` in JSON format:
    // {
    //   "name": "Game of the Year",
    //   "candidates": [
    //     {
    //       "id": 1,
    //       "name": "Game A",
    //       "description": "Game A offers an adventure with an exciting storyline."
    //     },
    //     {
    //       "id": 2,
    //       "name": "Game B",
    //       "description": "Game B boasts innovative gameplay and outstanding graphics."
    //     },
    //     {
    //       "id": 3,
    //       "name": "Game C",
    //       "description": "Game C provides a user-friendly interface and a variety of levels."
    //     }
    //   ]
    // }

    function _setVotingToken(address _votingToken) private onlyRole(DEFAULT_ADMIN_ROLE) {
        votingToken = IERC20(_votingToken);
    }

    function _setVotingContent(string memory _contentURI) private onlyRole(DEFAULT_ADMIN_ROLE) {
        voteContent = _contentURI;
    }

    function _updateVotingContent(string memory _contentURI) private onlyRole(DEFAULT_ADMIN_ROLE) {
        voteContent = _contentURI;
    }

    function _setVotingPeriod(uint256 _startTime, uint256 _endTime) private onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_startTime < _endTime, "Start time must be before end time.");
        startTime = _startTime;
        endTime = _endTime;
        emit VotingPeriodSet(_startTime, _endTime);
    }

    function updateCandidate(uint256 _votingItemCnt, string memory _newContentURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _votingItemCnt = _votingItemCnt;
        _updateVotingContent(_newContentURI);
        emit VotingItemUpdated(_votingItemCnt);
    }

    function vote(uint256 _candidate, uint256 tokenAmountWei) public {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting is not active.");
        require(votes[_candidate] >= 0, "Not a valid candidate.");

        uint256 tokenAmountToTransfer = tokenAmountWei * (10**18);

        require(votingToken.transferFrom(msg.sender, address(this), tokenAmountToTransfer), "Token transfer failed.");

        votes[_candidate] += tokenAmountWei;
        emit UserVoted(msg.sender, _candidate);
    }

    function endVoting() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > endTime, "Voting not ended.");
        _burnTokens();
        _sortWinners();
    }

    function _burnTokens() private {
        uint256 balance = votingToken.balanceOf(address(this));
        require(votingToken.transfer(address(0), balance), "Token burn failed.");
    }

    function _sortWinners() private {
        winners = new uint256[](votingItemCnt);
        for (uint i = 0; i < winners.length; i++) {
            for (uint j = i + 1; j < winners.length; j++) {
                if (votes[winners[j]] > votes[winners[i]]) {
                    (winners[i], winners[j]) = (winners[j], winners[i]);
                }
            }
        }
    }

    function getVoteContent() public view returns (string memory) {
        return voteContent;
    }

    function getWinners() public view returns (uint256[] memory) {
        return winners;
    }

    function getCandidatesCnt() public view returns (uint256) {
        return votingItemCnt;
    }

    function getVoteCount(uint256 _candidateId) public view returns (uint256) {
        return votes[_candidateId];
    }

    function getVoteCountAll() public view returns (uint256[] memory, uint256[] memory) {
        uint256 candidateCount = votingItemCnt;
        uint256[] memory candidateIds = new uint256[](candidateCount);
        uint256[] memory voteCounts = new uint256[](candidateCount);

        for (uint256 i = 1; i < candidateCount; i++) {
            candidateIds[i] = i;
            voteCounts[i] = votes[candidateIds[i]];
        }

        return (candidateIds, voteCounts);
    }
}
