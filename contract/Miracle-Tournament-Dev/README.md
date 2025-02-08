# MiracleTournamentManager v0.1

<div align="center">
  <img src="https://your-logo-url.png" alt="Miracle Tournament Logo" width="200"/>
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.0-blue)](https://soliditylang.org/)
  [![Hardhat](https://img.shields.io/badge/Built%20with-Hardhat-yellow)](https://hardhat.org/)
</div>

## 📝 개요

MiracleTournamentManager는 블록체인 기반의 토너먼트 관리 스마트 컨트랙트입니다. 토너먼트 생성, 참가자 관리, 상금 분배 등 다양한 기능을 제공합니다.

### ✨ 주요 기능

- 🏆 토너먼트 생성 및 관리
- 👥 참가자 등록/제거 시스템
- 💰 상금 풀 및 참가비 관리
- 🔄 자동/수동 상금 지급 시스템
- 📊 수수료 관리 (Developer, WinnerClub, Platform)

## 🚀 시작하기

### 사전 요구사항

- Node.js v14 이상
- npm 또는 yarn
- Hardhat

### 설치

```bash
# 저장소 클론
git clone https://github.com/YourRepository/MiracleTournamentManager.git

# 프로젝트 폴더로 이동
cd MiracleTournamentManager

# 의존성 설치
npm install

# 컴파일
npx hardhat compile
```

## 💡 사용 방법

### 토너먼트 생성

```javascript
const tournament = await manager.createTournament(
    tournamentId,          // 토너먼트 ID
    prizeTokenAddress,     // 상금 토큰 주소
    entryTokenAddress,     // 참가비 토큰 주소
    prizeAmount,          // 총 상금액
    entryFee,            // 참가비
    prizeDistribution,    // 상금 분배율
    maxParticipants      // 최대 참가자 수
);
```

### 토너먼트 참가

```javascript
// 참가비가 있는 경우 approve 필요
await entryToken.approve(managerAddress, entryFee);
await manager.participateInTournament(tournamentId);
```

## 🔐 권한 시스템

### 관리자 권한 (DEFAULT_ADMIN_ROLE)
- 수수료 설정
- 컨트랙트 설정 변경

### 운영자 권한 (FACTORY_ROLE)
- 토너먼트 운영 관리
- 참가자 셔플
- 토너먼트 종료/취소

## 📊 수수료 구조

| 수수료 종류 | 설명 | 설정 권한 |
|------------|------|-----------|
| Developer Fee | 개발자 수수료 | Admin |
| WinnerClub Fee | 위너클럽 수수료 | Admin |
| Platform Fee | 플랫폼 수수료 | Admin |

## 🔍 조회 함수

```solidity
// 토너먼트 정보 조회
function getTournamentInfo(uint256 _tournamentId) external view returns (...);

// 참가자 목록 조회
function getTournamentParticipants(uint256 _tournamentId) external view;

// 상금 분배 정보 조회
function getTournamentPrizeDistribution(uint256 _tournamentId) external view;
```

## ⚠️ 보안 고려사항

- **토큰 승인**: 상금/참가비 토큰 전송 전 반드시 approve 필요
- **난수 생성**: block.prevrandao 사용으로 제한적 무작위성
- **권한 관리**: 관리자 키 안전한 보관 필수

## 📄 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 🤝 기여하기

1. 이 저장소를 포크합니다
2. 새로운 브랜치를 생성합니다
3. 변경사항을 커밋합니다
4. 브랜치에 푸시합니다
5. Pull Request를 생성합니다

## 📬 문의하기

- Project Link: [https://github.com/YourRepository/MiracleTournamentManager](https://github.com/YourRepository/MiracleTournamentManager)
- Issues: [https://github.com/YourRepository/MiracleTournamentManager/issues](https://github.com/YourRepository/MiracleTournamentManager/issues)