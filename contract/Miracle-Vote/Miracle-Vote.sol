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

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract VotingTournament {
    uint public votingId;
    address public admin;
    ERC20Burnable public votingToken;
    uint public startTime;
    uint public endTime;
    uint public numberOfCandidates;
    mapping(uint => uint) public votes;
    uint[] public sortedVoteCounts;
    bool public votingEnded = false;

    constructor(
        uint _votingId,
        address _admin,
        address _tokenAddress,
        uint _startTime,
        uint _endTime,
        uint _numberOfCandidates
    ) {
        votingId = _votingId;
        admin = _admin;
        votingToken = ERC20Burnable(_tokenAddress);
        startTime = _startTime;
        endTime = _endTime;
        numberOfCandidates = _numberOfCandidates;
    }

    function vote(uint candidateId, uint amount) public {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting is not active");
        require(candidateId < numberOfCandidates, "Invalid candidate");
        votingToken.transferFrom(msg.sender, address(this), amount);
        votes[candidateId] += amount;
    }

    function endVoting() public {
        require(msg.sender == admin, "Only admin can end voting");
        require(!votingEnded, "Voting already ended");
        votingEnded = true;

        // 득표 수를 저장할 배열 초기화
        uint[] memory voteCounts = new uint[](numberOfCandidates);

        // 맵핑에서 득표 수를 배열로 복사
        for (uint i = 0; i < numberOfCandidates; i++) {
            voteCounts[i] = votes[i];
        }

        // 버블 정렬로 득표 수 정렬
        for (uint i = 0; i < voteCounts.length; i++) {
            for (uint j = 0; j < voteCounts.length - i - 1; j++) {
                if (voteCounts[j] < voteCounts[j + 1]) {
                    uint temp = voteCounts[j];
                    voteCounts[j] = voteCounts[j + 1];
                    voteCounts[j + 1] = temp;
                }
            }
        }

        // 정렬된 득표 수를 저장
        sortedVoteCounts = voteCounts;

        // 컨트랙트가 보유한 토큰의 총량을 확인
        uint256 balance = votingToken.balanceOf(address(this));

        // 확인된 토큰의 총량을 소각
        votingToken.burn(balance);
    }

    function getVoteCounts() public view returns (uint[] memory) {
        uint[] memory voteCounts = new uint[](numberOfCandidates);

        for (uint i = 0; i < numberOfCandidates; i++) {
            voteCounts[i] = votes[i];
        }

        return voteCounts;
    }
}

