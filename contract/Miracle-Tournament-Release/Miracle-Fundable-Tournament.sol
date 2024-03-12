// SPDX-License-Identifier: UNLICENSED
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   MiracleTournament V0.8.2 Fundable
pragma solidity ^0.8.22;    

import "./Miracle-Fundable-Escrow.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract FundableTournament is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address payable public EscrowAddr;
    uint[] private OnGoingTournaments;
    uint[] private EndedTournaments;
    uint[] public mvpMintAmount;
    uint[] public bptMintAmount;
    IMintableERC20 VoteToken;
    IMintableERC20 BattlePoint;
    // Tournament setting
    uint public minTournamentRate;

    struct Tournament {
        bool created;
        bool isFunding;
        address [] players;
        mapping(address => bool) playerRegistered;
        address [] ranker;
        address organizer;
        uint PlayersLimit;
        uint registerStartTime;
        uint registerEndTime;
        uint prizeCount;
        bool tournamentEnded;
        string scoreURI;
    }

    address admin;
    mapping(uint => Tournament) public tournamentMapping;

    event NewPersonalRecord(uint tournamentId, address account, uint score);
    event ScoreUpdated(uint tournamentId, string uri);
    event ShuffledPlayers(uint tournamentId, uint playersCount);

    bytes32 private constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 private constant ESCROW_ROLE = keccak256("ESCROW_ROLE");

    constructor(address _VoteToken, address _BattlePoint, string memory _contractURI)  {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
        VoteToken = IMintableERC20(_VoteToken);
        BattlePoint = IMintableERC20(_BattlePoint);
        mvpMintAmount = [10000000000000000000,5000000000000000000,3000000000000000000,1000000000000000000]; // Wei Default 1st:10 2nd:5 3th:3 other:1 
        bptMintAmount = [100000000000000000000,50000000000000000000,10000000000000000000]; // Wei Default 1st:100 2nd:50 other:10
        minTournamentRate = 100;
        deployer = msg.sender;
        _setupContractURI(_contractURI);
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

    function connectEscrow(address payable _escrowAddr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setupRole(ESCROW_ROLE, _escrowAddr);
        EscrowAddr = _escrowAddr;
    }

    function createTournament(uint _tournamentId, bool _isFunding, address _organizer, uint _registerStartTime, uint _registerEndTime, uint _prizeCount, uint _playerLimit) public onlyRole(ESCROW_ROLE) {
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.created = true;
        newTournament.isFunding = _isFunding;
        newTournament.organizer = _organizer;
        newTournament.registerStartTime = _registerStartTime;
        newTournament.registerEndTime = _registerEndTime;
        newTournament.prizeCount = _prizeCount;
        newTournament.PlayersLimit = _playerLimit;
        newTournament.tournamentEnded = false;
        
        addOnGoingTournament(_tournamentId);
    }
    
    function register(uint _tournamentId, address _player) public registrationOpen(_tournamentId) onlyRole(ESCROW_ROLE){
        require(block.timestamp > tournamentMapping[_tournamentId].registerStartTime, "Registration has not started yet");
        require(block.timestamp < tournamentMapping[_tournamentId].registerEndTime, "Registration deadline passed");
        require(!tournamentMapping[_tournamentId].playerRegistered[_player], "Address already registered");
        require(tournamentMapping[_tournamentId].players.length < tournamentMapping[_tournamentId].PlayersLimit, "Tournament is full.");
        tournamentMapping[_tournamentId].playerRegistered[_player] = true;
        tournamentMapping[_tournamentId].players.push(_player);
    }

    function kickPlayer(uint _tournamentId, address _player) public onlyRole(FACTORY_ROLE){
        require(tournamentMapping[_tournamentId].playerRegistered[_player] == true, "Player not registered");
        uint length = tournamentMapping[_tournamentId].players.length;
        
        for (uint i = 0; i < length; i++) {
            if (tournamentMapping[_tournamentId].players[i] == _player) {
                tournamentMapping[_tournamentId].players[i] = tournamentMapping[_tournamentId].players[length - 1];
                tournamentMapping[_tournamentId].players.pop();
                break;
            }
        }
        tournamentMapping[_tournamentId].playerRegistered[_player] = false;
    }

    function kickPlayerBatch(uint _tournamentId, address[] memory _players) external onlyRole(FACTORY_ROLE) {
        require(_players.length > 0, "No players to kick");
        
        for (uint j = 0; j < _players.length; j++) {
            if (tournamentMapping[_tournamentId].playerRegistered[_players[j]]) {
                uint length = tournamentMapping[_tournamentId].players.length;
                for (uint i = 0; i < length; i++) {
                    if (tournamentMapping[_tournamentId].players[i] == _players[j]) {
                        tournamentMapping[_tournamentId].players[i] = tournamentMapping[_tournamentId].players[length - 1];
                        tournamentMapping[_tournamentId].players.pop();
                        break;
                    }
                }
                tournamentMapping[_tournamentId].playerRegistered[_players[j]] = false;
            }
        }
    }


    function updateScore(uint tournamentId, string calldata _uri) external onlyRole(FACTORY_ROLE) {
        tournamentMapping[tournamentId].scoreURI = _uri;
    }

    function playersShuffle(uint tournamentId) public onlyRole(FACTORY_ROLE){
        Tournament storage tournament = tournamentMapping[tournamentId];
        address[] memory shuffledArray = tournament.players;
        uint n = shuffledArray.length;

        for (uint i = 0; i < n; i++) {
            uint j = i + uint(keccak256(abi.encodePacked(block.timestamp))) % (n - i);
            (shuffledArray[i], shuffledArray[j]) = (shuffledArray[j], shuffledArray[i]);
        }
        tournament.players = shuffledArray;

        emit ShuffledPlayers(tournamentId, shuffledArray.length);
    }

    function endFunding(uint _tournamentId) external onlyRole(FACTORY_ROLE) {
        FundableTournamentEscrow(EscrowAddr).endFunding(_tournamentId);
    }

    function cancelFunding(uint _tournamentId) external onlyRole(FACTORY_ROLE) {
        FundableTournamentEscrow(EscrowAddr).cancelFunding(_tournamentId);
    }

    function endTournament(uint _tournamentId, address[] calldata _rankers) public onlyRole(FACTORY_ROLE) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];

        require(!_tournament.tournamentEnded, "Tournament has already ended");

        uint _prizeCount = _tournament.prizeCount;
        address[] memory prizeAddr = new address[](_prizeCount);
        for(uint i = 0; i < _prizeCount; i++){
            prizeAddr[i] = _rankers[i];
        }

        _mintVoteToken(_tournamentId, _rankers);
        _mintBattlePoint(_tournamentId, _rankers);
        FundableTournamentEscrow(EscrowAddr).endedTournament(_tournamentId, prizeAddr);
        _tournament.tournamentEnded = true;

        removeOnGoingTournament(_tournamentId);
        addEndedTournament(_tournamentId);
    }


    function cancelTournament(uint _tournamentId) public onlyRole(FACTORY_ROLE) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(!_tournament.tournamentEnded, "Tournament has already ended");

        address[] memory _entryPlayers = _tournament.players;
        FundableTournamentEscrow(EscrowAddr).canceledTournament(_tournamentId, _entryPlayers);
        _tournament.tournamentEnded = true;

        removeOnGoingTournament(_tournamentId);
        addEndedTournament(_tournamentId);
    }

    function _mintVoteToken(uint _tournamentId, address[] calldata _rankers) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        address[] memory _entryPlayers = _tournament.players;

        for (uint i = 0; i < _rankers.length; i++) {
            uint mintAmount = (i < mvpMintAmount.length) ? mvpMintAmount[i] : mvpMintAmount[mvpMintAmount.length - 1];
            VoteToken.mintTo(_rankers[i], mintAmount);
        }

        for (uint j = 0; j < _entryPlayers.length; j++) {
            if (!_isRanker(_entryPlayers[j], _rankers)) {
                VoteToken.mintTo(_entryPlayers[j], mvpMintAmount[mvpMintAmount.length - 1]);
            }
        }
    }

    function _mintBattlePoint(uint _tournamentId, address[] calldata _rankers) internal {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        address[] memory _entryPlayers = _tournament.players;

        for (uint i = 0; i < _rankers.length; i++) {
            uint mintAmount = (i < bptMintAmount.length) ? bptMintAmount[i] : bptMintAmount[bptMintAmount.length - 1];
            BattlePoint.mintTo(_rankers[i], mintAmount);
        }

        for (uint j = 0; j < _entryPlayers.length; j++) {
            if (!_isRanker(_entryPlayers[j], _rankers)) {
                uint mintAmount = bptMintAmount[bptMintAmount.length - 1];
                if (mintAmount>0){
                    BattlePoint.mintTo(_entryPlayers[j], bptMintAmount[bptMintAmount.length - 1]);
                }
            }
        }
    }

    function _isRanker(address player, address[] memory rankers) internal pure returns (bool) {
        for (uint i = 0; i < rankers.length; i++) {
            if (player == rankers[i]) {
                return true;
            }
        }
        return false;
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
                break;
            }
        }
    }

    function updateMvpMintAmount(uint[] calldata newMvpMintAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mvpMintAmount = newMvpMintAmount;
    }

    function updateBptMintAmount(uint[] calldata newBptMintAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bptMintAmount = newBptMintAmount;
    }

    // View function
    function getRegistProgress(uint _tournamentId) public view returns (uint) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        if (_tournament.PlayersLimit == 0) {
            return 0;
        }
        uint progress = (_tournament.players.length * 100) / _tournament.PlayersLimit;
        return progress;
    }

    function getMinTournamentRate() public view returns (uint) {
        return minTournamentRate;
    }

    function isTounamentSuccess(uint _tournamentId) public view returns (bool) {
        uint progress = getFundingProgress(_tournamentId);
        uint minRate = getMinTournamentRate();
        return progress >= minRate;
    }

    function isFundingSuccess(uint _tournamentId) public view returns (bool) {
        return FundableTournamentEscrow(EscrowAddr).isFundingSuccess(_tournamentId);
    }
    
    function getAllTournamentCount() external view returns (uint) {
        uint count = OnGoingTournaments.length + EndedTournaments.length;
        return count;
    }

    function getOnGoingTournamentsCount() external view returns (uint) {
        return OnGoingTournaments.length;
    }

    function getEndedTournamentsCount() external view returns (uint) {
        return EndedTournaments.length;
    }

    function getOnGoingTournaments() external view returns (uint[] memory) {
        return OnGoingTournaments;
    }

    function getEndedTournaments() external view returns (uint[] memory) {
        return EndedTournaments;
    }

    function getPlayerCount(uint _tournamentId) external view returns(uint _playerCnt){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.players.length;
    }

    function getPlayers(uint _tournamentId) external view returns(address[] memory){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.players;
    }

    // View from escrow
    function getFundingProgress(uint _tournamentId) public view returns (uint) {
        return FundableTournamentEscrow(EscrowAddr).getFundingProgress(_tournamentId);
    }
}