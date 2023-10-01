// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "./Miracle-Tournament-Old.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentEscrow V0.2.1

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract MiracleTournamentEscrow is ContractMetadata {
    address public deployer;
    address public admin;
    address payable public tournamentAddr;
    uint public PrizeRoyaltyRate;
    uint public regfeeRoyaltyRate;
    address public royaltyAddr;
    MiracleTournament internal miracletournament;

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
        PrizeRoyaltyRate = 5;
        regfeeRoyaltyRate = 5;
        deployer = adminAddr;
        _setupContractURI("ipfs://QmceM9vcPnP11JgCWbPkGoMZPrbEMij98hJytjvRR1L9qN/BubbleShooterEscrow.json");
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

    function createTournamentEscrow(uint _tournamentId, uint8 _tType, address _prizeToken, address _feeToken, uint _prizeAmount, uint _registrationFee, uint _registerStartTime, uint _registerEndTime, uint _tournamentStartTime, uint _tournamentEndTime, uint256[] memory _withdrawAmount, string memory _tournamentURI) public {
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
        miracletournament.createTournament(_tournamentId, _tType, _registerStartTime, _registerEndTime, _tournamentStartTime, _tournamentEndTime, _withdrawAmount.length, _tournamentURI);
        emit LockPrizeToken(_tournamentId, _prizeAmount);
    }

    function register(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.registrationFee, "Allowance is not sufficient.");
        require(_tournament.registrationFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.registrationFee), "Transfer failed.");
        require(_tournament.organizer != msg.sender, "Organizers cannot apply.");
        _tournament.feeBalance = _tournament.feeBalance + _tournament.registrationFee;
        miracletournament.register(_tournamentId, msg.sender);
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
        uint256 totalAmount = _tournament.feeBalance;
        uint256 royaltyAmount = ((totalAmount * regfeeRoyaltyRate) / 100);
        uint256 regfeeAmount = totalAmount - royaltyAmount;
        require(token.transfer(royaltyAddr, royaltyAmount), "Transfer failed.");
        require(token.transfer(_tournament.organizer, regfeeAmount), "Transfer failed.");
        _tournament.feeBalance = 0;
        
        emit UnlockFee(_tournamentId, totalAmount);
    }

    function prizeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");
        require(_tournament.AddrwithdrawAmount[msg.sender] > 0, "There is no prize token to be paid to you.");
        
        IERC20 token = _tournament.prizeToken;
        uint256 totalAmount = _tournament.AddrwithdrawAmount[msg.sender];
        uint256 royaltyAmount = ((totalAmount * PrizeRoyaltyRate) / 100);
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

    function setRoyaltyAddress(address _royaltyAddr) public onlyAdmin{
        royaltyAddr = _royaltyAddr;
    }

    function setPrizeRoyaltyRate(uint _royaltyRate) public onlyAdmin{
        PrizeRoyaltyRate = _royaltyRate;
    }

    function setRegfeeRoyaltyRate(uint _royaltyRate) public onlyAdmin{
        regfeeRoyaltyRate = _royaltyRate;
    }

    function availablePrize(uint _tournamentId, address player) external view returns(uint _amount) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.AddrwithdrawAmount[player];
    }

}
