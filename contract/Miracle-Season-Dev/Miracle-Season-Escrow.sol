// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MiracleSeasonEscrow is PermissionsEnumerable, Multicall, ContractMetadata{
    address public deployer;

    struct Season {
        uint256 seasonId;
        address rewardToken;
        uint256 totalRewardAmount;
        uint256[] prizeDistribution;
        bool isEnded;
    }

    mapping(uint256 => Season) public seasons;

    modifier seasonExists(uint256 _seasonId) {
        require(seasons[_seasonId].seasonId == _seasonId, "Season does not exist.");
        _;
    }

    modifier seasonNotEnded(uint256 _seasonId) {
        require(!seasons[_seasonId].isEnded, "Season has already ended.");
        _;
    }

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    constructor(string memory _contractURI, address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(FACTORY_ROLE, admin);
        // Backend worker address
        _setupRole(FACTORY_ROLE, 0x8914b41C3D0491E751d4eA3EbfC04c42D7275A75);
        _setupRole(FACTORY_ROLE, 0x2fB586cD6bF507998e0816897D812d5dF2aF7677);
        _setupRole(FACTORY_ROLE, 0x7C7f65a0f86a556aAA04FD9ceDb1AA6D943C35c3);
        _setupRole(FACTORY_ROLE, 0xd278a5A5B9A83574852d25F08420029972fd2c6f);
        _setupRole(FACTORY_ROLE, 0x7c35582e6b953b0D7980ED3444363B5c99d1ded3);
        _setupRole(FACTORY_ROLE, 0xe463D4fdBc692D9016949881E6a5e18d815C4537);
        _setupRole(FACTORY_ROLE, 0x622DfbD67fa2e87aa8c774e14fda2791656f282b);
        _setupRole(FACTORY_ROLE, 0xbE810123C22046d93Afb018d7c4b7248df0088BE);
        _setupRole(FACTORY_ROLE, 0xc184A36eac1EA5d62829cc80e8e57E7c4994D40B);
        _setupRole(FACTORY_ROLE, 0xDCa74207a0cB028A2dE3aEeDdC7A9Be52109a785);
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function createSeason(
        uint256 currentSeasonId,
        address _rewardToken,
        uint256 _totalRewardAmount,
        uint256[] memory _prizeDistribution
    ) external {
        require(_rewardToken != address(0), "Invalid reward token address.");
        require(_totalRewardAmount > 0, "Total reward amount should be greater than 0.");
        require(_prizeDistribution.length > 0, "Prize distribution array should not be empty.");

        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < _prizeDistribution.length; i++) {
            totalDistributed += _prizeDistribution[i];
        }

        require(totalDistributed == _totalRewardAmount, "Sum of prize distribution does not match total reward amount.");

        seasons[currentSeasonId] = Season({
            seasonId: currentSeasonId,
            rewardToken: _rewardToken,
            totalRewardAmount: _totalRewardAmount,
            prizeDistribution: _prizeDistribution,
            isEnded: false
        });
    }

    function endSeason(uint256 _seasonId, address[] memory _rankedUsers) 
        external 
        onlyRole(FACTORY_ROLE) 
        seasonExists(_seasonId) 
        seasonNotEnded(_seasonId) 
    {
        Season storage season = seasons[_seasonId];
        require(_rankedUsers.length == season.prizeDistribution.length, "Ranked users and prize distribution length mismatch.");

        season.isEnded = true;

        IERC20 rewardToken = IERC20(season.rewardToken);

        for (uint256 i = 0; i < _rankedUsers.length; i++) {
            uint256 prize = season.prizeDistribution[i];
            require(prize <= season.totalRewardAmount, "Prize amount exceeds total reward amount.");
            season.totalRewardAmount -= prize;
            rewardToken.transfer(_rankedUsers[i], prize);
        }
    }

    function getSeason(uint256 _seasonId) external view returns (
        uint256 seasonId,
        address rewardToken,
        uint256 totalRewardAmount,
        uint256[] memory prizeDistribution,
        bool isEnded
    ) {
        Season storage season = seasons[_seasonId];
        return (
            season.seasonId,
            season.rewardToken,
            season.totalRewardAmount,
            season.prizeDistribution,
            season.isEnded
        );
    }
}
