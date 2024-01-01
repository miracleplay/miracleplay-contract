// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "./Miracle-Fund-Tournament-R1.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MiracleFundingEscrow V0.1                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              .0
                                             
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function mintTo(address to, uint256 amount) external;
    function decimals() external view returns (uint8);
}

contract MiracleTournamentEscrow is  PermissionsEnumerable, Multicall, ContractMetadata {
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
    // Permissions
    bytes32 private constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 private constant TOURNAMENT_ROLE = keccak256("TOURNAMENT_ROLE");

    MiracleTournament internal miracletournament;

    struct Tournament {
        address organizer;
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
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    mapping(uint => Funding) public fundingMapping;

    event CreateTournament(uint tournamentId, address organizer, string tournamentURI);
    event LockPrizeToken(uint tournamentId, uint prizeAmount);
    event LockFeeToken(uint tournamentId, uint feeAmount);
    event UnlockPrizeToken(uint tournamentId, uint amount);
    event UnlockFeeToken(uint tournamentId, uint amount);
    event WithdrawFee(uint tournamentId, uint feeBalance);
    event PrizePaid(uint tournamentId, address account, uint PrizeAmount);
    event ReturnFee(uint tournamentId, address account, uint feeAmount);
    event ReturnPrize(uint tournamentId, address account, uint PrizeAmount);
    event CanceledUnlock(uint tournamentId);
    event EndedUnlock(uint tournamentId, address [] _withdrawAddresses);

    constructor(address adminAddr, address _royaltyAddrDev, address _royaltyAddrFlp, string memory _contractURI) {
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddr);
        _setupRole(FACTORY_ROLE, adminAddr);
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrFlp = _royaltyAddrFlp;
        // Set default dev royalty 
        RoyaltyPrizeDev = 5;
        RoyaltyregfeeDev = 5;
        // Set default platform royalty 
        RoyaltyPrizeFlp = 5;
        RoyaltyregfeeFlp = 5;
        // Set default funding setting
        minFundingRate = 100;
        deployer = adminAddr;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyTournament(){
        require(msg.sender == tournamentAddr, "Only tournament contract can call this function");
        _;
    }

    modifier onlyOrganizer(uint _tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(msg.sender == _tournament.organizer, "Only organizer can call this function");
        _;
    }

    function connectTournament(address payable _miracletournament) public onlyAdmin{
        _setupRole(TOURNAMENT_ROLE, _miracletournament);
        miracletournament = MiracleTournament(_miracletournament);
    }

    // Create tournament
    function createTournamentEscrow(uint _tournamentId, uint8 _tournamentType, address _prizeToken, address _feeToken, uint _prizeAmount, uint _joinFee, uint256[] memory _regStartEndTime, uint256[] memory _FundStartEndTime, uint256[] memory _prizeAmountArray, string memory _tournamentURI, uint _playerLimit) external {
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
        
        miracletournament.createTournament(_tournamentId, _tournamentType, msg.sender, _regStartEndTime[0], _regStartEndTime[1], _prizeAmountArray.length, _playerLimit);
        createFunding(_tournamentId, _FundStartEndTime[0], _FundStartEndTime[1], _prizeToken, _prizeAmount);
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

    function endedTournament(uint _tournamentId, address[] memory _withdrawAddresses) external onlyTournament {
        _EndedUnlockTransfer(_tournamentId, _withdrawAddresses);
    }

    function canceledTournament(uint _tournamentId, address[] memory _entryPlayers) external onlyTournament{
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
            emit LockFeeToken(_tournamentId, _tournament.joinFee);
        }
        miracletournament.register(_tournamentId, msg.sender);
    }

    function _transferToken(IERC20 token, address to, uint256 amount) internal {
        if (amount > 0) {
            token.transfer(to, amount);
        }
    }

    // Tournament CANCEL unlock PRIZE and entry fee (auto transfer)
    function _CanceledUnlockTransfer(uint _tournamentId, address[] memory _players) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Set tournament status canceled
        _tournament.tournamentCanceled = true;
        if(_tournament.joinFee>0){
            // Transfer entry fee to users
            for (uint256 i = 0; i < _players.length; i++) {
                _tournament.feeToken.transfer(_players[i], _tournament.joinFee);
            }
            _tournament.prizeToken.transfer(_tournament.organizer, _tournament.prizeAmount);
        }
        emit CanceledUnlock(_tournamentId);
    }

    // Tournament END unlock PRIZE and entry fee (auto transfer)
    function _EndedUnlockTransfer(uint _tournamentId, address[] memory _winner) internal {
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

        // Calculate FEE and transfer
        uint256 _feeAmount = _tournament.feeBalance;
        uint256 _feeDev = (_feeAmount * RoyaltyregfeeDev) / 100;
        uint256 _feeFlp = (_feeAmount * RoyaltyregfeeFlp) / 100;
        uint256 _feeOrg = _feeAmount - (_feeDev + _feeFlp);
        _transferToken(_tournament.feeToken, royaltyAddrDev, _feeDev);
        _transferToken(_tournament.feeToken, royaltyAddrFlp, _feeFlp);
        _transferToken(_tournament.feeToken, _tournament.organizer, _feeOrg);

        emit EndedUnlock(_tournamentId, _winner);
    }


    function fundToTournament(uint _tournamentId, uint256 _amount) external {
        Funding storage funding = fundingMapping[_tournamentId];
        require(block.timestamp >= funding.startTime && block.timestamp <= funding.endTime, "Funding not active");
        require(funding.totalFunded + _amount <= funding.fundingGoal, "Funding amount exceeds goal");
        require(IERC20(funding.fundingToken).allowance(msg.sender, address(this)) >= _amount, "Allowance is not sufficient.");
        require(funding.fundingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        if (funding.contributions[msg.sender] == 0) {
            funding.contributors.push(msg.sender);
        }
        funding.contributions[msg.sender] += _amount;
        funding.totalFunded += _amount;
    }

    function endFunding(uint _tournamentId) external onlyAdmin {
        Funding storage funding = fundingMapping[_tournamentId];
        require(block.timestamp > funding.endTime, "Funding period not ended");
        funding.fundingActive = false;

        if (funding.totalFunded < funding.fundingGoal * minFundingRate / 100) {
            for (uint i = 0; i < funding.contributors.length; i++) {
                address contributor = funding.contributors[i];
                uint256 amount = funding.contributions[contributor];
                funding.fundingToken.transfer(contributor, amount);
            }
        } else {
            Tournament storage tournament = tournamentMapping[_tournamentId];
            tournament.prizeAmount = funding.totalFunded;
        }
    }

    // Set royalty address
    function setRoyaltyDevAddress(address _royaltyAddr) external onlyAdmin{
        royaltyAddrDev = _royaltyAddr;
    }

    function setRoyaltyFlpAddress(address _royaltyAddr) external onlyAdmin{
        royaltyAddrFlp = _royaltyAddr;
    }

    // Set prize royalty rate
    function setPrizeRoyaltyDevRate(uint _royaltyRate) external onlyAdmin{
        RoyaltyPrizeDev = _royaltyRate;
    }

    function setPrizeRoyaltyFlpRate(uint _royaltyRate) external onlyAdmin{
        RoyaltyPrizeFlp = _royaltyRate;
    }

    // Set regfee royalty rate
    function setRegfeeRoyaltyDevRate(uint _royaltyRate) external onlyAdmin{
        RoyaltyregfeeDev = _royaltyRate;
    }

    function setRegfeeRoyaltyFlpRate(uint _royaltyRate) external onlyAdmin{
        RoyaltyregfeeFlp = _royaltyRate;
    }

    // Set Funding
    function setMinimumFundingRate(uint _newRate) external onlyAdmin {
        require(_newRate > 0 && _newRate <= 100, "Invalid rate");
        minFundingRate = _newRate;
    }
}