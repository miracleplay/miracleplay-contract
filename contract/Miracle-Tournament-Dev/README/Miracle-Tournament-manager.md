# MiracleTournamentManager.sol

## 개요
이 컨트랙트는 사용자가 토너먼트를 생성하고, 참가자를 등록하고, 점수를 업데이트하고, 순위에 따라 상금을 분배하는 토너먼트를 관리합니다.

## 컨트랙트 세부사항
- Solidity 버전: ^0.8.0
- 라이센스: MIT

## 함수들

### createTournament
지정된 파라미터로 새로운 토너먼트를 생성합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.
  - `_prizeTokenAddress` (address): 상금으로 사용되는 토큰의 주소.
  - `_entryTokenAddress` (address): 참가비로 사용되는 토큰의 주소.
  - `_prizeAmount` (uint256): 총 상금 금액.
  - `_entryFee` (uint256): 참가자 참가비.
  - `_prizeDistribution` (uint256[]): 상금 분배.
  - `_maxParticipants` (uint256): 최대 참가자 수.

### updatePrizeDistribution
토너먼트의 상금 분배를 업데이트합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.
  - `_prizeDistribution` (uint256[]): 상금 분배.

### participateInTournament
토너먼트에 참가자를 등록합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.

### removeParticipant
토너먼트에서 참가자를 제거합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.
  - `_participant` (address): 제거할 참가자의 주소.

### shuffleParticipants
토너먼트의 참가자를 섞습니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.

### cancelTournament
토너먼트를 취소하고 참가비를 참가자에게 환불합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.

### endTournamentC
토너먼트를 종료하고 청구 가능한 상금을 계산합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.
  - `_winners` (address[]): 상금을 받을 자격이 있는 순위 참가자의 주소 배열.

### endTournamentA
토너먼트를 종료하고 자동으로 수수료, 상금 설정 및 분배를 처리합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.
  - `_winners` (address[]): 상금을 받을 자격이 있는 순위 참가자의 주소 배열.

### claimPrize
우승자가 상금을 청구할 수 있도록 합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.

### getTournamentInfo
토너먼트에 대한 정보를 조회합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.

### getTournamentParticipants
토너먼트의 참가자를 조회합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.

### getTournamentPrizeDistribution
토너먼트의 상금 분배를 조회합니다.
- **파라미터:**
  - `_tournamentId` (uint256): 토너먼트의 고유 식별자.

### getTournamentFees
컨트랙트의 수수료 정보를 조회합니다.

### setDeveloperFee
개발자 수수료를 설정합니다.
- **파라미터:**
  - `_feeAddress` (address): 개발자 수수료를 받을 주소.
  - `_feePercent` (uint256): 개발자 수수료 비율.

### setWinnerClubFee
우승자 클럽 수수료를 설정합니다.
- **파라미터:**
  - `_feeAddress` (address): 우승자 클럽 수수료를 받을 주소.
  - `_feePercent` (uint256): 우승자 클럽 수수료 비율.

### setPlatformFee
플랫폼 수수료를 설정합니다.
- **파라미터:**
  - `_feeAddress` (address): 플랫폼 수수료를 받을 주소.
  - `_feePercent` (uint256): 플랫폼 수수료 비율.