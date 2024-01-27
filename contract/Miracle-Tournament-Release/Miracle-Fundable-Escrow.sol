// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MiracleEscrow V0.8 Fundable
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
    function getUserStakedAmount(address user) external view returns (uint256);
}


contract FundableTournamentEscrow is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address public admin;
    address payable public tournamentAddr;
    // Royalty setting
    uint public RoyaltyPrizeDev;
    uint public RoyaltyregfeeDev;
    uint public RoyaltyPrizeFlp;
    uint public RoyaltyregfeeFlp;
    address public royaltyAddrDev;
    address public royaltyAddrFlp;
    // Funding setting
    uint public minFundingRate;
    // Get token fee info from asset master
    AssetMaster public assetMasterAddr;
    // Get NFT Staking info from NFT Staking
    IStakingContract[] public stakingContracts;

    // Permissions
    bytes32 private constant TOURNAMENT_ROLE = keccak256("TOURNAMENT_ROLE");

    FundableTournament internal miracletournament;

    struct Tournament {
        address organizer;
        bool isFunding;
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

    event CreateTournament(uint tournamentId, address organizer, string tournamentURI);
    event CreateFunding(uint fundingId, address fundingToken, uint fundingAmount);
    event UnlockPrize(uint tournamentId, uint amount);
    event UnlockFee(uint tournamentId, uint amount);
    event ReturnFee(uint tournamentId, address account, uint feeAmount);
    event ReturnPrize(uint tournamentId, address account, uint PrizeAmount);
    event CanceledUnlock(uint tournamentId);
    event EndedUnlock(uint tournamentId, address [] _withdrawAddresses);

    constructor(address adminAddr, address _royaltyAddrDev, address _royaltyAddrFlp, string memory _contractURI) {
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddr);
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrFlp = _royaltyAddrFlp;
        // Set default dev royalty 
        RoyaltyPrizeDev = 5;
        RoyaltyregfeeDev = 5;
        // Set default platform royalty 
        RoyaltyPrizeFlp = 5;
        RoyaltyregfeeFlp = 5;
        // Set default funding setting
        minFundingRate = 80;
        deployer = adminAddr;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    modifier onlyOrganizer(uint _tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(msg.sender == _tournament.organizer, "Only organizer can call this function");
        _;
    }

    function connectTournament(address payable _miracletournament) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setupRole(TOURNAMENT_ROLE, _miracletournament);
        miracletournament = FundableTournament(_miracletournament);
    }

    function connectAssestMaster(address _assetMasterAddr) external onlyRole(DEFAULT_ADMIN_ROLE){
        assetMasterAddr = AssetMaster(_assetMasterAddr);
    }

    function connectEditionStakings(address[] memory _stakingContractAddresses) external onlyRole(DEFAULT_ADMIN_ROLE){
        for (uint i = 0; i < _stakingContractAddresses.length; i++) {
            stakingContracts.push(IStakingContract(_stakingContractAddresses[i]));
        }
    }

    // Create tournament
    function createTournamentEscrow(uint _tournamentId, bool _isFunding, address _prizeToken, address _feeToken, uint _prizeAmount, uint _joinFee, uint256[] memory _regStartEndTime, uint256[] memory _FundStartEndTime, uint256[] memory _prizeAmountArray, string memory _tournamentURI, uint _playerLimit) external {
        require(_FundStartEndTime[0] < _FundStartEndTime[1], "Invalid funding time range");
        require(_regStartEndTime[0] < _regStartEndTime[1], "Invalid join tournament time range");
        uint256 totalWithdrawAmount;
        for (uint256 i = 0; i < _prizeAmountArray.length; i++) {
            totalWithdrawAmount += _prizeAmountArray[i];
        }
        require(totalWithdrawAmount == _prizeAmount, "Total prize amount must equal prize amount.");

        Tournament storage newTournament = tournamentMapping[_tournamentId];
        require(newTournament.tournamentCreated == false, "Tournament already created.");

        newTournament.organizer = msg.sender;
        newTournament.isFunding = _isFunding;
        newTournament.prizeToken = IERC20(_prizeToken);
        newTournament.feeToken = IERC20(_feeToken);
        newTournament.joinFee = _joinFee;
        newTournament.feeBalance = 0;
        newTournament.prizeAmountArray = _prizeAmountArray;
        newTournament.tournamentCreated = true;
        newTournament.tournamentEnded = false;
        newTournament.tournamentCanceled = false;
        newTournament.tournamentURI = _tournamentURI;
        newTournament.PlayersLimit = _playerLimit;
        
        miracletournament.createTournament(_tournamentId, _isFunding, msg.sender, _regStartEndTime[0], _regStartEndTime[1], _prizeAmountArray.length, _playerLimit);
        if (_isFunding){
            createFunding(_tournamentId, _FundStartEndTime[0], _FundStartEndTime[1], _prizeToken, _prizeAmount);
            emit CreateFunding(_tournamentId, _prizeToken, _prizeAmount);
        } else {
            require(IERC20(_prizeToken).transferFrom(msg.sender, address(this), _prizeAmount), "Transfer failed.");
        }
        _payFeeCreate();
        emit CreateTournament(_tournamentId, msg.sender, _tournamentURI);
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
        _EndedUnlockFee(_tournamentId);
        _EndedUnlockPrize(_tournamentId, _withdrawAddresses);
    }

    function canceledTournament(uint _tournamentId, address[] memory _entryPlayers) external onlyRole(TOURNAMENT_ROLE) {
        _CanceledUnlockTransfer(_tournamentId, _entryPlayers);
    }

    // USER entry to the tournament.
    function register(uint _tournamentId) external {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.joinFee, "Allowance is not sufficient.");
        require(_tournament.joinFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.organizer != msg.sender, "Organizers cannot register.");

        if(_tournament.joinFee > 0){
            require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.joinFee), "Transfer failed.");
            _tournament.feeBalance = _tournament.feeBalance + _tournament.joinFee;
        }
        _payFeeRegister();
        miracletournament.register(_tournamentId, msg.sender);
    }

    function fundTournament(uint _tournamentId, uint256 _amount) external {
        Funding storage funding = fundingMapping[_tournamentId];
        require(block.timestamp >= funding.startTime && block.timestamp <= funding.endTime, "Funding not active");
        require(funding.fundingActive, "Funding not active");
        require(funding.totalFunded + _amount <= funding.fundingGoal, "Funding amount exceeds goal");
        require(IERC20(funding.fundingToken).allowance(msg.sender, address(this)) >= _amount, "Allowance is not sufficient.");
        require(funding.fundingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        if (funding.contributions[msg.sender] == 0) {
            funding.contributors.push(msg.sender);
        }
        funding.contributions[msg.sender] += _amount;
        funding.totalFunded += _amount;
    }

    function endFunding(uint _tournamentId) external onlyRole(TOURNAMENT_ROLE) {
        Funding storage funding = fundingMapping[_tournamentId];
        require(funding.fundingActive, "Funding not active");
        require(funding.totalFunded > funding.fundingGoal * minFundingRate / 100, "Funding did not reach the minimum rate");
        funding.fundingActive = false;
        funding.fundingEnded = true;
        tournamentMapping[_tournamentId].prizeAmount = funding.totalFunded;
    }

    function cancelFunding(uint _tournamentId) external onlyRole(TOURNAMENT_ROLE) {
        Funding storage funding = fundingMapping[_tournamentId];
        require(funding.fundingActive, "Funding not active");
        funding.fundingActive = false;
        funding.fundingCanceled = true;
        for (uint i = 0; i < funding.contributors.length; i++) {
            address contributor = funding.contributors[i];
            uint256 amount = funding.contributions[contributor];
            funding.fundingToken.transfer(contributor, amount);
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
        emit CanceledUnlock(_tournamentId);
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

    function getTotalUserStakedNFTs(address user) public view returns (uint256 totalStaked) {
        totalStaked = 0;
        for (uint i = 0; i < stakingContracts.length; i++) {
            totalStaked += stakingContracts[i].getUserStakedAmount(user);
        }
    }
}