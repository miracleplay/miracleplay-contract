// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

import "./Miracle-Tournament-R3.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentEscrow V0.3.0

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
    //Developer Royalty
    uint public PrizeRateDev;
    uint public regfeeRateDev;
    address public royaltyAddrDev;
    //Platform Royalty
    uint public PrizeRatePlf;
    uint public regfeeRatePlf;
    address public royaltyAddrPlf;
    
    IERC1155 public NexusPointEdition;
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

    constructor(address adminAddr, address _royaltyAddrDev, address _royaltyAddrPlf, IERC1155 _NexusPointEdition) {
        admin = adminAddr;
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrPlf = _royaltyAddrPlf;
        PrizeRateDev = 5;
        regfeeRateDev = 5;
        PrizeRatePlf = 5;
        regfeeRatePlf = 5;
        deployer = adminAddr;
        NexusPointEdition = _NexusPointEdition;
        _setupContractURI("ipfs://QmTx1v2sdMVePkw3zZHdjGeDpwy7DE8rRMvw7p2eG6GqgE/BublleShooterEscrowR3.json");
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


    //Create Tournament and user join
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
        IERC1155(NexusPointEdition).mintTo(msg.sender, 0, "ipfs://QmRhpuNgyUMJ2bsVEiVySTbj8DeLfax2QJmWR34pnvAzY8/0", 1);
        emit LockFeeToken(_tournamentId, _tournament.joinFee);
    }

    //End tournament - unlock reg fee and prize
    function unlockRegFee(uint _tournamentId) external onlyTournament {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentEnded = true;
        feeRoyaltyPaiy(_tournamentId);

        emit UnlockFeeToken(_tournamentId, _tournament.feeBalance);
    }

    function feeRoyaltyPaiy(uint256 _tournamentId) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        //Royalty
        IERC20 token = _tournament.feeToken;
        uint256 totalAmount = _tournament.feeBalance;
        uint256 royaltyAmountDev = ((totalAmount * regfeeRateDev) / 100);
        uint256 royaltyAmountPlf = ((totalAmount * regfeeRatePlf) / 100);
        uint256 regfeeAmount = totalAmount - (royaltyAmountDev + royaltyAmountPlf);
        require(token.transfer(royaltyAddrDev, royaltyAmountDev), "Transfer to dev failed.");
        require(token.transfer(royaltyAddrDev, royaltyAmountPlf), "Transfer to plf failed.");
        _tournament.feeBalance = regfeeAmount;
    }

    function unlockPrize(uint _tournamentId, address[] memory _withdrawAddresses) external onlyTournament {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        uint256[] memory _prizeAmountArray = _tournament.prizeAmountArray;
        uint256 _prizeTotalAmount = _tournament.prizeAmount;
        
        require(_withdrawAddresses.length == _prizeAmountArray.length, "Arrays must be the same length.");

        uint256 totalAmountDev = ((_prizeTotalAmount * PrizeRateDev) / 100);
        uint256 totalAmountPlf = ((_prizeTotalAmount * PrizeRatePlf) / 100);
        IERC20 token = _tournament.prizeToken;

        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            uint256 _totalAmount = _prizeAmountArray[i];
            uint256 royaltyAmountDev = ((_totalAmount * PrizeRateDev) / 100);
            uint256 royaltyAmountPlf = ((_totalAmount * PrizeRatePlf) / 100);
            uint256 prizeAmount = _totalAmount - (royaltyAmountDev + royaltyAmountPlf);
            _tournament.playersWithdrawableAmount[_withdrawAddresses[i]] = prizeAmount;
        }

        require(token.transfer(royaltyAddrDev, totalAmountDev), "Transfer failed.");
        require(token.transfer(royaltyAddrPlf, totalAmountPlf), "Transfer failed.");

        _tournament.tournamentEnded = true;
        emit UnlockPrizeToken(_tournamentId, _withdrawAddresses);
    }

    function prizeRoyaltyPaiyDev(uint256 _tournamentId) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        //Royalty For Dev
    }

    //Cancel tournament and host/user withdraw
    function feeWithdraw(uint _tournamentId) public onlyOrganizer(_tournamentId){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");

        IERC20 token = _tournament.feeToken;
        uint256 regfeeAmount = _tournament.feeBalance;
        require(token.transfer(_tournament.organizer, regfeeAmount), "Transfer failed.");
        _tournament.feeBalance = 0;
        
        emit WithdrawFee(_tournamentId, regfeeAmount);
    }

    function prizeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.tournamentEnded, "Tournament has not ended yet");
        require(_tournament.playersWithdrawableAmount[msg.sender] > 0, "There is no prize token to be paid to you.");
        
        IERC20 token = _tournament.prizeToken;
        uint256 userPrizeAmount = _tournament.playersWithdrawableAmount[msg.sender];
        require(token.transfer(msg.sender, userPrizeAmount), "Transfer failed.");
        _tournament.playersWithdrawableAmount[msg.sender] = 0;

        emit PrizePaid(_tournamentId, msg.sender, userPrizeAmount);
    }

    function canceledTournament(uint _tournamentId, address[] memory _withdrawAddresses) external onlyTournament{
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        _tournament.tournamentCanceled = true;
        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.playersWithdrawableAmount[_withdrawAddresses[i]] = _tournament.joinFee;
        }

        emit CanceledTournament(_tournamentId);
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

    function setRoyaltyAddressDev(address _royaltyAddr) public onlyAdmin{
        royaltyAddrDev = _royaltyAddr;
    }

    function setPrizeRoyaltyRateDev(uint _royaltyRate) public onlyAdmin{
        PrizeRateDev = _royaltyRate;
    }

    function setRegfeeRoyaltyRateDev(uint _royaltyRate) public onlyAdmin{
        regfeeRateDev = _royaltyRate;
    }

    function setRoyaltyAddressPlf(address _royaltyAddr) public onlyAdmin{
        royaltyAddrPlf = _royaltyAddr;
    }

    function setPrizeRoyaltyRatePlf(uint _royaltyRate) public onlyAdmin{
        PrizeRatePlf = _royaltyRate;
    }

    function setRegfeeRoyaltyRatePlf(uint _royaltyRate) public onlyAdmin{
        regfeeRatePlf = _royaltyRate;
    }

    function availablePrize(uint _tournamentId, address player) external view returns(uint _amount) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.playersWithdrawableAmount[player];
    }

}