// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "./Miracle-Tournament-R7.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentEscrow V0.7.2                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              .0
                                             
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IERC1155{
    function mintTo(address _to, uint256 _tokenId, string calldata _uri, uint256 _amount) external;
}

interface IERC721{
    
}

contract MiracleTournamentEscrow is ContractMetadata {
    address public deployer;
    address public admin;
    address payable public tournamentAddr;
    //Royalty strring
    uint public RoyaltyPrizeDev;
    uint public RoyaltyregfeeDev;
    uint public RoyaltyPrizeFlp;
    uint public RoyaltyregfeeFlp;
    address public royaltyAddrDev;
    address public royaltyAddrFlp;

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
        admin = adminAddr;
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrFlp = _royaltyAddrFlp;
        // Set default dev royalty 
        RoyaltyPrizeDev = 5;
        RoyaltyregfeeDev = 5;
        // Set default platform royalty 
        RoyaltyPrizeFlp = 5;
        RoyaltyregfeeFlp = 5;
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
        tournamentAddr = _miracletournament;
        miracletournament = MiracleTournament(_miracletournament);
    }

    // Create tournament
    function createTournamentEscrow(uint _tournamentId, uint8 _tournamentType, address _prizeToken, address _feeToken, uint _prizeAmount, uint _joinFee, uint _registerStartTime, uint _registerEndTime, uint256[] memory _prizeAmountArray, string memory _tournamentURI, uint _playerLimit) external {
        require(IERC20(_prizeToken).allowance(msg.sender, address(this)) >= _prizeAmount, "Allowance is not sufficient.");
        require(_prizeAmount <= IERC20(_prizeToken).balanceOf(msg.sender), "Insufficient balance.");
        uint256 totalWithdrawAmount;
        for (uint256 i = 0; i < _prizeAmountArray.length; i++) {
            totalWithdrawAmount += _prizeAmountArray[i];
        }
        require(totalWithdrawAmount == _prizeAmount, "Total withdraw amount must equal prize amount.");

        Tournament storage newTournament = tournamentMapping[_tournamentId];
        require(newTournament.tournamentCreated == false, "Tournament already created.");
        require(IERC20(_prizeToken).transferFrom(msg.sender, address(this), _prizeAmount), "Transfer failed.");

        newTournament.organizer = msg.sender;
        newTournament.prizeToken = IERC20(_prizeToken);
        newTournament.feeToken = IERC20(_feeToken);
        newTournament.prizeAmount = _prizeAmount;
        newTournament.joinFee = _joinFee;
        newTournament.feeBalance = 0;
        newTournament.prizeAmountArray = _prizeAmountArray;
        newTournament.tournamentCreated = true;
        newTournament.tournamentEnded = false;
        newTournament.tournamentCanceled = false;
        newTournament.tournamentURI = _tournamentURI;
        newTournament.PlayersLimit = _playerLimit;
        
        miracletournament.createTournament(_tournamentId, _tournamentType, msg.sender, _registerStartTime, _registerEndTime, _prizeAmountArray.length, _playerLimit);
        emit CreateTournament(_tournamentId, msg.sender, _tournamentURI);
        emit LockPrizeToken(_tournamentId, _prizeAmount);
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
        require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.joinFee), "Transfer failed.");
        require(_tournament.organizer != msg.sender, "Organizers cannot register.");

        _tournament.feeBalance = _tournament.feeBalance + _tournament.joinFee;
        miracletournament.register(_tournamentId, msg.sender);
        emit LockFeeToken(_tournamentId, _tournament.joinFee);
    }

    // Tournament CANCEL unlock PRIZE and entry fee (auto transfer)
    function _CanceledUnlockTransfer(uint _tournamentId, address[] memory _players) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Set tournament status canceled
        _tournament.tournamentCanceled = true;
        // Transfer entry fee to users
        for (uint256 i = 0; i < _players.length; i++) {
            _tournament.feeToken.transfer(_players[i], _tournament.joinFee);
        }
        _tournament.prizeToken.transfer(_tournament.organizer, _tournament.prizeAmount);
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

        if (_prizeAmount == 0) {
            continue;
        }

        uint256 _prizeFeeDev = (_prizeAmount * RoyaltyPrizeDev) / 100;
        uint256 _prizeFeeFlp = (_prizeAmount * RoyaltyPrizeFlp) / 100;
        uint256 _prizeUser = _prizeAmount - (_prizeFeeDev + _prizeFeeFlp);
        
        _tournament.prizeToken.transfer(royaltyAddrDev, _prizeFeeDev);
        _tournament.prizeToken.transfer(royaltyAddrFlp, _prizeFeeFlp);
        _tournament.prizeToken.transfer(_winner[i], _prizeUser);
    }

        // Transfer entry fee
        uint256 _feeAmount = _tournament.feeBalance;
        uint256 _feeFeeDev = (_feeAmount * RoyaltyregfeeDev) / 100;
        uint256 _feeFeeFlp = (_feeAmount * RoyaltyregfeeFlp) / 100;
        uint256 _feeOrg = _feeAmount - (_feeFeeDev + _feeFeeFlp);
        _tournament.feeToken.transfer(royaltyAddrDev, _feeFeeDev);
        _tournament.feeToken.transfer(royaltyAddrFlp, _feeFeeFlp);
        _tournament.feeToken.transfer(_tournament.organizer, _feeOrg);

        emit EndedUnlock(_tournamentId, _winner);
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
}