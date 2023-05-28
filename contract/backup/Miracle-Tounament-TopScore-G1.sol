// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;    

import "./Miracle-Escrow-G1.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   HighScoreTournament V0.1.3

contract TopScoreTournament is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address payable public EscrowAddr;
    uint[] private OnGoingTournaments;
    uint[] private EndedTournaments;

    struct Player {
        uint id;
        address account;
        uint highscore;
        bool isRegistered;
        uint rank;
    }

    struct Tournament {
        bool registered;
        Player[] players;
        mapping(address => uint) playerIdByAccount;
        mapping(uint => address) rankToAccount;
        mapping(address => uint) accountToRank;
        address organizer;
        uint registerStartTime;
        uint registerEndTime;
        uint tournamentStartTime;
        uint tournamentEndTime;
        uint prizeCount;
        bool tournamentEnded;
        string tournamentURI;
    }

    address admin;
    mapping(uint => Tournament) public tournamentMapping;

    event CreateTournament(uint tournamentId);
    event Registered(uint tournamentId, address account);
    event NewPersonalRecord(uint tournamentId, address account, uint score);
    event TournamentEnded(uint tournamentId);
    event TournamentCanceled(uint tournamentId);

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant ESCROW_ROLE = keccak256("ESCROW_ROLE");

    constructor(address adminAddr) {
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddr);
        _setupRole(FACTORY_ROLE, adminAddr);
        deployer = adminAddr;
        _setupContractURI("ipfs://QmauSBrmFxRppBArjnxm41oWvq4qN8ao72RowCzRZN7aE5/Tournament-TopScore.json");
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    modifier registrationOpen(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp >= tournament.registerStartTime, "Registration has not started yet");
        require(block.timestamp <= tournament.registerEndTime, "Registration deadline passed");
        _;
    }

    modifier tournamentNotStarted(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp < tournament.tournamentEndTime, "This is not the time to proceed with the tournement.");
        require(block.timestamp > tournament.tournamentStartTime, "Tournament is not start");
        _;
    }

    modifier tournamentEndedOrNotStarted(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(tournament.tournamentEnded || block.timestamp < tournament.tournamentEndTime, "Tournament has ended");
        _;
    }

    function setUpdateRole(address _updateAddr) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setupRole(FACTORY_ROLE, _updateAddr);
    }

    function connectEscrow(address payable _escrowAddr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setupRole(ESCROW_ROLE, _escrowAddr);
        EscrowAddr = _escrowAddr;
    }


    function createTournament(uint _tournamentId, uint _registerStartTime, uint _registerEndTime, uint _tournamentStartTime, uint _tournamentEndTime, uint _prizeCount, string memory _tournamentURI) public onlyRole(ESCROW_ROLE) {
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.registered = true;
        newTournament.organizer = payable(msg.sender);
        newTournament.registerStartTime = _registerStartTime;
        newTournament.registerEndTime = _registerEndTime;
        newTournament.tournamentStartTime = _tournamentStartTime;
        newTournament.tournamentEndTime = _tournamentEndTime;
        newTournament.tournamentEnded = false;
        newTournament.prizeCount = _prizeCount;
        newTournament.tournamentURI = _tournamentURI;
        addOnGoingTournament(_tournamentId);

        emit CreateTournament(_tournamentId);
    }

    function register(uint tournamentId, address _player) public payable registrationOpen(tournamentId) onlyRole(ESCROW_ROLE){
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp >= tournament.registerStartTime, "Registration has not started yet");
        require(block.timestamp <= tournament.registerEndTime, "Registration deadline passed");
        uint playerId = tournament.players.length;
        Player memory player = Player({
            id: playerId,
            account: payable(_player),
            highscore: 0,
            isRegistered: true,
            rank: 0
        });

        tournament.players.push(player);
        tournament.playerIdByAccount[_player] = playerId;

        emit Registered(tournamentId, _player);
    }


    function _updateScore(uint tournamentId, address _account, uint _score) internal {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(tournament.players[tournament.playerIdByAccount[_account]].isRegistered, "Player is not registered");

        Player storage _player = tournament.players[tournament.playerIdByAccount[_account]];
        if(_player.highscore < _score){
            _player.highscore = _score;
            emit NewPersonalRecord(tournamentId, _account, _player.highscore);
        }    
    }

    function updateScore(uint tournamentId, address _account, uint[] calldata _score) external onlyRole(FACTORY_ROLE) {
        uint highscore = 0;
        for(uint i = 0; i < _score.length; i++) {
            if(highscore < _score[i]){
                highscore = _score[i];
            }
        }
        _updateScore(tournamentId, _account, highscore);
    }


    function calculateRanking(uint tournamentId) internal {
        Tournament storage tournament = tournamentMapping[tournamentId];
        uint len = tournament.players.length;

        for (uint i = 0; i < len; i++) {
            tournament.rankToAccount[i] = tournament.players[i].account;
        }

        uint[] memory scores = new uint[](len);
        for (uint i = 0; i < len; i++) {
            scores[i] = tournament.players[i].highscore;
        }

        // sort scores and rearrange the rank mapping
        for (uint i = 0; i < len - 1; i++) {
            for (uint j = i + 1; j < len; j++) {
                if (scores[i] < scores[j]) {
                    uint tempScore = scores[i];
                    scores[i] = scores[j];
                    scores[j] = tempScore;

                    address tempAddr = tournament.rankToAccount[i];
                    tournament.rankToAccount[i] = tournament.rankToAccount[j];
                    tournament.rankToAccount[j] = tempAddr;
                }
            }
        }

        for (uint i = 0; i < len; i++) {
            tournament.accountToRank[tournament.rankToAccount[i]] = i + 1;
        }

        // store the rank and score in the Player struct
        for (uint i = 0; i < len; i++) {
            tournament.players[i].highscore = scores[i];
            tournament.players[i].isRegistered = false;
            uint rank = tournament.accountToRank[tournament.players[i].account];
            tournament.players[i] = Player(tournament.players[i].id, tournament.players[i].account, tournament.players[i].highscore, tournament.players[i].isRegistered, rank);
        }
    }

    function endTournament(uint _tournamentId) public onlyRole(FACTORY_ROLE) {
        calculateRanking(_tournamentId);
        Tournament storage tournament = tournamentMapping[_tournamentId];
        uint _prizeCount = tournament.prizeCount;
        address[] memory prizeAddr = new address[](_prizeCount);
        for(uint i = 0; i < _prizeCount; i++){
            prizeAddr[i] = tournament.rankToAccount[i];
        }
        TournamentEscrow(EscrowAddr).unlockPrize(_tournamentId, prizeAddr);
        TournamentEscrow(EscrowAddr).unlockRegFee(_tournamentId);
        tournament.tournamentEnded = true;

        removeOnGoingTournament(_tournamentId);
        emit TournamentEnded(_tournamentId);
    }

    function cancelTournament(uint _tournamentId) public onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournamentMapping[_tournamentId];
        
        // Get the list of player addresses
        uint playerCount = tournament.players.length;
        address[] memory playerAddresses = new address[](playerCount);
        for (uint i = 0; i < playerCount; i++) {
            playerAddresses[i] = tournament.players[i].account;
        }

        TournamentEscrow(EscrowAddr).canceledTournament(_tournamentId, playerAddresses);
        removeOnGoingTournament(_tournamentId);
        emit TournamentCanceled(_tournamentId);
    }

    function addOnGoingTournament(uint _tournamentId) internal {
        OnGoingTournaments.push(_tournamentId);
    }

    function addEndedTournament(uint _tournamentId) internal {
        EndedTournaments.push(_tournamentId);
    }

    function removeOnGoingTournament(uint _tournamentId) internal {
        for (uint256 i = 0; i < OnGoingTournaments.length; i++) {
            if (OnGoingTournaments[i] == _tournamentId) {
                if (i != OnGoingTournaments.length - 1) {
                    OnGoingTournaments[i] = OnGoingTournaments[OnGoingTournaments.length - 1];
                }
                OnGoingTournaments.pop();
                addEndedTournament(_tournamentId);
                break;
            }
        }
    }

    function getAllTournamentCount() public view returns (uint) {
        uint count = OnGoingTournaments.length + EndedTournaments.length;
        return count;
    }

    function getOnGoingTournamentsCount() public view returns (uint) {
        return OnGoingTournaments.length;
    }

    function getEndedTournamentsCount() public view returns (uint) {
        return EndedTournaments.length;
    }

    function getOnGoingTournaments() public view returns (uint[] memory) {
        return OnGoingTournaments;
    }

    function getEndedTournaments() public view returns (uint[] memory) {
        return EndedTournaments;
    }

    function getPlayerCount(uint _tournamentId) external view returns(uint _playerCnt){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.players.length;
    }

    function getPlayerInfo(uint _tournamentId, uint playerId) external view returns(Player memory _player){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.players[playerId];
    }

    function getPlayerRank(uint _tournamentId, address player) external view returns(uint _rank){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.accountToRank[player];
    }

    function playerIdByAccount(uint _tournamentId, address player) external view returns(uint _id){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.playerIdByAccount[player];
    }
}