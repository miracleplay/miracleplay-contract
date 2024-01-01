// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;    

import "./Miracle-Fund-Escrow-R1.sol";
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
//   MiracleFundingTournament V0.1

contract MiracleTournament is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address payable public EscrowAddr;
    uint[] private OnGoingTournaments;
    uint[] private EndedTournaments;
    uint[] public mvpMintAmount;
    uint[] public bptMintAmount;
    IERC20 VoteToken;
    IERC20 BattlePoint;

    struct Tournament {
        bool created;
        uint8 tournamentType;
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

    event CreateTournament(uint tournamentId);
    event Registered(uint tournamentId, address account);
    event NewPersonalRecord(uint tournamentId, address account, uint score);
    event ScoreUpdated(uint tournamentId, string uri);
    event TournamentEnded(uint tournamentId); 
    event TournamentCanceled(uint tournamentId);
    event ShuffledPlayers(uint tournamentId, uint playersCount);

    bytes32 private constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 private constant ESCROW_ROLE = keccak256("ESCROW_ROLE");

    constructor(address adminAddr, address _VoteToken, address _BattlePoint, string memory _contractURI)  {
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddr);
        _setupRole(FACTORY_ROLE, adminAddr);
        VoteToken = IERC20(_VoteToken);
        BattlePoint = IERC20(_BattlePoint);
        mvpMintAmount = [10000000000000000000,5000000000000000000,3000000000000000000,1000000000000000000]; // Wei
        bptMintAmount = [100000000000000000000,50000000000000000000,10000000000000000000]; // Wei
        deployer = adminAddr;
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

    function createTournament(uint _tournamentId, uint8 _tournamentType, address _organizer, uint _registerStartTime, uint _registerEndTime, uint _prizeCount, uint _playerLimit) public onlyRole(ESCROW_ROLE) {
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.created = true;
        newTournament.tournamentType = _tournamentType;
        newTournament.organizer = _organizer;
        newTournament.registerStartTime = _registerStartTime;
        newTournament.registerEndTime = _registerEndTime;
        newTournament.prizeCount = _prizeCount;
        newTournament.PlayersLimit = _playerLimit;
        newTournament.tournamentEnded = false;
        
        addOnGoingTournament(_tournamentId);
        emit CreateTournament(_tournamentId);
    }
    
    function register(uint _tournamentId, address _player) public payable registrationOpen(_tournamentId) onlyRole(ESCROW_ROLE){
        require(block.timestamp > tournamentMapping[_tournamentId].registerStartTime, "Registration has not started yet");
        require(block.timestamp < tournamentMapping[_tournamentId].registerEndTime, "Registration deadline passed");
        require(!tournamentMapping[_tournamentId].playerRegistered[_player], "Address already registered");
        require(tournamentMapping[_tournamentId].players.length < tournamentMapping[_tournamentId].PlayersLimit, "Tournament is full.");
        tournamentMapping[_tournamentId].playerRegistered[_player] = true;
        tournamentMapping[_tournamentId].players.push(_player);
        emit Registered(_tournamentId, _player);
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
        MiracleTournamentEscrow(EscrowAddr).endFunding(_tournamentId);
    }

    function cancelFunding(uint _tournamentId) external onlyRole(FACTORY_ROLE) {
        MiracleTournamentEscrow(EscrowAddr).cancelFunding(_tournamentId);
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
        MiracleTournamentEscrow(EscrowAddr).endedTournament(_tournamentId, prizeAddr);
        _tournament.tournamentEnded = true;

        removeOnGoingTournament(_tournamentId);
        addEndedTournament(_tournamentId);

        emit TournamentEnded(_tournamentId);
    }


    function cancelTournament(uint _tournamentId) public onlyRole(FACTORY_ROLE) {
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        require(!_tournament.tournamentEnded, "Tournament has already ended");

        address[] memory _entryPlayers = _tournament.players;
        MiracleTournamentEscrow(EscrowAddr).canceledTournament(_tournamentId, _entryPlayers);
        _tournament.tournamentEnded = true;

        removeOnGoingTournament(_tournamentId);
        addEndedTournament(_tournamentId);

        emit TournamentCanceled(_tournamentId);
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
            VoteToken.mintTo(_rankers[i], mintAmount);
        }

        for (uint j = 0; j < _entryPlayers.length; j++) {
            if (!_isRanker(_entryPlayers[j], _rankers)) {
                uint mintAmount = bptMintAmount[bptMintAmount.length - 1];
                if (mintAmount>0){
                    VoteToken.mintTo(_entryPlayers[j], bptMintAmount[bptMintAmount.length - 1]);
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

    // View function
    function getFundingProgress(uint _tournamentId) public view returns (uint) {
        return MiracleTournamentEscrow(EscrowAddr).getFundingProgress(_tournamentId);
    }
}