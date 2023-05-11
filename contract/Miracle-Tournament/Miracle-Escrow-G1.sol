// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./Miracle-Tournament-Score-G1.sol";

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//       

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TournamentEscrow {
    address public admin;
    address public tournamentAddr;
    ScoreTournament internal scoretournament;

    struct Tournament {
        address organizer;
        IERC20 prizeToken;
        IERC20 feeToken;
        uint prizeAmount;
        uint registrationFee;
        uint feeBalance;
        uint256[] withdrawPercentages;
        mapping (address => uint256) AddrWithdrawPercentages;
    }
    mapping(uint => Tournament) public tournamentMapping;


    constructor(address adminAddr) {
        admin = adminAddr;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyTournament(){
        require(msg.sender == tournamentAddr, "Only tournament contract can call this function");
        _;
    }

    function connectTournament(address _scoretournament) public onlyAdmin{
        tournamentAddr = _scoretournament;
        scoretournament = ScoreTournament(_scoretournament);
    }

    function createTournamentEscrow(uint _tournamentId, address _prizeToken, address _feeToken, uint _prizeAmount, uint _registrationFee, uint _registerStartTime, uint _registerEndTime, uint _tournamentStartTime, uint _tournamentEndTime, uint256[] memory _percentages, string memory _tournamentURI) public {
        require(IERC20(_prizeToken).allowance(msg.sender, address(this)) >= _prizeAmount, "Allowance is not sufficient.");
        require(_prizeAmount <= IERC20(_prizeToken).balanceOf(msg.sender), "Insufficient balance.");
        require(IERC20(_prizeToken).transferFrom(msg.sender, address(this), _prizeAmount), "Transfer failed.");
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.organizer = msg.sender;
        newTournament.prizeToken = IERC20(_prizeToken);
        newTournament.feeToken = IERC20(_feeToken);
        newTournament.prizeAmount = _prizeAmount;
        newTournament.registrationFee = _registrationFee;
        newTournament.withdrawPercentages = _percentages;
        scoretournament.createTournament(_tournamentId, _registerStartTime, _registerEndTime, _tournamentStartTime, _tournamentEndTime, _percentages.length, _tournamentURI);
    }

    function register(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.registrationFee, "Allowance is not sufficient.");
        require(_tournament.registrationFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.registrationFee), "Transfer failed.");
        _tournament.feeBalance = _tournament.feeBalance + _tournament.registrationFee;
        scoretournament.register(_tournamentId);
    }

    function updateWithdrawals(uint _tournamentId, address[] memory _withdrawAddresses) public onlyTournament {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        uint256[] memory _percentages = _tournament.withdrawPercentages;
        require(_withdrawAddresses.length == _percentages.length, "Arrays must be the same length.");

        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.AddrWithdrawPercentages[_withdrawAddresses[i]] = ((_tournament.prizeAmount * _percentages[i])/100);
        }
    }

    function feeWithdraw(uint _tournamentId) public onlyTournament{
        Tournament storage _tournament = tournamentMapping[_tournamentId];

        IERC20 token = _tournament.feeToken;
        uint256 withdrawAmount = _tournament.feeBalance;
        require(token.transferFrom(address(this), _tournament.organizer, withdrawAmount), "Transfer failed.");
    }

    function prizeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.AddrWithdrawPercentages[msg.sender] > 0, "There is no prize token to be paid to you.");

        IERC20 token = _tournament.prizeToken;
        uint256 withdrawAmount = _tournament.AddrWithdrawPercentages[msg.sender];
        require(token.transferFrom(address(this), msg.sender, withdrawAmount), "Transfer failed.");
    }
}
