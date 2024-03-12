// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MiracleEscrow V0.8.2 Fundable
pragma solidity ^0.8.22;

import "./Miracle-Asset-Master.sol";
import "./Miracle-Fundable-Tournament.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
              
interface IMintableERC20 is IERC20 {
    function mintTo(address to, uint256 amount) external;
}

interface IStakingContract {
    function stakings(address user) external view returns (uint256, uint256, uint256);
}

interface iMiraclePass {
    function hasValidPremiumPass(address user) external view returns (bool);
    function hasValidPlatinumPass(address user) external view returns (bool);
}

contract FundableTournamentEscrow is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address public admin;
    // Royalty setting
    uint public RoyaltyPrizeDev;
    uint public RoyaltyregfeeDev;
    uint public RoyaltyPrizeFlp;
    uint public RoyaltyregfeeFlp;
    address public royaltyAddrDev;
    address public royaltyAddrFlp;
    // Funding setting
    uint public minFundingRate;
    uint public baseLimit;
    // Get token fee info from asset master
    AssetMaster public assetMasterAddr;
    // Get NFT Staking info from NFT Staking
    IStakingContract[] public stakingContracts;
    // Miracle Pass
    iMiraclePass public miraclePass;

    // Permissions
    bytes32 private constant TOURNAMENT_ROLE = keccak256("TOURNAMENT_ROLE");

    FundableTournament public miracletournament;

    struct Tournament {
        address organizer;
        bool isFunding;
        uint tier;
        IERC20 prizeToken;
        IERC20 feeToken;
        uint prizeAmount;
        uint joinFee;
        uint feeBalance;
        uint256[] prizeAmountArray;
        bool tournamentCreated;
        bool tournamentEnded;
        bool tournamentCanceled;
        string tournamentURI;
        uint PlayersLimit;
    }
    mapping(uint => Tournament) public tournamentMapping;

    struct Funding {
        uint256 startTime;
        uint256 endTime;
        IERC20 fundingToken;
        uint256 totalFunded;
        uint256 fundingGoal;
        bool fundingActive;
        bool fundingEnded;
        bool fundingCanceled;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    mapping(uint => Funding) public fundingMapping;

    event UnlockPrize(uint tournamentId, uint amount);
    event UnlockFee(uint tournamentId, uint amount);

    constructor(address _royaltyAddrDev, address _royaltyAddrFlp, address[] memory _stakingContractAddresses, address _assetMasterAddr, address _miracletournament, address _miraclePass, string memory _contractURI) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrFlp = _royaltyAddrFlp;
        // Set staking contract
        for (uint i = 0; i < _stakingContractAddresses.length; i++) {
            stakingContracts.push(IStakingContract(_stakingContractAddresses[i]));
        }
        // Set default dev royalty 
        RoyaltyPrizeDev = 5;
        RoyaltyregfeeDev = 5;
        // Set default platform royalty 
        RoyaltyPrizeFlp = 5;
        RoyaltyregfeeFlp = 5;
        // Set default funding setting
        minFundingRate = 100;
        baseLimit = 200e6;
        deployer = msg.sender;
        // Set asset master contract
        assetMasterAddr = AssetMaster(_assetMasterAddr);
        // Set tournament contract
        _setupRole(TOURNAMENT_ROLE, _miracletournament);
        miracletournament = FundableTournament(_miracletournament);
        // Set miracle pass contract
        miraclePass = iMiraclePass(_miraclePass);
        _setupContractURI(_contractURI);
    }

    event EscrowCreated(uint tournamentId, address organizer);
    event Registration(uint tournamentId, address user);
    event KickPlayer(uint tournamentId, address user);
    event Fund(uint tournamentId, address fundingUser, uint256 fundingAmount);
    event FundEnded(uint tournamentId);
    event FundCanceled(uint tournamentId);
    event TournamentEnded(uint tournamentId);
    event TournamentCanceled(uint tournamentId);

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    modifier onlyOrganizer(uint _tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(msg.sender == _tournament.organizer, "Only organizer can call this function");
        _;
    }

    function connectEditionStakings(address[] memory _stakingContractAddresses) external onlyRole(DEFAULT_ADMIN_ROLE){
        // Clear the existing array
        delete stakingContracts;
            
        for (uint i = 0; i < _stakingContractAddresses.length; i++) {
            stakingContracts.push(IStakingContract(_stakingContractAddresses[i]));
        }
    }

    function connectTournament(address _miracletournament) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setupRole(TOURNAMENT_ROLE, _miracletournament);
        miracletournament = FundableTournament(_miracletournament);
    }

    function connectAssestMaster(address _assetMasterAddr) external onlyRole(DEFAULT_ADMIN_ROLE){
        assetMasterAddr = AssetMaster(_assetMasterAddr);
    }

    function connectMiraclePass(address _miraclePassAddr) external onlyRole(DEFAULT_ADMIN_ROLE){
        miraclePass = iMiraclePass(_miraclePassAddr);
    }

    // Create tournament
    function createTournamentEscrow(uint256[] memory _tournamentInfo, bool _isFunding, address[] memory _prizeFeeToken, uint256[] memory _prizeFeeAmount, uint256[] memory _regStartEndTime, uint256[] memory _FundStartEndTime, uint256[] memory _prizeAmountArray, string memory _tournamentURI, uint _playerLimit) external {
        // Create Tournament Pamameter
        // _tournamentInfo 0-TournamentId, 1-TournamentTier
        // Escrow -> Tournament
        require(_FundStartEndTime[0] < _FundStartEndTime[1], "Invalid funding time range");
        require(_regStartEndTime[0] < _regStartEndTime[1], "Invalid join tournament time range");
        uint256 totalWithdrawAmount;
        for (uint256 i = 0; i < _prizeAmountArray.length; i++) {
            totalWithdrawAmount += _prizeAmountArray[i];
        }
        require(totalWithdrawAmount == _prizeFeeAmount[0], "Total prize amount must equal prize amount.");
        
        Tournament storage newTournament = tournamentMapping[_tournamentInfo[0]];
        require(newTournament.tournamentCreated == false, "Tournament already created.");
        _payFeeCreate();

        newTournament.organizer = msg.sender;
        newTournament.isFunding = _isFunding;
        newTournament.tier = _tournamentInfo[1];
        newTournament.prizeToken = IERC20(_prizeFeeToken[0]);
        newTournament.feeToken = IERC20(_prizeFeeToken[1]);
        newTournament.joinFee = _prizeFeeAmount[1];
        newTournament.feeBalance = 0;
        newTournament.prizeAmount = _prizeFeeAmount[0];
        newTournament.prizeAmountArray = _prizeAmountArray;
        newTournament.tournamentCreated = true;
        newTournament.tournamentEnded = false;
        newTournament.tournamentCanceled = false;
        newTournament.tournamentURI = _tournamentURI;
        newTournament.PlayersLimit = _playerLimit;
        // createTournament(uint _tournamentId, bool _isFunding, address _organizer, uint _registerStartTime, uint _registerEndTime, uint _prizeCount, uint _playerLimit)
        miracletournament.createTournament(_tournamentInfo[0], _isFunding, msg.sender, _regStartEndTime[0], _regStartEndTime[1], _prizeAmountArray.length, _playerLimit);
        if (_isFunding){
            createFunding(_tournamentInfo[0], _FundStartEndTime[0], _FundStartEndTime[1], _prizeFeeToken[0], _prizeFeeAmount[0]);
        } else {
            require(IERC20(_prizeFeeToken[0]).transferFrom(msg.sender, address(this), _prizeFeeAmount[0]), "Transfer failed.");
        }
        
        emit EscrowCreated(_tournamentInfo[0], msg.sender);
    }

    function createFunding(uint _tournamentId, uint _fundStartTime, uint _fundEndTime, address _fundingToken, uint _fundingGoal) internal {
        Funding storage funding = fundingMapping[_tournamentId];
        require(_fundStartTime < _fundEndTime, "Invalid time range");
        require(_fundingToken != address(0), "Invalid token address");

        funding.startTime = _fundStartTime;
        funding.endTime = _fundEndTime;
        funding.fundingToken = IERC20(_fundingToken);
        funding.fundingGoal = _fundingGoal;
        funding.fundingActive = true;
    }

    function endedTournament(uint _tournamentId, address[] memory _withdrawAddresses) external onlyRole(TOURNAMENT_ROLE) {
        // Tournament -> Escrow
        _EndedUnlockFee(_tournamentId);
        _EndedUnlockPrize(_tournamentId, _withdrawAddresses);
        emit TournamentEnded(_tournamentId);
    }

    function canceledTournament(uint _tournamentId, address[] memory _entryPlayers) external onlyRole(TOURNAMENT_ROLE) {
        // Tournament -> Escrow
        _CanceledUnlockTransfer(_tournamentId, _entryPlayers);
        emit TournamentCanceled(_tournamentId);
    }

    // USER entry to the tournament.
    function register(uint _tournamentId) external {
        // Escrow -> Tournament
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.joinFee, "Allowance is not sufficient.");
        require(_tournament.joinFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.organizer != msg.sender, "Organizers cannot register.");
        require(tierValify(_tournament.tier, msg.sender), "There are no required passes for the tournament.");

        // 사용자 티어 확인 로직 필요

        if (_tournament.isFunding){
            Funding storage funding = fundingMapping[_tournamentId];
            require(funding.fundingEnded, "Funding is not ended.");
        }

        _payFeeRegister();

        if(_tournament.joinFee > 0){
            require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.joinFee), "Transfer failed.");
            _tournament.feeBalance = _tournament.feeBalance + _tournament.joinFee;
        }
        
        miracletournament.register(_tournamentId, msg.sender);
        emit Registration(_tournamentId, msg.sender);
    }

    function kickPlayer(uint _tournamentId, address _player) external onlyRole(TOURNAMENT_ROLE) {
        // Tournament -> Escrow
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        if(_tournament.joinFee > 0){
            require(_tournament.feeToken.transferFrom(address(this), _player, _tournament.joinFee), "Transfer failed.");
            _tournament.feeBalance = _tournament.feeBalance - _tournament.joinFee;
        }
        emit KickPlayer(_tournamentId, msg.sender);
    }

    function fundTournament(uint _tournamentId, uint256 _amount) external {
        Funding storage funding = fundingMapping[_tournamentId];
        require(block.timestamp >= funding.startTime && block.timestamp <= funding.endTime, "Funding not active");
        require(funding.fundingActive, "Funding not active");
        require(funding.totalFunded + _amount <= funding.fundingGoal, "Funding amount exceeds goal");
        require(IERC20(funding.fundingToken).allowance(msg.sender, address(this)) >= _amount, "Allowance is not sufficient.");
        require(funding.fundingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        require(_amount >= baseLimit, "Amount is less than the minimum required");
        require(_amount % baseLimit == 0, "Amount must be in multiples of 200");

        // Get staking amount
        uint256 stakedNFTs = getTotalUserStakedAmount(msg.sender);
        uint256 maxFundingLimit = calculateMaxFundingLimit(stakedNFTs);

        uint256 newTotalContribution = funding.contributions[msg.sender] + _amount;
        require(newTotalContribution <= maxFundingLimit, "Total contribution exceeds maximum funding limit");

        if (funding.contributions[msg.sender] == 0) {
            // New funder
            funding.contributors.push(msg.sender);
        }
        funding.contributions[msg.sender] = newTotalContribution;
        funding.totalFunded += _amount;
        emit Fund(_tournamentId, msg.sender, _amount);
    }

    function endFunding(uint _tournamentId) external onlyRole(TOURNAMENT_ROLE) {
        // Tournament -> Escrow
        Funding storage funding = fundingMapping[_tournamentId];
        require(funding.fundingActive, "Funding not active");
        require(funding.totalFunded >= funding.fundingGoal * minFundingRate / 100, "Funding did not reach the minimum rate");
        funding.fundingActive = false;
        funding.fundingEnded = true;
        tournamentMapping[_tournamentId].prizeAmount = funding.totalFunded;

        emit FundEnded(_tournamentId);
    }

    function cancelFunding(uint _tournamentId) external onlyRole(TOURNAMENT_ROLE) {
        // Tournament -> Escrow
        Funding storage funding = fundingMapping[_tournamentId];
        require(funding.fundingActive, "Funding not active");
        funding.fundingActive = false;
        funding.fundingCanceled = true;
        for (uint i = 0; i < funding.contributors.length; i++) {
            address contributor = funding.contributors[i];
            uint256 amount = funding.contributions[contributor];
            funding.fundingToken.transfer(contributor, amount);
        }
        emit FundCanceled(_tournamentId);
    }

    // Check tier pass
    function tierValify(uint _gameTier, address user) public view returns (bool) {
        if(_gameTier == 1){
            return miraclePass.hasValidPremiumPass(user);
        }else if(_gameTier == 2){
            return miraclePass.hasValidPlatinumPass(user);
        }else{
            return true;
        }
    }

    // Function to pay a fee
    function _payFeeCreate() internal {
        address feeWallet = assetMasterAddr.feeRecipient(); 
        address feeToken = assetMasterAddr.feeToken();
        uint256 amount = assetMasterAddr.tournamentCreationFee();
        if(amount > 0){
            require(IERC20(feeToken).transferFrom(msg.sender, feeWallet, amount), "Asset master token fee transfer failed.");
        }
    }

    function _payFeeRegister() internal {
        address feeWallet = assetMasterAddr.feeRecipient();
        address feeToken = assetMasterAddr.feeToken();
        uint256 amount = assetMasterAddr.tournamentParticipationFee();
        if(amount > 0){
            require(IERC20(feeToken).transferFrom(msg.sender, feeWallet, amount), "Asset master token fee transfer failed.");
        }
    }

    function _EndedUnlockFee(uint _tournamentId) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Calculate join fee and transfer
        uint256 _feeAmount = _tournament.feeBalance;
        uint256 _feeDev = (_feeAmount * RoyaltyregfeeDev) / 100;
        uint256 _feeFlp = (_feeAmount * RoyaltyregfeeFlp) / 100;
        if(_tournament.isFunding){
            uint256 _feeForInvestors = _feeAmount - (_feeDev + _feeFlp);
            _transferToken(_tournament.feeToken, royaltyAddrDev, _feeDev);
            _transferToken(_tournament.feeToken, royaltyAddrFlp, _feeFlp);
            // Distribute remaining fee to investors
            Funding storage funding = fundingMapping[_tournamentId];
            uint256 totalInvested = funding.totalFunded;
            for (uint i = 0; i < funding.contributors.length; i++) {
                address investor = funding.contributors[i];
                uint256 investedAmount = funding.contributions[investor];
                uint256 investorShare = (_feeForInvestors * investedAmount) / totalInvested;
                _transferToken(_tournament.feeToken, investor, investorShare);
            }
        } else {
            uint256 _feeOrg = _feeAmount - (_feeDev + _feeFlp);
            _transferToken(_tournament.feeToken, royaltyAddrDev, _feeDev);
            _transferToken(_tournament.feeToken, royaltyAddrFlp, _feeFlp);
            _transferToken(_tournament.feeToken, _tournament.organizer, _feeOrg);
        }
        emit UnlockFee(_tournamentId, _tournament.feeBalance);
    }

    // Tournament END unlock PRIZE (auto transfer)
    function _EndedUnlockPrize(uint _tournamentId, address[] memory _winner) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Set tournament status ended
        _tournament.tournamentEnded = true;

        uint256[] memory _prizeAmountArray = _tournament.prizeAmountArray;
        require(_winner.length == _prizeAmountArray.length, "Arrays must be the same length.");
        // Transfer prize to winner
        for (uint256 i = 0; i < _winner.length; i++) {
            uint256 _prizeAmount = _prizeAmountArray[i];
            if (_prizeAmount > 0) {
                // Calculate PRIZE and transfer
                uint256 _prizeDev = (_prizeAmount * RoyaltyPrizeDev) / 100;
                uint256 _prizeFlp = (_prizeAmount * RoyaltyPrizeFlp) / 100;
                uint256 _prizeUser = _prizeAmount - (_prizeDev + _prizeFlp);
                _transferToken(_tournament.prizeToken, royaltyAddrDev, _prizeDev);
                _transferToken(_tournament.prizeToken, royaltyAddrFlp, _prizeFlp);
                _transferToken(_tournament.prizeToken, _winner[i], _prizeUser);
            }
        }
        emit UnlockPrize(_tournamentId, _tournament.prizeAmount);
    }

    // Tournament CANCEL unlock PRIZE and entry fee (auto transfer)
    function _CanceledUnlockTransfer(uint _tournamentId, address[] memory _players) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Set tournament status canceled
        _tournament.tournamentCanceled = true;
        if(_tournament.joinFee > 0){
            // Transfer entry fee to users
            for (uint256 i = 0; i < _players.length; i++) {
                _tournament.feeToken.transfer(_players[i], _tournament.joinFee);
            }
        }
        
        if(_tournament.isFunding){
            Funding storage funding = fundingMapping[_tournamentId];
            funding.fundingActive = false;
            funding.fundingCanceled = true;
            for (uint i = 0; i < funding.contributors.length; i++) {
                address contributor = funding.contributors[i];
                uint256 amount = funding.contributions[contributor];
                funding.fundingToken.transfer(contributor, amount);
            }
        }else{
            if(_tournament.prizeAmount > 0){
                // Transfer prize to org
                _tournament.prizeToken.transfer(_tournament.organizer, _tournament.prizeAmount);
            }
        }
    }

    function _transferToken(IERC20 token, address to, uint256 amount) internal {
        if (amount > 0) {
            require(token.transfer(to, amount),"Transfer failed");
        }
    }

    // Set royalty address
    function setRoyaltyDevAddress(address _royaltyAddr) external onlyRole(DEFAULT_ADMIN_ROLE){
        royaltyAddrDev = _royaltyAddr;
    }

    function setRoyaltyFlpAddress(address _royaltyAddr) external onlyRole(DEFAULT_ADMIN_ROLE){
        royaltyAddrFlp = _royaltyAddr;
    }

    // Set prize royalty rate
    function setPrizeRoyaltyDevRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyPrizeDev = _royaltyRate;
    }

    function setPrizeRoyaltyFlpRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyPrizeFlp = _royaltyRate;
    }

    // Set regfee royalty rate
    function setRegfeeRoyaltyDevRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyregfeeDev = _royaltyRate;
    }

    function setRegfeeRoyaltyFlpRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyregfeeFlp = _royaltyRate;
    }

    // Set Funding
    function setMinimumFundingRate(uint _newRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newRate > 0 && _newRate <= 100, "Invalid rate");
        minFundingRate = _newRate;
    }
    
    // View function
    function getFundingProgress(uint _tournamentId) public view returns (uint) {
        Funding storage funding = fundingMapping[_tournamentId];
        if (funding.fundingGoal == 0) {
            return 0;
        }
        uint progress = (funding.totalFunded * 100) / funding.fundingGoal;
        return progress;
    }

    function getMinFundingRate() public view returns (uint) {
        return minFundingRate;
    }

    function getFundingDetails(uint _tournamentId) public view returns (uint256 startTime, uint256 endTime, address fundingToken, uint256 totalFunded, uint256 fundingGoal, bool fundingActive, bool fundingEnded, bool fundingCanceled, address[] memory contributors) {
        Funding storage funding = fundingMapping[_tournamentId];
        return (funding.startTime, funding.endTime, address(funding.fundingToken), funding.totalFunded, funding.fundingGoal, funding.fundingActive, funding.fundingEnded, funding.fundingCanceled, funding.contributors);
    }

    function isFundingSuccess(uint _tournamentId) public view returns (bool) {
        uint progress = getFundingProgress(_tournamentId);
        uint minRate = getMinFundingRate();
        return progress >= minRate;
    }

    function getTotalUserStakedAmount(address user) public view returns (uint256 totalAmount) {
        totalAmount = 0;

        for (uint i = 0; i < stakingContracts.length; i++) {
            (uint256 amount,,) = stakingContracts[i].stakings(user);
            totalAmount += amount;
        }
    }

    function calculateMaxFundingLimit(uint256 stakedNFTs) public view returns (uint256) {
        uint256 maxStakedNFTs = 50; 

        if (stakedNFTs <= 1) {
            return baseLimit;
        }   

        if (stakedNFTs > maxStakedNFTs) {
            stakedNFTs = maxStakedNFTs;
        }

        return baseLimit * stakedNFTs;
    }
}