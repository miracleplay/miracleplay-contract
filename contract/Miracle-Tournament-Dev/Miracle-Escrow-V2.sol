// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Tournament {
    address public deployer;
    address public organizer;
    bool public isTournamentActive;
    IERC20 public entryFeeToken; // 참가비로 사용될 ERC-20 토큰
    uint256 public entryFeeAmount; // 참가비 금액
    mapping(address => bool) public users; // 참가자 
    address[] public usersList; // 참가자 주소 목록
    uint256 public startTime;
    uint256 public endTime;
    
    // 순위별 수상자의 주소를 저장하기 위한 배열
    address[] public winners;

    // ERC20, ERC721, ERC1155 tokens for prizes
    IERC20 public erc20Prize;
    IERC721 public erc721Prize;
    IERC1155 public erc1155Prize;

    // Contract status
    enum TournamentState {
        Created,
        EscrowCompleted,
        Finished,
        Cancelled
    }
    TournamentState public state;

    constructor(address _organizer, uint256 _startTime, uint256 _endTime, address _entryFeeToken, uint256 _entryFeeAmount) {
        require(_startTime < _endTime, "Start time must be before end time");
        require(_startTime > block.timestamp, "Start time must be in the future");
        deployer = msg.sender;
        organizer = _organizer;
        isTournamentActive = true;
        startTime = _startTime;
        endTime = _endTime;
        state = TournamentState.Created;
        entryFeeToken = IERC20(_entryFeeToken);
        entryFeeAmount = _entryFeeAmount;
    }

    // 참가 신청 함수
    function enterTournament() external {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Tournament registration is not open");
        require(!users[msg.sender], "User already registered");

        if (entryFeeAmount > 0) {
            // 참가비 전송이 성공적으로 이루어졌는지 확인
            require(entryFeeToken.transferFrom(msg.sender, address(this), entryFeeAmount), "Failed to transfer entry fee");
        }

        if (!users[msg.sender]) {
            users[msg.sender] = true;
            usersList.push(msg.sender); // 참가자 목록에 추가
        }
    }

    // 에스크로 완료 상태로 변경
    function completeEscrow() external {
        require(state == TournamentState.Created, "Tournament is not in the created state");
        // 에스크로 로직 추가
        state = TournamentState.EscrowCompleted;
    }

    //Prize ERC-20 Token
    uint256[] public erc20PrizesByRank;

    function depositERC20Prize(address _tokenAddress, uint256[] memory amounts) external {
        require(msg.sender == organizer, "Only organizer can deposit prizes");
        erc20Prize = IERC20(_tokenAddress);

        uint256 totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        erc20Prize.transferFrom(msg.sender, address(this), totalAmount);
    }

    //Prize ERC-721 NFT
    struct ERC721Prize {
        address tokenAddress;
        uint256 tokenId;
    }

    ERC721Prize[] public prizesByRankNFT;

    // ERC-721 상금 예치
    function depositERC721Prize(uint256 _rank, address _tokenAddress, uint256 _tokenId) external {
        require(msg.sender == organizer, "Only organizer can deposit prizes");
        
        // 배열의 길이를 확인하고 필요한 경우 확장
        if (_rank >= prizesByRankNFT.length) {
            expandPrizesByRankNFTArray(_rank + 1);
        }

        require(prizesByRankNFT[_rank].tokenAddress == address(0), "Prize already set for this rank");

        IERC721 erc721Token = IERC721(_tokenAddress);
        erc721Token.transferFrom(msg.sender, address(this), _tokenId);

        prizesByRankNFT[_rank] = ERC721Prize({
            tokenAddress: _tokenAddress,
            tokenId: _tokenId
        });
    }

    // 배열 확장을 위한 내부 함수
    function expandPrizesByRankNFTArray(uint256 newSize) private {
        while (prizesByRankNFT.length < newSize) {
            prizesByRankNFT.push(ERC721Prize({
                tokenAddress: address(0),
                tokenId: 0
            }));
        }
    }


    //Prize ERC-1155 Editions
    struct ERC1155Prize {
        address tokenAddress;
        uint256 tokenId;
        uint256 amount;
    }

    ERC1155Prize[] public prizesByRankEditions;

    // ERC-1155 토큰 예치
    function depositERC1155Prize(uint256 _rank, address _tokenAddress, uint256 _tokenId, uint256 _amount) external {
        require(msg.sender == organizer, "Only organizer can deposit prizes");

        // 배열의 길이를 확인하고 필요한 경우 확장
        if (_rank >= prizesByRankEditions.length) {
            expandPrizesByRankEditionsArray(_rank + 1);
        }

        require(prizesByRankEditions[_rank].tokenAddress == address(0), "Prize already set for this rank");

        IERC1155 erc1155Token = IERC1155(_tokenAddress);
        erc1155Token.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");

        prizesByRankEditions[_rank] = ERC1155Prize({
            tokenAddress: _tokenAddress,
            tokenId: _tokenId,
            amount: _amount
        });
    }

    // 배열 확장을 위한 내부 함수
    function expandPrizesByRankEditionsArray(uint256 newSize) private {
        while (prizesByRankEditions.length < newSize) {
            prizesByRankEditions.push(ERC1155Prize({
                tokenAddress: address(0),
                tokenId: 0,
                amount: 0
            }));
        }
    }

    // 토너먼트 취소 상태로 변경
    function cancelTournament() external {
        require(msg.sender == deployer, "Only deploy wallet can cancel the tournament");
        require(state != TournamentState.Cancelled, "Tournament is already cancelled");

        refundEntryFees(); // 참가비 반환
        refundPrizes(); // 상금 반환

        state = TournamentState.Cancelled; // 상태 변경
    }

    // 토너먼트 종료 및 상금 분배
    function finishTournament(address[] calldata _winners) external {
        require(msg.sender == deployer, "Only deploy wallet can finish the tournament");
        require(state == TournamentState.EscrowCompleted, "Tournament is not in the correct state to finish");
        
        uint256 winnersCount = _winners.length;

        // ERC-20 상금 분배
        for (uint i = 0; i < winnersCount; i++) {
            if (i < erc20PrizesByRank.length && erc20PrizesByRank[i] > 0) {
                erc20Prize.transfer(_winners[i], erc20PrizesByRank[i]);
            }
        }

        // ERC-721 상금 분배
        for (uint i = 0; i < winnersCount; i++) {
            if (i < prizesByRankNFT.length && prizesByRankNFT[i].tokenAddress != address(0)) {
                IERC721(prizesByRankNFT[i].tokenAddress).transferFrom(address(this), _winners[i], prizesByRankNFT[i].tokenId);
            }
        }

        // ERC-1155 상금 분배
        for (uint i = 0; i < winnersCount; i++) {
            if (i < prizesByRankEditions.length && prizesByRankEditions[i].tokenAddress != address(0)) {
                IERC1155(prizesByRankEditions[i].tokenAddress).safeTransferFrom(address(this), _winners[i], prizesByRankEditions[i].tokenId, prizesByRankEditions[i].amount, "");
            }
        }

        state = TournamentState.Finished; // 상태 변경
    }

    // 참가비 반환 함수
    function refundEntryFees() private {
        for (uint256 i = 0; i < usersList.length; i++) {
            if (entryFeeAmount > 0 && users[usersList[i]]) {
                entryFeeToken.transfer(usersList[i], entryFeeAmount);
            }
        }
    }

    // 상금 반환 함수 (ERC-20, ERC-721, ERC-1155)
    function refundPrizes() private {
        // ERC-20 상금 반환
        if (address(erc20Prize) != address(0)) {
            uint256 balance = erc20Prize.balanceOf(address(this));
            erc20Prize.transfer(organizer, balance);
        }

        // ERC-721 상금 반환
        for (uint256 i = 0; i < prizesByRankNFT.length; i++) {
            if (prizesByRankNFT[i].tokenAddress != address(0)) {
                IERC721 nftToken = IERC721(prizesByRankNFT[i].tokenAddress);
                nftToken.safeTransferFrom(address(this), organizer, prizesByRankNFT[i].tokenId);
            }
        }

        // ERC-1155 상금 반환
        for (uint256 j = 0; j < prizesByRankEditions.length; j++) {
            if (prizesByRankEditions[j].tokenAddress != address(0)) {
                IERC1155 editionsToken = IERC1155(prizesByRankEditions[j].tokenAddress);
                editionsToken.safeTransferFrom(address(this), organizer, prizesByRankEditions[j].tokenId, prizesByRankEditions[j].amount, "");
            }
        }
    }

    // 참가자 수를 반환하는 함수
    function getParticipantCount() public view returns (uint256) {
        return usersList.length;
    }
}
