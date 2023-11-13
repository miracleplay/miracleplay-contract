// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

// import "./Miracle-Tournament.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   TournamentEscrow V1.1                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          .0
                                             
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IERC1155{
    function mintTo(address _to, uint256 _tokenId, string calldata _uri, uint256 _amount) external;
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

interface IERC721{
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

contract MiracleTournamentEscrow is ContractMetadata {
    address public deployer;
    address public admin;
    address payable public tournamentAddr;
    //Royalty strring
    uint public RoyaltyPrizeDev;
    uint public RoyaltyregfeeDev;
    uint public RoyaltyPrizeFlp;
    uint public RoyaltyregfeeFlp;
    address public royaltyAddrDev;
    address public royaltyAddrFlp;
    // Nexus point
    IERC1155 public NexusPointEdition;
    uint public NexusPointID;
    string public NexusPointURI;

    // MiracleTournament internal miracletournament;

    struct Tournament {
        address organizer;
        TournamentStatus tournamentStatus;
        uint prizeCount;
        string tournamentURI;
        uint PlayersLimit;
    }

    struct TournamentEscrow {
        TournamentJoinfee joinFee;
        mapping(uint => TournamentPrizeAssets) ranksPrize;
        createTotalAssets createAssets;
    }

    struct TournamentPrizeAssets {
        PrizeAssetsERC20 Token;
        PrizeAssetsERC721 NFT;
        PrizeAssetsERC1155 Edition;
    }

    struct PrizeAssetsERC20{
        address tokenAddress;
        uint amount;
    }

    struct PrizeAssetsERC721{
        address NFTAddress;
        uint NFTId;
    }

    struct PrizeAssetsERC1155{
        address EditionAddress;
        uint EditionId;
        uint EditionAmount;
    }

    struct createTotalAssets{
        address[] TokenIndex;
        mapping (address=>uint) tokenAmount;
        address[] NFTIndex;
        mapping (address=>uint[]) NFT;
        address[] EditionIndex;
        mapping (address=>mapping(uint=>uint)) Edition;
    }

    struct TournamentJoinfee {
        address feeToken;
        uint feeAmount;
        uint feeBalance;
    }

    struct TournamentStatus {
        bool tournamentCreated;
        bool tournamentEnded;
        bool tournamentCanceled;
    }

    mapping(uint => Tournament) tournamentMap;
    mapping(uint => TournamentEscrow) escrowMap;

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

    constructor(address adminAddr, address _royaltyAddrDev, address _royaltyAddrFlp, IERC1155 _NexusPointEdition, uint _NexusPointID, string memory _nexusURI, string memory _contractURI) {
        admin = adminAddr;
        // Set Royalty address
        royaltyAddrDev = _royaltyAddrDev;
        royaltyAddrFlp = _royaltyAddrFlp;
        // Set default dev royalty 
        RoyaltyPrizeDev = 5;
        RoyaltyregfeeDev = 5;
        // Set default platform royalty 
        RoyaltyPrizeFlp = 0;
        RoyaltyregfeeFlp = 0;
        deployer = adminAddr;
        NexusPointEdition = _NexusPointEdition;
        NexusPointID = _NexusPointID;
        NexusPointURI = _nexusURI;
        _setupContractURI(_contractURI);
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
        Tournament storage _tournament = tournamentMap[_tournamentId];
        require(msg.sender == _tournament.organizer, "Only organizer can call this function");
        _;
    }

    function connectTournament(address payable _miracletournament) public onlyAdmin{
        tournamentAddr = _miracletournament;
        // miracletournament = MiracleTournament(_miracletournament);
    }

    // Create tournament
    //  _joinFeeToken, uint _joinFee, uint _joinStartTime, uint _joinEndTime, string memory _tournamentURI, uint _playerLimit
    function createTournamentEscrow(uint _tournamentId, uint _prizeCount, address[] memory _prizeToken, uint[] memory _prizeAmount, address[] memory _prizeNFT, uint[] memory _NFTtokens, address[] memory _prizeEdition, uint[] memory _editionTokens, uint[] memory _editionAmount) external {
        TournamentEscrow storage _newEscrow = escrowMap[_tournamentId];
        Tournament storage _newTournament = tournamentMap[_tournamentId];
        createTotalAssets storage _createTotalAssets = _newEscrow.createAssets;

        require(_newTournament.tournamentStatus.tournamentCreated == false, "Tournament already created.");

        // Set prize array and save memory to transfer assests.
        for (uint i = 0; i < _prizeCount; i++){
            TournamentPrizeAssets memory prizeAssets = _newEscrow.ranksPrize[i];

            address selectedToken = _prizeToken[i];
            uint selectedTokenAmount = _prizeAmount[i];

            address selectedNFT = _prizeNFT[i];
            uint selectedNFTId = _NFTtokens[i];

            address selectedEdition = _prizeEdition[i];
            uint selectedEditionId = _editionTokens[i];
            uint selectedEditionAmount = _editionAmount[i];

            // ERC20
            if(selectedToken != address(0)){
                prizeAssets.Token.tokenAddress = selectedToken;
                prizeAssets.Token.amount = selectedTokenAmount;

                uint currentAmount = _createTotalAssets.tokenAmount[selectedToken];

                _createTotalAssets.tokenAmount[selectedToken] = currentAmount + selectedTokenAmount;
                if (currentAmount == 0) {
                    _createTotalAssets.TokenIndex.push(selectedToken);
                }
            }
            // ERC721
            if (selectedNFT != address(0)){
                prizeAssets.NFT.NFTAddress = selectedNFT;
                prizeAssets.NFT.NFTId = (selectedNFTId);

                bool isAdded = false;
                for (uint ii = 0; ii < _createTotalAssets.NFTIndex.length; ii++){
                    if (_createTotalAssets.NFTIndex[ii] == selectedNFT){
                        isAdded = true;
                        break;
                    }
                }
                if(!isAdded){
                    _createTotalAssets.NFTIndex.push(selectedNFT);
                }
                _createTotalAssets.NFT[selectedNFT].push(selectedNFTId);
            }
            // ERC1155
            if (selectedEdition != address(0)){
                prizeAssets.Edition.EditionAddress = selectedEdition;
                prizeAssets.Edition.EditionId = selectedEditionId;
                prizeAssets.Edition.EditionAmount = selectedEditionAmount;
                
                bool isAdded = false;
                for (uint ii = 0; ii < _createTotalAssets.EditionIndex.length; ii++){
                    if(_createTotalAssets.EditionIndex[ii] == selectedEdition){
                        isAdded = true;
                        break;
                    }
                }
                if(!isAdded){
                    _createTotalAssets.EditionIndex.push(selectedEdition);
                    _createTotalAssets.Edition[selectedEdition][selectedEditionId] = selectedEditionAmount;
                }
            }
        }

        // Escrow Assest
        if (_createTotalAssets.TokenIndex.length > 0){
            for (uint erc20i = 0; erc20i < _createTotalAssets.TokenIndex.length; erc20i++){
                address _tokenAddress = _createTotalAssets.TokenIndex[erc20i];
                uint _tokenAmount = _createTotalAssets.tokenAmount[erc20i];
            }
        }

        if(_createTotalAssets.NFTIndex.length >0){

        }

        if(_createTotalAssets.EditionIndex.length >0){

        }

    }
}