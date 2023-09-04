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
//   TournamentEscrow V0.5.0

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

    uint public RoyaltyPrizeDev; // Royalty rate
    uint public RoyaltyregfeeDev; // Royalty rate
    uint public RoyaltyPrizeFlp; // Royalty rate
    uint public RoyaltyregfeeFlp; // Royalty rate
    
    address public royaltyAddrDev;
    address public royaltyAddrFlp;
    
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
        mapping (address => uint256) playersWithdrawablePrize;
        mapping (address => uint256) playersWithdrawableFee;
        bool tournamentCreated;
        bool tournamentEnded;
        bool tournamentCanceled;
        string tournamentURI;
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

    constructor(address adminAddr, address _royaltyAddrDev, address _royaltyAddrFlp, IERC1155 _NexusPointEdition, uint _NexusPointID) {
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
        NexusPointEdition = _NexusPointEdition;
        NexusPointID = _NexusPointID;
        _setupContractURI("ipfs://QmZkMS2i5fLF8f8z48JrXUQNWo6br9MwzjeWRjvGwHP1ua/MiracleBingoEscrowR3.json");
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

    function endedTournament(uint _tournamentId, address[] memory _withdrawAddresses) external onlyTournament {
        _EndedUnlock(_tournamentId, _withdrawAddresses);
    }

    function canceledTournament(uint _tournamentId, address[] memory _withdrawAddresses) external onlyTournament{
        _CanceledUnlock(_tournamentId, _withdrawAddresses);
    }

    // The USERS sign up for the tournament.
    function register(uint _tournamentId) external {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.joinFee, "Allowance is not sufficient.");
        require(_tournament.joinFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.joinFee), "Transfer failed.");
        require(_tournament.organizer != msg.sender, "Organizers cannot register.");
        _tournament.feeBalance = _tournament.feeBalance + _tournament.joinFee;
        miracletournament.register(_tournamentId, msg.sender);
        //Mint Nexus Point
        IERC1155(NexusPointEdition).mintTo(msg.sender, NexusPointID, "ipfs://bafybeicpoasyeqqikyongxofdqafflfshyrp343gaonsft7dw4djs7fsce/0", 1);
        emit LockFeeToken(_tournamentId, _tournament.joinFee);
    }

    //The tournament END and the ORGANIZER withdraws the entry fee.
    function feeWithdraw(uint _tournamentId) external onlyOrganizer(_tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");

        IERC20 token = _tournament.feeToken;
        uint256 totalAmount = _tournament.feeBalance;
        uint256 royaltyAmountDev = ((totalAmount * RoyaltyregfeeDev) / 100);
        uint256 royaltyAmountFlp = ((totalAmount * RoyaltyregfeeFlp) / 100);
        
        uint256 regfeeAmount = totalAmount - (royaltyAmountDev + royaltyAmountFlp);
        require(token.transfer(royaltyAddrDev, royaltyAmountDev), "Transfer failed.");
        require(token.transfer(royaltyAddrFlp, royaltyAmountFlp), "Transfer failed.");
        require(token.transfer(_tournament.organizer, regfeeAmount), "Transfer failed.");
        _tournament.feeBalance = 0;
        
        emit WithdrawFee(_tournamentId, totalAmount);
    }

    // The tournament END and the WINNER withdraws the prize token.
    function prizeWithdraw(uint _tournamentId) external {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");
        require(_tournament.playersWithdrawablePrize[msg.sender] > 0, "There is no prize token to be paid to you.");
        
        IERC20 token = _tournament.prizeToken;
        uint256 totalAmount = _tournament.playersWithdrawablePrize[msg.sender];
        uint256 royaltyAmountDev = ((totalAmount * RoyaltyPrizeDev) / 100);
        uint256 royaltyAmountFlp = ((totalAmount * RoyaltyPrizeFlp) / 100);
        uint256 userPrizeAmount = totalAmount - (royaltyAmountDev + royaltyAmountFlp);
        require(token.transfer(royaltyAddrDev, royaltyAmountDev), "Transfer failed.");
        require(token.transfer(royaltyAddrFlp, royaltyAmountFlp), "Transfer failed.");
        require(token.transfer(msg.sender, userPrizeAmount), "Transfer failed.");
        _tournament.playersWithdrawablePrize[msg.sender] = 0;

        emit PrizePaid(_tournamentId, msg.sender, totalAmount);
    }

    // The tournament CANCEL and the ORGANIZER withdraw the prize token.
    function cancelPrizeWithdraw(uint _tournamentId) external onlyOrganizer(_tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentCanceled, "Tournament has not canceled");

        IERC20 token = _tournament.prizeToken;
        uint256 withdrawAmount = _tournament.playersWithdrawablePrize[_tournament.organizer];
        require(token.transfer(msg.sender, withdrawAmount), "Transfer failed.");
        _tournament.playersWithdrawablePrize[_tournament.organizer] = 0;
        
        emit ReturnPrize(_tournamentId, msg.sender, withdrawAmount);
    }

    // The tournament CANCEL and the USERS withdrawn entry fee.
    function cancelRegFeeWithdraw(uint _tournamentId) external {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentCanceled, "Tournament has not canceled");
        require(_tournament.playersWithdrawableFee[msg.sender] > 0, "There is no prize token to be paid to you.");

        IERC20 token = _tournament.feeToken;
        uint256 withdrawAmount = _tournament.playersWithdrawableFee[msg.sender];
        require(token.transfer(msg.sender, withdrawAmount), "Transfer failed.");
        _tournament.playersWithdrawableFee[msg.sender] = 0;

        emit ReturnFee(_tournamentId, msg.sender, withdrawAmount);
    }

    // Tournament cancel unlock prize and entry fee
    function _CanceledUnlock(uint _tournamentId, address[] memory _withdrawAddresses) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Set tournament status canceled
        _tournament.tournamentCanceled = true;
        // Set users entry fee return
        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.playersWithdrawableFee[_withdrawAddresses[i]] = _tournament.joinFee;
        }
        _tournament.playersWithdrawablePrize[_tournament.organizer] = _tournament.prizeAmount;
        emit CanceledUnlock(_tournamentId);
    }

    // Tournament end unlock prize and entry fee
    function _EndedUnlock(uint _tournamentId, address[] memory _withdrawAddresses) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        // Set tournament status ended
        _tournament.tournamentEnded = true;

        uint256[] memory _prizeAmountArray = _tournament.prizeAmountArray;
        require(_withdrawAddresses.length == _prizeAmountArray.length, "Arrays must be the same length.");
        // Set winner prize amount
        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.playersWithdrawablePrize[_withdrawAddresses[i]] = _prizeAmountArray[i];
        }
        // Set users entry fee to org
        _tournament.playersWithdrawableFee[_tournament.organizer] = _tournament.feeBalance;

        emit EndedUnlock(_tournamentId, _withdrawAddresses);
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

    function withdrawablePrize(uint _tournamentId, address player) external view returns(uint _amount) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.playersWithdrawablePrize[player];
    }

    function withdrawableFee(uint _tournamentId, address player) external view returns(uint _amount) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.playersWithdrawableFee[player];
    }

}