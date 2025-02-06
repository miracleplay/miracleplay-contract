// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

/// @notice 단순 ERC20 인터페이스 정의 (필요한 함수만 포함)
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MultiSigERC20Withdrawal is ContractMetadata, Multicall 
{
    /* ========== STATE VARIABLES ========== */
    address public deployer;

    // ERC20 토큰 주소 (배포 시 설정)
    IERC20 public token;

    // 관리자와 출금 권한을 관리하는 매핑
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isWithdrawalWallet;

    // 이미 출금이 처리된 체인ID와 트랜잭션 해시 조합의 기록 (일반 출금용)
    mapping(bytes32 => bool) public processedWithdrawal;

    // 일반 출금 일시정지 여부 (true이면 일시정지)
    bool public withdrawalPaused;

    // 관리자가 요청한 출금(멀티시그) 건에 대한 구조체
    struct AdminWithdrawalRequest {
        address to;
        uint256 amount;
        uint256 approvalCount;
        bool executed;
        // 각 관리자가 승인했는지 여부
        mapping(address => bool) approvedBy;
    }
    // 요청ID를 증가시키기 위한 카운터
    uint256 public adminWithdrawalRequestCount;
    // 요청ID => AdminWithdrawalRequest
    mapping(uint256 => AdminWithdrawalRequest) private adminWithdrawalRequests;

    /* ========== EVENTS ========== */
    // 일반 출금 이벤트: chainId와 txHash는 중복 출금 방지를 위한 용도
    event Withdrawal(
        address indexed executor,
        address indexed to,
        uint256 amount,
        uint256 chainId,
        bytes32 txHash
    );
    // 관리자 출금 요청 이벤트 (체인ID, txHash 제거됨)
    event AdminWithdrawalRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint256 amount,
        address to
    );
    event AdminWithdrawalApproved(
        uint256 indexed requestId,
        address indexed approver,
        uint256 approvalCount
    );
    event AdminWithdrawalExecuted(uint256 indexed requestId, address indexed executor);
    event AdminUpdated(address indexed admin, bool status);
    event WithdrawalWalletUpdated(address indexed wallet, bool status);
    
    // 일반 출금 일시정지/해제 이벤트
    event WithdrawalPaused(address indexed admin);
    event WithdrawalUnpaused(address indexed admin);

    /* ========== MODIFIERS ========== */
    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Only admin can call");
        _;
    }

    modifier onlyWithdrawalWallet() {
        require(isWithdrawalWallet[msg.sender], "Only withdrawal wallet can call");
        _;
    }

    modifier whenNotPaused() {
        require(!withdrawalPaused, "General withdrawals are paused");
        _;
    }

    /* ========== CONSTRUCTOR ========== */
    /**
     * @notice 생성자
     * @param _token ERC20 토큰 컨트랙트 주소
     * @param initialAdmins 초기 관리자 주소 배열 (최소 1개)
     * @param initialWithdrawalWallets 초기 출금권한 지갑 주소 배열 (최소 1개)
     */
    constructor(
        IERC20 _token,
        address _deployer,
        address[] memory initialAdmins,
        address[] memory initialWithdrawalWallets,
        string memory _contractURI
    ) {
        token = _token;
        deployer = _deployer;
        
        // 초기 관리자 설정
        require(initialAdmins.length > 0, "At least one admin required");
        for (uint256 i = 0; i < initialAdmins.length; i++) {
            isAdmin[initialAdmins[i]] = true;
            emit AdminUpdated(initialAdmins[i], true);
        }
        // 초기 출금권한 지갑 설정
        require(initialWithdrawalWallets.length > 0, "At least one withdrawal wallet required");
        for (uint256 i = 0; i < initialWithdrawalWallets.length; i++) {
            isWithdrawalWallet[initialWithdrawalWallets[i]] = true;
            emit WithdrawalWalletUpdated(initialWithdrawalWallets[i], true);
        }

        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    /* ========== FUNCTIONALITY ========== */

    /**
     * @notice 일반 출금 함수 (출금 권한이 있는 지갑 전용)
     *         동일한 (chainId, txHash) 조합의 출금은 단 한 번만 처리됩니다.
     *         일시정지 상태일 경우 출금이 실행되지 않습니다.
     * @param chainId 체인 식별자
     * @param txHash 트랜잭션 해시 (중복 출금 방지용)
     * @param to 출금 받을 주소
     * @param amount 출금할 토큰 수량 (토큰 단위)
     */
    function withdraw(
        uint256 chainId,
        bytes32 txHash,
        address to,
        uint256 amount
    ) external onlyWithdrawalWallet whenNotPaused {
        // 동일한 chainId와 txHash에 대해 이미 출금이 이루어졌는지 확인
        bytes32 key = keccak256(abi.encodePacked(chainId, txHash));
        require(!processedWithdrawal[key], "Withdrawal already processed for this tx");
        processedWithdrawal[key] = true;

        // 잔액 확인
        require(token.balanceOf(address(this)) >= amount, "Insufficient token balance");

        // 토큰 전송
        require(token.transfer(to, amount), "Token transfer failed");

        emit Withdrawal(msg.sender, to, amount, chainId, txHash);
    }

    /**
     * @notice 관리자 멀티시그 출금 요청 (관리자 전용)
     *         체인ID와 txHash 없이 요청합니다.
     * @param to 출금 받을 주소
     * @param amount 출금할 토큰 수량 (토큰 단위)
     */
    function requestAdminWithdrawal(address to, uint256 amount) external onlyAdmin {
        adminWithdrawalRequestCount++;
        AdminWithdrawalRequest storage request = adminWithdrawalRequests[adminWithdrawalRequestCount];
        request.to = to;
        request.amount = amount;
        request.approvalCount = 0;
        request.executed = false;

        // 최초 요청자는 자동 승인 처리 (중복 승인 방지)
        request.approvedBy[msg.sender] = true;
        request.approvalCount = 1;

        emit AdminWithdrawalRequested(adminWithdrawalRequestCount, msg.sender, amount, to);
        emit AdminWithdrawalApproved(adminWithdrawalRequestCount, msg.sender, request.approvalCount);
    }

    /**
     * @notice 관리자 멀티시그 출금 요청 승인 (관리자 전용)
     * @param requestId 출금 요청 ID
     */
    function approveAdminWithdrawal(uint256 requestId) external onlyAdmin {
        AdminWithdrawalRequest storage request = adminWithdrawalRequests[requestId];
        require(!request.executed, "Request already executed");
        require(!request.approvedBy[msg.sender], "Already approved by this admin");

        request.approvedBy[msg.sender] = true;
        request.approvalCount++;

        emit AdminWithdrawalApproved(requestId, msg.sender, request.approvalCount);
    }

    /**
     * @notice 관리자 멀티시그 출금 실행 (관리자 전용)
     *         최소 2명의 승인이 필요함.
     * @param requestId 출금 요청 ID
     */
    function executeAdminWithdrawal(uint256 requestId) external onlyAdmin {
        AdminWithdrawalRequest storage request = adminWithdrawalRequests[requestId];
        require(!request.executed, "Request already executed");
        require(request.approvalCount >= 2, "Not enough approvals");

        // 잔액 확인
        require(token.balanceOf(address(this)) >= request.amount, "Insufficient token balance");

        request.executed = true;
        require(token.transfer(request.to, request.amount), "Token transfer failed");

        emit AdminWithdrawalExecuted(requestId, msg.sender);
    }

    /**
     * @notice 관리자 권한 업데이트 (추가 또는 제거)
     * @param adminAddr 대상 주소
     * @param status true면 관리자 추가, false면 제거
     */
    function updateAdmin(address adminAddr, bool status) external onlyAdmin {
        isAdmin[adminAddr] = status;
        emit AdminUpdated(adminAddr, status);
    }

    /**
     * @notice 출금 권한 지갑 업데이트 (추가 또는 제거)
     * @param wallet 대상 주소
     * @param status true면 출금권한 추가, false면 제거
     */
    function updateWithdrawalWallet(address wallet, bool status) external onlyAdmin {
        isWithdrawalWallet[wallet] = status;
        emit WithdrawalWalletUpdated(wallet, status);
    }
    
    /**
     * @notice 일반 출금 일시정지 함수 (어드민 1명으로 실행 가능)
     */
    function pauseWithdrawals() external onlyAdmin {
        require(!withdrawalPaused, "Withdrawals are already paused");
        withdrawalPaused = true;
        emit WithdrawalPaused(msg.sender);
    }
    
    /**
     * @notice 일반 출금 일시정지 해제 함수 (어드민 1명으로 실행 가능)
     */
    function unpauseWithdrawals() external onlyAdmin {
        require(withdrawalPaused, "Withdrawals are not paused");
        withdrawalPaused = false;
        emit WithdrawalUnpaused(msg.sender);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice 특정 관리자 출금 요청의 승인 여부를 조회
     * @param requestId 출금 요청 ID
     * @param adminAddr 관리자 주소
     * @return approved 해당 관리자가 승인했는지 여부
     */
    function hasAdminApproved(uint256 requestId, address adminAddr) external view returns (bool approved) {
        AdminWithdrawalRequest storage request = adminWithdrawalRequests[requestId];
        return request.approvedBy[adminAddr];
    }
    
    /**
     * @notice 주어진 (chainId, txHash) 조합의 출금이 이미 처리되었는지 확인합니다.
     * @param chainId 체인 식별자
     * @param txHash 트랜잭션 해시
     * @return processed 해당 조합의 출금이 처리되었으면 true, 아니면 false
     */
    function isWithdrawalProcessed(uint256 chainId, bytes32 txHash) external view returns (bool processed) {
        bytes32 key = keccak256(abi.encodePacked(chainId, txHash));
        return processedWithdrawal[key];
    }
}
