// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "./Miracle-Tournament-R2.sol";
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

interface IERC1155{
    function mintTo(address _to, uint256 _tokenId, string calldata _uri, uint256 _amount) external;
}

contract MiracleTournamentEscrow is ContractMetadata {
    address public deployer;
    address public admin;
    address payable public tournamentAddr;
    uint public PrizeRoyaltyRate;
    uint public regfeeRoyaltyRate;
    address public royaltyAddr;
    IERC1155 public NexusPointEdition;
    uint public NexusPointID;

    MiracleTournament internal miracletournament;

    struct Tournament {
        address organizer;
        IERC20 prizeToken;
        IERC20 feeToken;
        uint prizeAmount;
        uint joinFee;
        uint feeBalance;
        uint256[] prizeAmountArray;
        mapping (address => uint256) playersWithdrawableAmount;
        bool tournamentCreated;
        bool tournamentEnded;
        bool tournamentCanceled;
        string tournamentURI;
    }
    mapping(uint => Tournament) public tournamentMapping;

    event CreateTournament(uint tournamentId, address organizer, string tournamentURI);
    event LockPrizeToken(uint tournamentId, uint prizeAmount);
    event LockFeeToken(uint tournamentId, uint feeAmount);
    event UnlockPrizeToken(uint tournamentId, address [] _withdrawAddresses);
    event UnlockFeeToken(uint tournamentId, uint feeBalance);
    event WithdrawFee(uint tournamentId, uint feeBalance);
    event PrizePaid(uint tournamentId, address account, uint PrizeAmount);
    event ReturnFee(uint tournamentId, address account, uint feeAmount);
    event ReturnPrize(uint tournamentId, address account, uint PrizeAmount);
    event CanceledTournament(uint tournamentId);

    constructor(address adminAddr, address _royaltyAddr, IERC1155 _NexusPointEdition, uint _NexusPointID) {
        admin = adminAddr;
        royaltyAddr = _royaltyAddr;
        PrizeRoyaltyRate = 5;
        regfeeRoyaltyRate = 5;
        deployer = adminAddr;
        NexusPointEdition = _NexusPointEdition;
        NexusPointID = _NexusPointID;
        _setupContractURI("ipfs://QmQ1q8zPkLnZENuBsmB3fJGtmQQ1Mmm5Li6EtEQz6atdeR/MiracleBingoEscrowR3.json");
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

    function createTournamentEscrow(uint _tournamentId, uint8 _tournamentType, address _prizeToken, address _feeToken, uint _prizeAmount, uint _joinFee, uint _registerStartTime, uint _registerEndTime, uint256[] memory _prizeAmountArray, string memory _tournamentURI, uint _playerLimit) public {
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
        
        miracletournament.createTournament(_tournamentId, _tournamentType, msg.sender, _registerStartTime, _registerEndTime, _prizeAmountArray.length, _playerLimit);
        emit CreateTournament(_tournamentId, msg.sender, _tournamentURI);
        emit LockPrizeToken(_tournamentId, _prizeAmount);
    }

    function register(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.joinFee, "Allowance is not sufficient.");
        require(_tournament.joinFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.joinFee), "Transfer failed.");
        require(_tournament.organizer != msg.sender, "Organizers cannot apply.");
        _tournament.feeBalance = _tournament.feeBalance + _tournament.joinFee;
        miracletournament.register(_tournamentId, msg.sender);
        //Mint Nexus Point
        IERC1155(NexusPointEdition).mintTo(msg.sender, NexusPointID, "ipfs://bafybeicpoasyeqqikyongxofdqafflfshyrp343gaonsft7dw4djs7fsce/0", 1);
        emit LockFeeToken(_tournamentId, _tournament.joinFee);
    }

    function unlockPrize(uint _tournamentId, address[] memory _withdrawAddresses) public onlyTournament {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentEnded = true;

        uint256[] memory _prizeAmountArray = _tournament.prizeAmountArray;
        require(_withdrawAddresses.length == _prizeAmountArray.length, "Arrays must be the same length.");

        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.playersWithdrawableAmount[_withdrawAddresses[i]] = _prizeAmountArray[i];
        }

        emit UnlockPrizeToken(_tournamentId, _withdrawAddresses);
    }

    function unlockRegFee(uint _tournamentId) public onlyTournament {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentEnded = true;

        emit UnlockFeeToken(_tournamentId, _tournament.feeBalance);
    }

    function canceledTournament(uint _tournamentId, address[] memory _withdrawAddresses) public onlyTournament{
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentCanceled = true;
        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.playersWithdrawableAmount[_withdrawAddresses[i]] = _tournament.joinFee;
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
        
        emit WithdrawFee(_tournamentId, totalAmount);
    }

    function prizeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");
        require(_tournament.playersWithdrawableAmount[msg.sender] > 0, "There is no prize token to be paid to you.");
        
        IERC20 token = _tournament.prizeToken;
        uint256 totalAmount = _tournament.playersWithdrawableAmount[msg.sender];
        uint256 royaltyAmount = ((totalAmount * PrizeRoyaltyRate) / 100);
        uint256 userPrizeAmount = totalAmount - royaltyAmount;
        require(token.transfer(royaltyAddr, royaltyAmount), "Transfer failed.");
        require(token.transfer(msg.sender, userPrizeAmount), "Transfer failed.");
        _tournament.playersWithdrawableAmount[msg.sender] = 0;

        emit PrizePaid(_tournamentId, msg.sender, totalAmount);
    }

    function cancelPrizeWithdraw(uint _tournamentId) public onlyOrganizer(_tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentCanceled, "Tournament has not canceled");

        IERC20 token = _tournament.prizeToken;
        uint256 withdrawAmount = _tournament.prizeAmount;
        require(token.transfer(msg.sender, withdrawAmount), "Transfer failed.");

        emit ReturnPrize(_tournamentId, msg.sender, withdrawAmount);
    }

    function cancelRegFeeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentCanceled, "Tournament has not canceled");
        require(_tournament.playersWithdrawableAmount[msg.sender] > 0, "There is no prize token to be paid to you.");

        IERC20 token = _tournament.feeToken;
        uint256 withdrawAmount = _tournament.playersWithdrawableAmount[msg.sender];
        require(token.transfer(msg.sender, withdrawAmount), "Transfer failed.");
        _tournament.playersWithdrawableAmount[msg.sender] = 0;

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
        return _tournament.playersWithdrawableAmount[player];
    }

}