// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "./Miracle-Tournament-Score-G1.sol";
import "./Miracle-ProxyV2.sol";

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentEscrow V0.1.1

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TournamentEscrow {
    address public admin;
    address public tournamentAddr;
    uint public royaltyRate;
    address public royaltyAddr;
    ScoreTournament internal scoretournament;

    struct Tournament {
        address organizer;
        IERC20 prizeToken;
        IERC20 feeToken;
        uint prizeAmount;
        uint registrationFee;
        uint feeBalance;
        uint256[] withdrawAmount;
        mapping (address => uint256) AddrwithdrawAmount;
        bool tournamentEnded;
        bool tournamentCanceled;
    }
    mapping(uint => Tournament) public tournamentMapping;

    event LockPrizeToken(uint tournamentId, uint prizeAmount);
    event LockFeeToken(uint tournamentId, uint feeAmount);
    event UnlockFee(uint tournamentId, uint feeBalance);
    event UnlockPrize(uint tournamentId, address [] _withdrawAddresses);
    event PrizePaid(uint tournamentId, address account, uint PrizeAmount);
    event ReturnFee(uint tournamentId, address account, uint feeAmount);
    event CanceledTournament(uint tournamentId);

    constructor(address adminAddr, address _royaltyAddr) {
        admin = adminAddr;
        royaltyAddr = _royaltyAddr;
        royaltyRate = 5;
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

    function connectTournament(address _scoretournament) public onlyAdmin{
        tournamentAddr = _scoretournament;
        scoretournament = ScoreTournament(_scoretournament);
    }

    function createTournamentEscrow(uint _tournamentId, address _prizeToken, address _feeToken, uint _prizeAmount, uint _registrationFee, uint _registerStartTime, uint _registerEndTime, uint _tournamentStartTime, uint _tournamentEndTime, uint256[] memory _withdrawAmount, string memory _tournamentURI) public {
        require(IERC20(_prizeToken).allowance(msg.sender, address(this)) >= _prizeAmount, "Allowance is not sufficient.");
        require(_prizeAmount <= IERC20(_prizeToken).balanceOf(msg.sender), "Insufficient balance.");
        require(IERC20(_prizeToken).transferFrom(msg.sender, address(this), _prizeAmount), "Transfer failed.");
        uint256 totalWithdrawAmount;
        for (uint256 i = 0; i < _withdrawAmount.length; i++) {
            totalWithdrawAmount += _withdrawAmount[i];
        }
        require(totalWithdrawAmount == _prizeAmount, "Total withdraw amount must equal prize amount.");

        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.organizer = msg.sender;
        newTournament.prizeToken = IERC20(_prizeToken);
        newTournament.feeToken = IERC20(_feeToken);
        newTournament.prizeAmount = _prizeAmount;
        newTournament.registrationFee = _registrationFee;
        newTournament.withdrawAmount = _withdrawAmount;
        newTournament.tournamentEnded = false;
        newTournament.tournamentCanceled = false;
        scoretournament.createTournament(_tournamentId, _registerStartTime, _registerEndTime, _tournamentStartTime, _tournamentEndTime, _withdrawAmount.length, _tournamentURI);
        emit LockPrizeToken(_tournamentId, _prizeAmount);
    }

    function register(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.registrationFee, "Allowance is not sufficient.");
        require(_tournament.registrationFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.registrationFee), "Transfer failed.");
        require(_tournament.organizer != msg.sender, "Organizers cannot apply.");
        _tournament.feeBalance = _tournament.feeBalance + _tournament.registrationFee;
        scoretournament.register(_tournamentId, msg.sender);
        emit LockFeeToken(_tournamentId, _tournament.registrationFee);
    }

    function unlockPrize(uint _tournamentId, address[] memory _withdrawAddresses) public onlyTournament {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentEnded = true;

        uint256[] memory _withdrawAmount = _tournament.withdrawAmount;
        require(_withdrawAddresses.length == _withdrawAmount.length, "Arrays must be the same length.");

        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.AddrwithdrawAmount[_withdrawAddresses[i]] = _withdrawAmount[i];
        }

        emit UnlockPrize(_tournamentId, _withdrawAddresses);
    }

    function unlockRegFee(uint _tournamentId) public onlyTournament {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentEnded = true;

        emit UnlockFee(_tournamentId, _tournament.feeBalance);
    }

    function canceledTournament(uint _tournamentId, address[] memory _withdrawAddresses) public onlyTournament{
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentCanceled = true;
        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.AddrwithdrawAmount[_withdrawAddresses[i]] = _tournament.registrationFee;
        }

        emit CanceledTournament(_tournamentId);
    }

    function feeWithdraw(uint _tournamentId) public onlyOrganizer(_tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");

        IERC20 token = _tournament.feeToken;
        uint256 withdrawAmount = _tournament.feeBalance;
        require(token.transfer(_tournament.organizer, withdrawAmount), "Transfer failed.");
        
        emit UnlockFee(_tournamentId, withdrawAmount);
    }

    function prizeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");
        require(_tournament.AddrwithdrawAmount[msg.sender] > 0, "There is no prize token to be paid to you.");
        
        IERC20 token = _tournament.prizeToken;
        uint256 totalAmount = _tournament.AddrwithdrawAmount[msg.sender];
        uint256 royaltyAmount = ((totalAmount * royaltyRate) / 100);
        uint256 userPrizeAmount = totalAmount - royaltyAmount;
        require(token.transfer(royaltyAddr, royaltyAmount), "Transfer failed.");
        require(token.transfer(msg.sender, userPrizeAmount), "Transfer failed.");
        _tournament.AddrwithdrawAmount[msg.sender] = 0;

        emit PrizePaid(_tournamentId, msg.sender, totalAmount);
    }

    function CancelPrizeWithdraw(uint _tournamentId) public onlyOrganizer(_tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentCanceled, "Tournament has not canceled");

        IERC20 token = _tournament.prizeToken;
        uint256 withdrawAmount = _tournament.prizeAmount;
        require(token.transfer(msg.sender, withdrawAmount), "Transfer failed.");
    }

    function CancelRegFeeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentCanceled, "Tournament has not canceled");
        require(_tournament.AddrwithdrawAmount[msg.sender] > 0, "There is no prize token to be paid to you.");

        IERC20 token = _tournament.feeToken;
        uint256 withdrawAmount = _tournament.AddrwithdrawAmount[msg.sender];
        require(token.transfer(msg.sender, withdrawAmount), "Transfer failed.");
        _tournament.AddrwithdrawAmount[msg.sender] = 0;

        emit ReturnFee(_tournamentId, msg.sender, withdrawAmount);
    }

    function emergencyWithdraw(uint _tournamentId) public onlyAdmin{
        Tournament storage _tournament = tournamentMapping[_tournamentId];

        IERC20 feeToken = _tournament.feeToken;
        uint256 withdrawAmountFee = _tournament.feeBalance;
        require(feeToken.transfer(admin, withdrawAmountFee), "Transfer failed.");
        _tournament.feeBalance = 0;

        IERC20 prizeToken = _tournament.prizeToken;
        uint256 withdrawAmountPrize = _tournament.prizeAmount;
        require(prizeToken.transfer(admin, withdrawAmountPrize), "Transfer failed.");
        _tournament.prizeAmount = 0;
    }

    function availablePrize(uint _tournamentId, address player) external view returns(uint _amount) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.AddrwithdrawAmount[player];
    }

}
