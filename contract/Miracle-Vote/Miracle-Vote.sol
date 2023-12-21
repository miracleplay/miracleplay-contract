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

    function vote(uint candidateId, uint ethAmount) public payable {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting is not active");
        require(candidateId < numberOfCandidates, "Invalid candidate");
        // Ethereum 단위의 정수를 실제 토큰 수량으로 변환
        uint256 tokenAmountToTransfer = ethAmount * (10**18);

        // 사용자의 토큰 잔액 확인
        uint256 voterBalance = votingToken.balanceOf(msg.sender);
        require(voterBalance >= tokenAmountToTransfer, "Insufficient token balance");

        // 토큰 이전 및 투표 로직
        require(votingToken.transferFrom(msg.sender, address(this), tokenAmountToTransfer), "Token transfer failed.");
        votes[candidateId] += ethAmount;
    }

    function endVoting() public {
        require(msg.sender == admin, "Only admin can end voting");
        require(!votingEnded, "Voting already ended");
        votingEnded = true;

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

