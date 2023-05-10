// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

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

contract TokenEscrow {
    address public admin;

    struct Tournament {
        address organizer;
        IERC20 prizeToken;
        IERC20 feeToken;
        uint prizeAmount;
        uint registrationFee;
        uint feeBalance;
        mapping (address => uint256) withdrawPercentages;
        mapping (address => uint256) withdrawAmounts;
    }
    mapping(uint => Tournament) public tournamentMapping;


    constructor(address adminAddr) {
        admin = adminAddr;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    function createTournamentEscrow(uint _tournamentId, address _prizeToken, address _feeToken, uint _prizeAmount, uint _registrationFee) public {
        require(IERC20(_prizeToken).allowance(msg.sender, address(this)) >= _prizeAmount, "Allowance is not sufficient.");
        require(_prizeAmount <= IERC20(_prizeToken).balanceOf(msg.sender), "Insufficient balance.");
        require(IERC20(_prizeToken).transferFrom(msg.sender, address(this), _prizeAmount), "Transfer failed.");
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.organizer = msg.sender;
        newTournament.prizeToken = IERC20(_prizeToken);
        newTournament.feeToken = IERC20(_feeToken);
        newTournament.prizeAmount = _prizeAmount;
        newTournament.registrationFee = _registrationFee;
    }

    function register(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.feeToken.allowance(msg.sender, address(this)) >= _tournament.registrationFee, "Allowance is not sufficient.");
        require(_tournament.registrationFee <= _tournament.feeToken.balanceOf(msg.sender), "Insufficient balance.");
        require(_tournament.feeToken.transferFrom(msg.sender, address(this), _tournament.registrationFee), "Transfer failed.");
        _tournament.feeBalance = _tournament.feeBalance + _tournament.registrationFee;
    }

    function updateWithdrawals(uint _tournamentId, address[] memory _withdrawAddresses, uint256[] memory _percentages, uint256[] memory _amount) public onlyAdmin {
        require(msg.sender == admin, "Only the admin can update withdrawals.");
        require(_withdrawAddresses.length == _percentages.length, "Arrays must be the same length.");
        
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        for (uint256 i = 0; i < _withdrawAddresses.length; i++) {
            _tournament.withdrawPercentages[_withdrawAddresses[i]] = _percentages[i];
            _tournament.withdrawAmounts[_withdrawAddresses[i]] = _amount[i];
        }
    }

    function feeWithdraw(uint _tournamentId) public {

    }

    function prizeWithdraw(uint _tournamentId) public {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(_tournament.withdrawAmounts[msg.sender] > 0, "There is no prize token to be paid to you.");

        IERC20 token = _tournament.prizeToken;
        uint256 withdrawAmount = _tournament.withdrawAmounts[msg.sender];
        require(token.transferFrom(address(this), msg.sender, withdrawAmount), "Transfer failed.");
    }
}
