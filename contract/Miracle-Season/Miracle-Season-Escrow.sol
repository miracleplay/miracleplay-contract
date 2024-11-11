// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MiracleSeasonEscrow V1.2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MiracleSeasonEscrow is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer; // Address of the contract deployer

    // Struct to store season information
    struct Season {
        uint256 seasonId;              // Season ID
        address rewardToken;           // Token address used as reward
        uint256 totalRewardAmount;     // Total reward amount to be distributed in the season
        uint256[] prizeDistribution;   // Array for prize distribution by rank
        bool isEnded;                  // Status of season (true if ended)
    }

    mapping(uint256 => Season) public seasons; // Mapping of season ID to Season struct

    // Modifier to check if a season exists
    modifier seasonExists(uint256 _seasonId) {
        require(seasons[_seasonId].seasonId == _seasonId, "Season does not exist.");
        _;
    }

    // Modifier to check if a season has not ended
    modifier seasonNotEnded(uint256 _seasonId) {
        require(!seasons[_seasonId].isEnded, "Season has already ended.");
        _;
    }

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE"); // Definition of the FACTORY_ROLE

    // Event definitions
    event SeasonCreated(
        uint256 indexed seasonId,
        address rewardToken,
        uint256 totalRewardAmount,
        uint256 timestamp
    );

    event SeasonEnded(
        uint256 indexed seasonId,
        address[] winners,
        uint256 timestamp
    );

    // Constructor to initialize contract metadata and roles
    constructor(string memory _contractURI, address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin); // Set admin role
        _setupRole(FACTORY_ROLE, admin);       // Set FACTORY_ROLE
        deployer = msg.sender;                 // Store the deployer address

        // Setup FACTORY_ROLE for specific addresses
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

        _setupContractURI(_contractURI); // Set contract metadata URI
    }

    // Checks if the deployer can set the contract URI
    function _canSetContractURI() internal view virtual override returns (bool) {
        return msg.sender == deployer;
    }

    // Function to create a season, allowing for optional rewards if rewardToken is address(0)
    function createSeason(
        uint256 currentSeasonId,
        address _rewardToken,
        uint256 _totalRewardAmount,
        uint256[] memory _prizeDistribution
    ) external {
        require(_totalRewardAmount > 0 || _rewardToken == address(0), "Total reward amount should be greater than 0 for rewarded season.");
        require(_prizeDistribution.length > 0, "Prize distribution array should not be empty.");

        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < _prizeDistribution.length; i++) {
            totalDistributed += _prizeDistribution[i];
        }
        require(totalDistributed == _totalRewardAmount, "Sum of prize distribution does not match total reward amount.");

        // If rewardToken is specified, transfer the reward tokens to the contract for safekeeping
        if (_rewardToken != address(0)) {
            IERC20(_rewardToken).transferFrom(msg.sender, address(this), _totalRewardAmount);
        }

        // Store the new season details
        seasons[currentSeasonId] = Season({
            seasonId: currentSeasonId,
            rewardToken: _rewardToken,
            totalRewardAmount: _totalRewardAmount,
            prizeDistribution: _prizeDistribution,
            isEnded: false
        });

        // Emit an event for season creation
        emit SeasonCreated(currentSeasonId, _rewardToken, _totalRewardAmount, block.timestamp);
    }

    // Function to end a season; if no rewards, skip prize distribution
    function endSeason(uint256 _seasonId, address[] memory _rankedUsers)
        external
        onlyRole(FACTORY_ROLE)
        seasonExists(_seasonId)
        seasonNotEnded(_seasonId)
    {
        Season storage season = seasons[_seasonId];
        require(_rankedUsers.length == season.prizeDistribution.length, "Ranked users and prize distribution length mismatch.");

        season.isEnded = true; // Set season status to ended

        // If rewardToken is not address(0), distribute rewards
        if (season.rewardToken != address(0)) {
            IERC20 rewardToken = IERC20(season.rewardToken); // Create an instance of the reward token
            address[] memory winners = new address[](_rankedUsers.length); // Array to store winners
            uint256[] memory prizes = new uint256[](_rankedUsers.length);  // Array to store prize amounts

            // Distribute prizes to each winner based on rank
            for (uint256 i = 0; i < _rankedUsers.length; i++) {
                uint256 prize = season.prizeDistribution[i];
                winners[i] = _rankedUsers[i];
                prizes[i] = prize;
                rewardToken.transfer(_rankedUsers[i], prize); // Transfer prize to winner
            }

            // Emit an event for season end with rewards
            emit SeasonEnded(_seasonId, winners, block.timestamp);
        } else {
            // Emit an event for season end without rewards
            emit SeasonEnded(_seasonId, _rankedUsers, block.timestamp);
        }
    }

    // View function to retrieve details of a specific season
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
