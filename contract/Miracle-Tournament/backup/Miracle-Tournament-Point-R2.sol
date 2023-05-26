// SPDX-License-Identifier: UNLICENSED

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PointTournament {
    struct Player {
        uint id;
        address payable account;
        uint score;
        bool isRegistered;
        uint rank;
    }

    Player[] public players;
    mapping(address => uint) public playerIdByAccount;
    mapping(uint => address) public rankToAccount;
    mapping(address => uint) public accountToRank;
    address payable public organizer;
    IERC20 public token;
    uint public registrationFee;

    uint public registerStartTime;
    uint public registerEndTime;
    uint public tournamentStartTime;
    uint public tournamentEndTime;
    bool public tournamentEnded;

    string public tournamentURI;

    event Registered(address account);
    event ScoreUpdated(address account, uint score);
    event TournamentEnded();

    modifier onlyOrganizer() {
        require(msg.sender == organizer, "Only organizer can call this function");
        _;
    }

    modifier registrationOpen() {
        require(block.timestamp >= registerStartTime, "Registration has not started yet");
        require(block.timestamp <= registerEndTime, "Registration deadline passed");
        _;
    }

    modifier tournamentNotStarted() {
        require(block.timestamp < tournamentEndTime, "Tournament has already started");
        require(block.timestamp > tournamentStartTime, "Tournament is not start");
        _;
    }

    modifier tournamentEndedOrNotStarted() {
        require(tournamentEnded || block.timestamp < tournamentEndTime, "Tournament has ended");
        _;
    }

    constructor(
        uint _registerStartTime, 
        uint _registerEndTime, 
        uint _tournamentStartTime, 
        uint _tournamentEndTime, 
        string memory _tournamentURI,
        address _tokenAddress,
        uint _registrationFee
    ) {
        organizer = payable(msg.sender);
        registerStartTime = _registerStartTime;
        registerEndTime = _registerEndTime;
        tournamentStartTime = _tournamentStartTime;
        tournamentEndTime = _tournamentEndTime;
        tournamentURI = _tournamentURI;
        token = IERC20(_tokenAddress);
        registrationFee = _registrationFee;
    }

    function register() public registrationOpen {
        require(block.timestamp >= registerStartTime, "Registration has not started yet");
        require(block.timestamp <= registerEndTime, "Registration deadline passed");
        uint allowance = token.allowance(msg.sender, address(this));
        require(allowance >= registrationFee, "Contract is not authorized to transfer tokens on behalf of the sender");
        
        bool isRegistered = false;
        for (uint i = 0; i < players.length; i++) {
            if (players[i].account == msg.sender) {
                isRegistered = true;
                break;
            }
        }
        require(!isRegistered, "Player already registered");

        uint playerId = players.length;

        Player memory player = Player({
            id: playerId,
            account: payable(msg.sender),
            score: 0,
            isRegistered: true,
            rank: 0
        });

        players.push(player);
        playerIdByAccount[msg.sender] = playerId;

        token.transferFrom(msg.sender, address(this), registrationFee);

        emit Registered(msg.sender);
    }

    function updateScore(address _account, uint _score) public onlyOrganizer tournamentNotStarted tournamentEndedOrNotStarted {
        require(playerIdByAccount[_account] > 0, "Player not registered");
        Player storage _player = players[playerIdByAccount[_account]];

        _player.score += _score;
        emit ScoreUpdated(_account, _player.score);
    }

    function calculateRanking() public onlyOrganizer {
        require(tournamentEnded, "Tournament has not ended yet");
        uint len = players.length;

        for (uint i = 0; i < len; i++) {
            rankToAccount[i] = players[i].account;
        }

        uint[] memory scores = new uint[](len);
        for (uint i = 0; i < len; i++) {
            scores[i] = players[i].score;
        }

        // sort scores and rearrange the rank mapping
        for (uint i = 0; i < len - 1; i++) {
            for (uint j = i + 1; j < len; j++) {
                if (scores[i] < scores[j]) {
                    uint tempScore = scores[i];
                    scores[i] = scores[j];
                    scores[j] = tempScore;

                    address tempAddr = rankToAccount[i];
                    rankToAccount[i] = rankToAccount[j];
                    rankToAccount[j] = tempAddr;
                }
            }
        }

        for (uint i = 0; i < len; i++) {
            accountToRank[rankToAccount[i]] = i + 1;
        }

        // store the rank and score in the Player struct
        for (uint i = 0; i < len; i++) {
            players[i].score = scores[i];
            players[i].isRegistered = false;
            uint rank = accountToRank[players[i].account];
            players[i] = Player(players[i].id, players[i].account, players[i].score, players[i].isRegistered, rank);
        }
    }

    function endTournament() public onlyOrganizer tournamentNotStarted {
        calculateRanking();
        tournamentEnded = true;
        emit TournamentEnded();
    }
}

