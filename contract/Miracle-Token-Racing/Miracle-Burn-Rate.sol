// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IERC20 (간략화 버전)
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // BPT가 burn 기능을 제공한다고 가정
    function burn(uint256 amount) external;
}

contract BurnRaceProRata {
    IERC20 public BPT; // 소각될 토큰

    address public owner;

    /// @notice 라운드 정보 구조체
    struct Round {
        uint256 roundId;
        uint256 startTime;
        uint256 endTime;
        uint256 totalReward;    // 이 라운드에서 지급될 MPT 총량
        uint256 totalBurned;    // 이 라운드의 총 BPT 소각량
        bool isActive;
        bool isEnded;

        address[] participants;
    }

    /// @notice 사용자별 소각 정보
    struct UserBurnInfo {
        uint256 burnedAmount;   // 소각한 BPT 양
        bool rewardClaimed;     // 보상 수령 여부
    }

    // 라운드ID => (사용자주소 => 소각정보)
    mapping(uint256 => mapping(address => UserBurnInfo)) public userBurnInfo;
    // 라운드ID => 라운드 정보
    mapping(uint256 => Round) public rounds;

    // 라운드 카운터
    uint256 public currentRoundId;

    event RoundStarted(uint256 indexed roundId, uint256 startTime, uint256 endTime, uint256 totalReward);
    event BurnedBPT(uint256 indexed roundId, address indexed user, uint256 amount);
    event RoundEnded(uint256 indexed roundId, uint256 totalBurned);
    event RewardClaimed(uint256 indexed roundId, address indexed user, uint256 rewardAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _BPT) {
        owner = msg.sender;
        BPT = IERC20(_BPT);
    }

    /**
     * @dev 라운드를 시작하며, 보상 풀(MPT)을 이 컨트랙트로 전송받는다
     */
    function startRound(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _totalReward
    )
        external
        payable
        onlyOwner
    {
        require(_endTime > block.timestamp, "Invalid endTime");
        require(_endTime > _startTime, "endTime must be > startTime");
        require(_totalReward > 0, "Reward must be > 0");
        require(msg.value == _totalReward, "Incorrect MPT amount");

        currentRoundId++;

        // 시작 시간이 과거거나 0이면 현재 블록시간으로 교정
        uint256 start = _startTime < block.timestamp ? block.timestamp : _startTime;

        rounds[currentRoundId] = Round({
            roundId: currentRoundId,
            startTime: start,
            endTime: _endTime,
            totalReward: _totalReward,
            totalBurned: 0,
            isActive: true,
            isEnded: false,
            participants: new address[](0)
        });

        emit RoundStarted(currentRoundId, start, _endTime, _totalReward);
    }

    /**
     * @dev 현재 진행 중인 라운드에 BPT 소각 참여
     */
    function burnBPT(uint256 _roundId, uint256 _amount) external {
        Round storage round = rounds[_roundId];
        require(round.isActive, "Round not active");
        require(!round.isEnded, "Round already ended");
        require(block.timestamp >= round.startTime && block.timestamp <= round.endTime, "Not in round duration");
        require(_amount > 0, "Amount must be > 0");

        // 1) BPT를 컨트랙트로 전송
        bool success = BPT.transferFrom(msg.sender, address(this), _amount);
        require(success, "BPT transfer failed");

        // 2) 컨트랙트에서 소각
        BPT.burn(_amount);

        // 3) 기록 갱신
        userBurnInfo[_roundId][msg.sender].burnedAmount += _amount;
        round.totalBurned += _amount;

        // 첫 참여라면 participants 배열에 추가
        if (userBurnInfo[_roundId][msg.sender].burnedAmount == _amount) {
            round.participants.push(msg.sender);
        }

        emit BurnedBPT(_roundId, msg.sender, _amount);
    }

    /**
     * @dev 라운드 종료
     */
    function endRound(uint256 _roundId) external onlyOwner {
        Round storage round = rounds[_roundId];
        require(round.isActive, "Round not active");
        require(!round.isEnded, "Round already ended");
        require(block.timestamp > round.endTime, "Round not finished");

        round.isActive = false;
        round.isEnded = true;

        emit RoundEnded(_roundId, round.totalBurned);
    }

    /**
     * @dev 사용자가 보상을 청구 (프로 레타 비율)
     */
    function claimReward(uint256 _roundId) external {
        Round storage round = rounds[_roundId];
        UserBurnInfo storage userInfo = userBurnInfo[_roundId][msg.sender];

        require(round.isEnded, "Round not ended");
        require(userInfo.burnedAmount > 0, "No burn record");
        require(!userInfo.rewardClaimed, "Already claimed");

        uint256 userBurned = userInfo.burnedAmount;
        uint256 totalBurned = round.totalBurned;

        uint256 rewardAmount = 0;
        if (totalBurned > 0) {
            rewardAmount = (round.totalReward * userBurned) / totalBurned;
        }

        userInfo.rewardClaimed = true;

        if (rewardAmount > 0) {
            (bool success,) = payable(msg.sender).call{value: rewardAmount}("");
            require(success, "MPT transfer failed");
        }

        emit RewardClaimed(_roundId, msg.sender, rewardAmount);
    }

    /**
     * @dev 비상시 남은 MPT를 회수하는 함수
     */
    function withdrawMPT(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be > 0");
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        require(success, "MPT transfer failed");
    }

    // MPT 수신을 위한 receive 함수 추가
    receive() external payable {}

    // -------------------------------------------------------------------------
    //                  "조회용" 함수들 (READ-ONLY)
    // -------------------------------------------------------------------------

    /**
     * @dev 특정 라운드에 참여한 '전체 사용자 수'를 반환
     */
    function getRoundParticipantsCount(uint256 _roundId)
        external
        view
        returns (uint256)
    {
        return rounds[_roundId].participants.length;
    }

    /**
     * @dev 특정 라운드의 participants 배열에서, 인덱스에 해당하는 사용자의 주소를 반환
     */
    function getParticipantByIndex(uint256 _roundId, uint256 _index)
        external
        view
        returns (address)
    {
        Round storage round = rounds[_roundId];
        require(_index < round.participants.length, "Index out of bounds");
        return round.participants[_index];
    }

    // -------------------------------------------------------------------------
    //     새로 추가된: 인덱스를 통해 사용자 정보(주소, 기여도, 예상 보상) 조회
    // -------------------------------------------------------------------------

    /**
     * @dev
     *  - 해당 라운드의 participants[_index]를 찾아서,
     *  - (1) 사용자 주소,
     *  - (2) 기여도(1만 분율 = Basis Points, 1만 = 100%),
     *  - (3) 예상 보상량(MPT)을 반환한다.
     */
    function getParticipantInfoByIndex(uint256 _roundId, uint256 _index)
        external
        view
        returns (
            address participant,
            uint256 contributionBps,  // 기여도(bps, 1만 = 100%)
            uint256 estimatedReward
        )
    {
        Round storage round = rounds[_roundId];
        require(_index < round.participants.length, "Index out of bounds");

        participant = round.participants[_index];

        uint256 userBurned = userBurnInfo[_roundId][participant].burnedAmount;
        uint256 totalBurned = round.totalBurned;

        // 기여도 & 예상 보상 계산
        if (totalBurned == 0) {
            // 아무도 소각 안했으면 기여도, 보상 모두 0
            contributionBps = 0;
            estimatedReward = 0;
        } else {
            // Basis Points(1만 분율)로 계산 → 1만 = 100%
            // ex) userBurned=200, totalBurned=1000 => contributionBps=200*10000/1000=2000(bps)=20.00%
            contributionBps = (userBurned * 10000) / totalBurned;

            // 라운드가 종료되었든 아니든, "지금까지"의 비율로 환산한 보상
            estimatedReward = (round.totalReward * userBurned) / totalBurned;
        }
    }

    /**
     * @dev
     *  - 주소를 이용하여 해당 라운드의 참여자 정보를 조회
     *  - (1) 사용자의 소각량,
     *  - (2) 기여도(1만 분율 = Basis Points, 1만 = 100%),
     *  - (3) 예상 보상량(MPT),
     *  - (4) 보상 수령 여부를 반환한다.
     */
    function getParticipantInfoByAddress(uint256 _roundId, address _participant)
        external
        view
        returns (
            uint256 burnedAmount,     // 사용자의 소각량
            uint256 contributionBps,  // 기여도(bps, 1만 = 100%)
            uint256 estimatedReward,  // 예상 보상
            bool rewardClaimed        // 보상 수령 여부
        )
    {
        Round storage round = rounds[_roundId];
        UserBurnInfo storage userInfo = userBurnInfo[_roundId][_participant];

        burnedAmount = userInfo.burnedAmount;
        rewardClaimed = userInfo.rewardClaimed;

        uint256 totalBurned = round.totalBurned;

        // 기여도 & 예상 보상 계산
        if (totalBurned == 0 || burnedAmount == 0) {
            // 아무도 소각 안했거나 해당 사용자가 소각하지 않았으면 기여도, 보상 모두 0
            contributionBps = 0;
            estimatedReward = 0;
        } else {
            // Basis Points(1만 분율)로 계산 → 1만 = 100%
            contributionBps = (burnedAmount * 10000) / totalBurned;

            // 라운드가 종료되었든 아니든, "지금까지"의 비율로 환산한 보상
            estimatedReward = (round.totalReward * burnedAmount) / totalBurned;
        }
    }
}
