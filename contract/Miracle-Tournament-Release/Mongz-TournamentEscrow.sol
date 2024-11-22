// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MongzTournamentEscrow V0.9.0 Tournament
pragma solidity ^0.8.22;

import "./Mongz-Tournament.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract MongzTournamentEscrow is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address public admin;
    // Royalty setting
    uint public RoyaltyPrizeDev;
    uint public RoyaltyRegfeeDev;
    uint public RoyaltyPrizeFlp;
    uint public RoyaltyRegfeeFlp;
    uint public RoyaltyPrizeReferee;
    uint public RoyaltyRegfeeReferee;
    address public royaltyAddrDev;
    address public royaltyAddrFlp;

    // Permissions
    bytes32 public constant TOURNAMENT_ROLE = keccak256("TOURNAMENT_ROLE");
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    MongzTournament public mongztournament;

    struct Tournament {
        address organizer;
        bool isSponsored;
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
        address[] referees;
        uint PlayersLimit;
    }
    mapping(uint => Tournament) public tournamentMapping;

    event UnlockPrize(uint tournamentId, uint amount);
    event UnlockFee(uint tournamentId, uint amount);

    constructor(address _royaltyAddrDev, address _royaltyAddrFlp,address _mongztournament,string memory _contractURI) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrFlp = _royaltyAddrFlp;
        // Set default dev royalty
        RoyaltyPrizeDev = 5;
        RoyaltyRegfeeDev = 5;
        // Set default platform royalty 
        RoyaltyPrizeFlp = 5;
        RoyaltyRegfeeFlp = 5;
        // Set Referee user royalty
        RoyaltyPrizeReferee = 5;
        RoyaltyRegfeeReferee = 0;
        deployer = msg.sender;
        // Set tournament contract
        _setupRole(TOURNAMENT_ROLE, _mongztournament);
        mongztournament = MongzTournament(_mongztournament);
        _setupContractURI(_contractURI);
        // Set default tournament admin
        _setupRole(FACTORY_ROLE, msg.sender); // Deployer tournament admin
    }

    event EscrowCreated(uint tournamentId, address organizer);
    event Registration(uint tournamentId, address user);
    event KickPlayer(uint tournamentId, address user);
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

    function connectTournament(address _mongztournament) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setupRole(TOURNAMENT_ROLE, _mongztournament);
        mongztournament = MongzTournament(_mongztournament);
    }

    // Create tournament
    function createTournamentEscrow(uint256[] memory _tournamentInfo, bool _isFunding, address[] memory _prizeFeeToken, uint256[] memory _prizeFeeAmount, uint256[] memory _regStartEndTime, uint256[] memory _FundStartEndTime, uint256[] memory _prizeAmountArray, string memory _tournamentURI, uint _playerLimit, address[] memory _referees) external {
        // Escrow -> Tournament
        // Create Tournament Pamameter
        // _tournamentInfo 0-TournamentId, 1-TournamentTier
        require(_isFunding == false, "Funding is not supported.");
        require(_FundStartEndTime[0] == _regStartEndTime[0] && _FundStartEndTime[1] == _regStartEndTime[1], "Funding is not supported.");
        require(_regStartEndTime[0] < _regStartEndTime[1], "Invalid join tournament time range");
        uint256 totalWithdrawAmount;
        for (uint256 i = 0; i < _prizeAmountArray.length; i++) {
            totalWithdrawAmount += _prizeAmountArray[i];
        }
        require(totalWithdrawAmount == _prizeFeeAmount[0], "Total prize amount must equal prize amount.");
        
        Tournament storage newTournament = tournamentMapping[_tournamentInfo[0]];
        require(newTournament.tournamentCreated == false, "Tournament already created.");

        newTournament.organizer = msg.sender;
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
        newTournament.referees = _referees;
        newTournament.PlayersLimit = _playerLimit;
        mongztournament.createTournament(_tournamentInfo[0], msg.sender, _regStartEndTime[0], _regStartEndTime[1], _prizeAmountArray.length, _playerLimit);

        require(IERC20(_prizeFeeToken[0]).transferFrom(msg.sender, address(this), _prizeFeeAmount[0]), "Transfer failed.");
        
        emit EscrowCreated(_tournamentInfo[0], msg.sender);
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

        if(_tournament.joinFee > 0){
            require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.joinFee), "Transfer failed.");
            _tournament.feeBalance = _tournament.feeBalance + _tournament.joinFee;
        }
        
        mongztournament.register(_tournamentId, msg.sender);
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

    function _EndedUnlockFee(uint _tournamentId) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Calculate join fee and transfer
        uint256 _feeAmount = _tournament.feeBalance;
        uint256 _feeDev = (_feeAmount * RoyaltyRegfeeDev) / 100;
        uint256 _feeFlp = (_feeAmount * RoyaltyRegfeeFlp) / 100;

        uint256 _feeOrg = _feeAmount - (_feeDev + _feeFlp);
        _transferToken(_tournament.feeToken, royaltyAddrDev, _feeDev);
        _transferToken(_tournament.feeToken, royaltyAddrFlp, _feeFlp);
        _transferToken(_tournament.feeToken, _tournament.organizer, _feeOrg);

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

                if (_tournament.referees.length > 0 && _tournament.referees[0] != address(0)) {
                    uint256 _totalRefereePrize = (_prizeAmount * RoyaltyPrizeReferee) / 100; // 00% of prize amount for Referees
                    uint256 _prizePerReferee = _totalRefereePrize / _tournament.referees.length;
                    // Transfer prize to each Referee
                    for (uint256 j = 0; j < _tournament.referees.length; j++) {
                        _transferToken(_tournament.prizeToken, _tournament.referees[j], _prizePerReferee);
                    }
                    _prizeUser -= _totalRefereePrize; // Adjust user prize after Referees' distribution
                }
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

        if(_tournament.prizeAmount > 0){
            // Transfer prize to org
            _tournament.prizeToken.transfer(_tournament.organizer, _tournament.prizeAmount);
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

    function setPrizeRoyaltyRefRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyPrizeReferee = _royaltyRate;
    }

    // Set regfee royalty rate
    function setRegfeeRoyaltyDevRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyRegfeeDev = _royaltyRate;
    }

    function setRegfeeRoyaltyFlpRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyRegfeeFlp = _royaltyRate;
    }

    function setRegfeeRoyaltyRefRate(uint _royaltyRate) external onlyRole(DEFAULT_ADMIN_ROLE){
        RoyaltyRegfeeReferee = _royaltyRate;
    }
}