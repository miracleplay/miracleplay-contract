// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MiracleSeasonEventLogger is PermissionsEnumerable, Multicall, ContractMetadata{
    address public deployer;

    // EXP 획득 이벤트
    event EXPGained(
        uint256 indexed seasonId,
        uint256 indexed tournamentId,
        address indexed user,
        uint256 expGained,
        uint256 timestamp
    );

    // 레벨업 이벤트
    event LevelUp(
        uint256 indexed seasonId,
        address indexed user,
        uint256 previousLevel,
        uint256 newLevel,
        uint256 timestamp
    );

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    constructor(string memory _contractURI, address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(FACTORY_ROLE, admin);
        // Backend worker address
        _setupRole(FACTORY_ROLE, 0x8914b41C3D0491E751d4eA3EbfC04c42D7275A75);
        _setupRole(FACTORY_ROLE, 0x21e7f129906E9590ED86514ad6Ea24Bfb51ff7Aa);
        _setupRole(FACTORY_ROLE, 0x4439335C0510f219fDCDf24c17CA04519cf6acaB);
        _setupRole(FACTORY_ROLE, 0x38C8B1e5C74D5624984306f04a3fC6530314c12e);
        _setupRole(FACTORY_ROLE, 0xB8E4a928B26641062DB940F0CbfC5E0673d5dd21);
        _setupRole(FACTORY_ROLE, 0x44831D76f8EE889BA13c9CFc6150c9f9BD57Fcf5);
        _setupRole(FACTORY_ROLE, 0x94cc3Fbb7DBd1adF321dF30C8DdDFD456A38d199);
        _setupRole(FACTORY_ROLE, 0xB93518CBFB9B296B1C29d0071b5C719E02709972);
        _setupRole(FACTORY_ROLE, 0x27682DbE4e0cBd6e08E9Ed1834B08eD8F22b2290);
        _setupRole(FACTORY_ROLE, 0x5503d2131DfFFA43D735ADdE3d06318Aa50e1cc1);
        _setupRole(FACTORY_ROLE, 0xF0E684097a91A22D9eCC76F150e45A993F02Fdee);
        _setupRole(FACTORY_ROLE, 0xd8a4071c2138a5bC4eDe9e4A9572fe52961B3411);
        _setupRole(FACTORY_ROLE, 0xCf604788017E5233944A8dd61Dc7585ceF518252);
        _setupRole(FACTORY_ROLE, 0x82c7dcA7cf59a71D88d2E277Ea50e0d280017aAd);
        _setupRole(FACTORY_ROLE, 0xE0e17E460fcF2ce9a0a7Ccd00dC46a831dD96d0c);
        _setupRole(FACTORY_ROLE, 0xeCE8Dd51550DAd391B41140FF37eE1f72b8c66ce);
        _setupRole(FACTORY_ROLE, 0xb2A4Bf1ab9e48FE5cc587e136FdB015537861a47);
        _setupRole(FACTORY_ROLE, 0x68D757bcb544b16cA6EE20d01e36a14DB9Ad888c);
        _setupRole(FACTORY_ROLE, 0xEC68a8774768aed9F47f2B948a11D495B5e35c69);
        _setupRole(FACTORY_ROLE, 0xB0e77E9BF9774794C4742151E7636499e5554A36);
        _setupRole(FACTORY_ROLE, 0xB4445C049E3eCee1b2B4C1aB83858F48CeAD7DcC);
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    // EXP 획득 이벤트 발생 함수
    function logEXPGained(
        uint256 seasonId,
        uint256 tournamentId,
        address user,
        uint256 expGained,
        uint256 timestamp
    ) external onlyRole(FACTORY_ROLE)  {
        require(user != address(0), "Invalid user address.");
        emit EXPGained(seasonId, tournamentId, user, expGained, timestamp);
    }

    // 레벨업 이벤트 발생 함수
    function logLevelUp(
        uint256 seasonId,
        address user,
        uint256 previousLevel,
        uint256 newLevel,
        uint256 timestamp
    ) external onlyRole(FACTORY_ROLE)  {
        require(user != address(0), "Invalid user address.");
        require(newLevel > previousLevel, "New level must be greater than previous level.");
        emit LevelUp(seasonId, user, previousLevel, newLevel, timestamp);
    }
}
