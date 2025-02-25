// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title IERC20
 * @dev ERC20 표준 인터페이스 (간단화 버전).
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // BPT에 burn 기능이 있다고 가정 (혹은 소각 주소로 전송하는 방식 사용)
    function burn(uint256 amount) external;
}

/**
 * @title BurnRace
 * @notice
 *  - 매 라운드마다 사용자들이 BPT를 소각하여 경쟁.
 *  - 라운드 시작 시 오너가 보상 풀(MPT)을 이 컨트랙트에 전송.
 *  - 라운드 종료 시 상위권 사용자들이 `claimReward()`로 MPT를 수령.
 *  - 데모용 예시 코드로, 실제 서비스 적용 전 보안 감사 및 가스 최적화 필요.
 */
contract BurnRaceRanked {

    // 소각 및 보상을 위한 ERC20 토큰들
    IERC20 public BPT; // 소각할 토큰
    IERC20 public MPT; // 보상으로 지급할 토큰

    address public owner;

    /// @dev 라운드 정보 구조체
    struct Round {
        uint256 roundId;        // 라운드 ID
        uint256 startTime;      // 라운드 시작 시간 (timestamp)
        uint256 endTime;        // 라운드 종료 시간 (timestamp)
        uint256 totalReward;    // 이 라운드에서 지급될 MPT 보상 풀
        uint256 totalBurned;    // 이 라운드 전체 소각된 BPT 총량
        bool isActive;          // 라운드가 진행 중인지 여부
        bool isEnded;           // 라운드가 종료되었는지 여부

        address[] participants; // 참가 주소 목록 (온체인 정렬 시 가스비 주의)
        address[] winners;      // 라운드 종료 후 상위 보상 대상
    }

    /// @dev 사용자별 라운드 참여 정보
    struct UserBurnInfo {
        uint256 burnedAmount;   // 해당 라운드에서 소각한 BPT 양
        bool rewardClaimed;     // 보상을 이미 수령했는지 여부
    }

    /// @notice 라운드ID => (사용자 주소 => 참여 정보)
    mapping(uint256 => mapping(address => UserBurnInfo)) public userBurnInfo;
    /// @notice 라운드ID => 라운드 정보
    mapping(uint256 => Round) public rounds;

    // 현재까지 생성된 라운드의 수
    uint256 public currentRoundId;

    // 라운드별 상위 몇 명에게 보상을 줄지 설정 (데모: Top 3)
    uint256 public constant TOP_RANK = 3;

    // Top 3에게 보상 분배 (예: 1등 40%, 2등 25%, 3등 15%)
    // 나머지 20%는 여기서 예시상으로는 분배하지 않지만, 필요하면 확장 가능
    uint256[] public rewardDistribution = [40, 25, 15]; // %

    // 이벤트 정의
    event RoundStarted(
        uint256 indexed roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 totalReward
    );
    event BurnedBPT(
        uint256 indexed roundId,
        address indexed user,
        uint256 amount
    );
    event RoundEnded(
        uint256 indexed roundId,
        uint256 totalBurned
    );
    event RewardClaimed(
        uint256 indexed roundId,
        address indexed user,
        uint256 rewardAmount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _BPT, address _MPT) {
        owner = msg.sender;
        BPT = IERC20(_BPT);
        MPT = IERC20(_MPT);
    }

    /**
     * @dev 새로운 라운드를 시작하며, 보상 풀로 쓸 MPT를 컨트랙트에 전송합니다.
     * @param _startTime 라운드 시작 시간 (0 또는 현재시간 이상)
     * @param _endTime 라운드 종료 시간 (시작 시간보다 커야 함)
     * @param _totalReward 이 라운드에서 지급할 MPT 토큰 총량
     * 
     * 요구사항:
     *  - 오너가 반드시 이 컨트랙트에 대해 MPT allowance(_totalReward 이상)를 설정해야 합니다.
     *  - 성공 시, MPT.transferFrom(owner -> this contract, _totalReward) 실행
     */
    function startRound(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _totalReward
    )
        external
        onlyOwner
    {
        require(_endTime > block.timestamp, "Invalid endTime");
        require(_endTime > _startTime, "endTime must be > startTime");
        require(_totalReward > 0, "Reward must be > 0");

        // 오너가 컨트랙트에 MPT를 전송
        bool success = MPT.transferFrom(msg.sender, address(this), _totalReward);
        require(success, "MPT transferFrom failed");

        currentRoundId++;

        // _startTime이 0이거나 현재시간 이전이면, block.timestamp로 대체
        uint256 start = _startTime < block.timestamp ? block.timestamp : _startTime;

        rounds[currentRoundId] = Round({
            roundId: currentRoundId,
            startTime: start,
            endTime: _endTime,
            totalReward: _totalReward,
            totalBurned: 0,
            isActive: true,
            isEnded: false,
            participants: new address[](0),
            winners: new address[](0)
        });

        emit RoundStarted(currentRoundId, start, _endTime, _totalReward);
    }

    /**
     * @dev 현재 진행 중인 라운드에 BPT를 소각하여 참여.
     * @param _roundId 참여할 라운드 ID
     * @param _amount 소각할 BPT 수량
     */
    function burnBPT(uint256 _roundId, uint256 _amount) external {
        Round storage round = rounds[_roundId];
        require(round.isActive, "Round not active");
        require(!round.isEnded, "Round already ended");
        require(
            block.timestamp >= round.startTime && block.timestamp <= round.endTime,
            "Not in round duration"
        );
        require(_amount > 0, "Amount must be > 0");

        // 사용자 -> 컨트랙트로 BPT 전송
        bool success = BPT.transferFrom(msg.sender, address(this), _amount);
        require(success, "BPT transfer failed");

        // BPT 소각 (BPT에 burn 함수가 있다고 가정)
        BPT.burn(_amount);

        // 라운드 및 사용자 정보 갱신
        userBurnInfo[_roundId][msg.sender].burnedAmount += _amount;
        round.totalBurned += _amount;

        // participants 배열에 중복 없이 추가 (단순 예시)
        // 최초 참여 시 burnedAmount가 이번 트랜잭션 amount와 동일
        if (userBurnInfo[_roundId][msg.sender].burnedAmount == _amount) {
            round.participants.push(msg.sender);
        }

        emit BurnedBPT(_roundId, msg.sender, _amount);
    }

    /**
     * @dev 라운드 종료 처리 (온체인에서 간단 정렬 예시).
     *  - 실제로는 가스 비용이 크므로 오프체인 계산 + Merkle Proof 등 권장
     * @param _roundId 종료할 라운드 ID
     */
    function endRound(uint256 _roundId) external onlyOwner {
        Round storage round = rounds[_roundId];
        require(round.isActive, "Round not active");
        require(!round.isEnded, "Round already ended");
        require(block.timestamp > round.endTime, "Round not finished");

        round.isActive = false;
        round.isEnded = true;

        // 간단 온체인 정렬 (Insertion Sort), 참가자가 많으면 가스 폭탄
        address[] storage parts = round.participants;
        uint256 length = parts.length;

        for (uint256 i = 1; i < length; i++) {
            address key = parts[i];
            uint256 j = i - 1;

            uint256 keyBurn = userBurnInfo[_roundId][key].burnedAmount;
            
            // 내림차순 정렬(큰 소각량이 앞으로)
            while (
                (j >= 0) &&
                userBurnInfo[_roundId][parts[j]].burnedAmount < keyBurn
            ) {
                parts[j + 1] = parts[j];
                if (j == 0) {
                    break;
                }
                j--;
            }
            parts[j + 1] = key;
        }

        // 상위 TOP_RANK 추출
        uint256 rankCount = (length < TOP_RANK) ? length : TOP_RANK;
        address[] memory topWinners = new address[](rankCount);

        for (uint256 i = 0; i < rankCount; i++) {
            topWinners[i] = parts[i];
        }

        // winners 배열에 기록
        for (uint256 i = 0; i < rankCount; i++) {
            round.winners.push(topWinners[i]);
        }

        emit RoundEnded(_roundId, round.totalBurned);
    }

    /**
     * @dev 라운드 보상(MPT) 수령
     *  - endRound 이후에만 가능
     *  - 순위에 따라 차등 지급 (데모: Top 3에 대해 rewardDistribution 비율로 지급)
     * @param _roundId 보상을 청구할 라운드 ID
     */
    function claimReward(uint256 _roundId) external {
        Round storage round = rounds[_roundId];
        UserBurnInfo storage userInfo = userBurnInfo[_roundId][msg.sender];

        require(round.isEnded, "Round not ended");
        require(userInfo.burnedAmount > 0, "No burn record");
        require(!userInfo.rewardClaimed, "Already claimed");

        // 보상 대상인지(winners에 포함되는지) 확인
        bool isWinner = false;
        uint256 rankIndex = 0;

        for (uint256 i = 0; i < round.winners.length; i++) {
            if (round.winners[i] == msg.sender) {
                isWinner = true;
                rankIndex = i; // 0 -> 1등, 1 -> 2등, 2 -> 3등
                break;
            }
        }

        uint256 rewardAmount = 0;
        if (isWinner && rankIndex < rewardDistribution.length) {
            // 예) 1등: 40% = rewardDistribution[0]
            uint256 percentage = rewardDistribution[rankIndex];
            rewardAmount = round.totalReward * percentage / 100;
        } else {
            // 상위에 들지 못했다면 (이 예시에서는 추가 보상 X)
            rewardAmount = 0;
        }

        userInfo.rewardClaimed = true;

        if (rewardAmount > 0) {
            bool success = MPT.transfer(msg.sender, rewardAmount);
            require(success, "MPT transfer failed");
        }

        emit RewardClaimed(_roundId, msg.sender, rewardAmount);
    }

    /** 
     * @dev 비상시 오너가 MPT를 회수할 수 있는 함수 (프로젝트 정책에 따라 삭제 또는 제한 가능)
     */
    function withdrawMPT(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be > 0");
        bool success = MPT.transfer(msg.sender, _amount);
        require(success, "MPT transfer failed");
    }

    function getUserRank(uint256 _roundId, address _user) 
        external 
        view 
        returns (uint256) 
    {
        Round storage round = rounds[_roundId];
        uint256 userBurned = userBurnInfo[_roundId][_user].burnedAmount;
        if (userBurned == 0) {
            // 소각 이력이 없다면 순위를 매길 필요가 없음 (0으로 반환하거나 별도 처리)
            return 0; 
        }

        uint256 rank = 1; 
        // 모든 참가자 순회
        for (uint256 i = 0; i < round.participants.length; i++) {
            address p = round.participants[i];
            // 만약 p 사용자의 소각량이 나보다 많으면, 내 순위는 1 더 뒤로 밀린다
            if (userBurnInfo[_roundId][p].burnedAmount > userBurned) {
                rank++;
            }
        }
        return rank;
    }

    /** ----- 유틸 함수 예시 ----- */

    function getRoundParticipantsCount(uint256 _roundId) external view returns (uint256) {
        return rounds[_roundId].participants.length;
    }

    function getRoundWinners(uint256 _roundId) external view returns (address[] memory) {
        return rounds[_roundId].winners;
    }
}
