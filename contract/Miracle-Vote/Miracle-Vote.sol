// SPDX-License-Identifier: MIT

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   Miracleplay Voting with ERC-20 Token

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
    address[] private candidateList;
    mapping(address => uint256) private votes;
    address[] private winners;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setVotingToken(address _votingToken) public onlyRole(DEFAULT_ADMIN_ROLE) {
        votingToken = IERC20(_votingToken);
    }

    function setVotingContent(string memory _contentURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        voteContent = _contentURI;
    }

    function setVotingPeriod(uint256 _startTime, uint256 _endTime) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_startTime < _endTime, "Start time must be before end time.");
        startTime = _startTime;
        endTime = _endTime;
    }

    function registerCandidate(address _candidate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        candidateList.push(_candidate);
        votes[_candidate] = 0;
    }

    function vote(address _candidate) public {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting is not active.");
        require(votes[_candidate] >= 0, "Not a valid candidate.");
        require(votingToken.transferFrom(msg.sender, address(this), 1), "Token transfer failed.");

        votes[_candidate] += 1;
    }

    function endVoting() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > endTime, "Voting not ended.");
        _burnTokens();
        _sortWinners();
    }


    function resetVoting() public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.timestamp > endTime, "Voting is still in progress.");

        for (uint i = 0; i < candidateList.length; i++) {
            delete votes[candidateList[i]];
        }
        delete candidateList;
        delete winners;
        startTime = 0;
        endTime = 0;
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

    function getVoteContent() public view returns (string memory) {
        return voteContent;
    }

    function getWinners() public view returns (address[] memory) {
        return winners;
    }

    function getCandidates() public view returns (address[] memory) {
        return candidateList;
    }

    function getVoteCount(address _candidate) public view returns (uint256) {
        return votes[_candidate];
    }

    function getVoteCountAll() public view returns (address[] memory, uint[] memory) {
        address[] memory _candidateList = getCandidates();
        uint[] memory _voteCount = new uint[](_candidateList.length);
        for (uint i = 0; i < _candidateList.length; i++) {
            _voteCount[i] = getVoteCount(_candidateList[i]);
        }
        return (_candidateList, _voteCount);
    }
}
