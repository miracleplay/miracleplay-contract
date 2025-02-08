// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@thirdweb-dev/contracts/eip/ERC721A.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract UpgradeableMiracleERC721 is 
    ERC721A,
    PermissionsEnumerable,
    Multicall,
    ContractMetadata
{
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    // 메타데이터 관련 변수
    string private _baseTokenURI;
    mapping(uint256 => string) private _tokenURIs;

    // 최대 발행 수량 변수 추가
    uint256 public maxTotalSupply;
    
    // 이벤트
    event TokenURIUpdated(uint256 indexed tokenId, string newUri);
    event BaseURIUpdated(string newUri);
    event MaxTotalSupplyUpdated(uint256 maxTotalSupply);
    event TokenMinted(
        address indexed to,
        uint256 indexed tokenId,
        string tokenURI,
        string pairKey
    );

    constructor(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        string memory _contractURI
    ) ERC721A(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _setupRole(FACTORY_ROLE, _defaultAdmin);
        _setupContractURI(_contractURI);
        maxTotalSupply = 10000;
    }

    /// @dev NFT 민팅 함수
    function mint(
        address _to,
        string memory _tokenURI,
        string memory _pairKey
    ) external onlyRole(FACTORY_ROLE) {
        require(totalSupply() + 1 <= maxTotalSupply, "Exceeds max supply");
        uint256 tokenId = totalSupply();
        _safeMint(_to, 1);
        
        _tokenURIs[tokenId] = _tokenURI;
        emit TokenURIUpdated(tokenId, _tokenURI);
        emit TokenMinted(_to, tokenId, _tokenURI, _pairKey);
    }

    /// @dev 베이스 URI 설정
    function setBaseURI(string memory _newBaseURI) 
        external 
        onlyRole(FACTORY_ROLE) 
    {
        _baseTokenURI = _newBaseURI;
        emit BaseURIUpdated(_newBaseURI);
    }

    /// @dev 특정 ID로 NFT 민팅 함수
    // function mintWithTokenId(
    //     address _to,
    //     uint256 _tokenId,
    //     string memory _tokenURI
    // ) external onlyRole(FACTORY_ROLE) {
    //     require(totalSupply() + 1 <= maxTotalSupply, "Exceeds max supply");
    //     require(!_exists(_tokenId), "Token already exists");
    //     _safeMint(_to, 1);
    //     _tokenURIs[_tokenId] = _tokenURI;
    //     emit TokenURIUpdated(_tokenId, _tokenURI);
    // }

    /// @dev 개별 토큰 URI 설정
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) 
        external 
        onlyRole(FACTORY_ROLE) 
    {
        require(_exists(_tokenId), "Token does not exist");
        _tokenURIs[_tokenId] = _tokenURI;
        emit TokenURIUpdated(_tokenId, _tokenURI);
    }

    /// @dev 여러 토큰의 URI를 한 번에 설정
    function batchSetTokenURI(
        uint256[] memory _ids, 
        string[] memory _uris
    ) external onlyRole(FACTORY_ROLE) {
        require(
            _ids.length == _uris.length,
            "Arrays length mismatch"
        );
        
        for(uint256 i = 0; i < _ids.length; i++) {
            require(_exists(_ids[i]), "Token does not exist");
            _tokenURIs[_ids[i]] = _uris[i];
            emit TokenURIUpdated(_ids[i], _uris[i]);
        }
    }

    /// @dev 토큰 URI 조회
    function tokenURI(uint256 _tokenId) 
        public 
        view 
        virtual 
        override 
        returns (string memory) 
    {
        require(_exists(_tokenId), "Token does not exist");

        string memory _tokenURI = _tokenURIs[_tokenId];
        
        // 개별 URI가 설정되어 있으면 반환
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        
        // 아니면 baseURI + tokenId 반환
        return string(abi.encodePacked(_baseTokenURI, _toString(_tokenId)));
    }

    /// @dev baseURI 반환
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /// @dev msgSender 오버라이드
    function _msgSender() 
        internal 
        view 
        virtual 
        override(Context, Multicall) 
        returns (address) 
    {
        return super._msgSender();
    }

    /// @dev msgData 오버라이드
    function _msgData() 
        internal 
        view 
        virtual 
        override(Context) 
        returns (bytes calldata) 
    {
        return super._msgData();
    }

    /// @dev 컨트랙트 URI 설정 권한 체크
    function _canSetContractURI() 
        internal 
        view 
        virtual 
        override 
        returns (bool) 
    {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /// @dev 현재 발행된 총 NFT 수량 조회
    function getCurrentTotalSupply() public view returns (uint256) {
        return totalSupply();
    }


    /// @dev 토큰 ID로 소유자 주소 조회
    function getOwnerOfToken(uint256 _tokenId) public view returns (address) {
        require(_exists(_tokenId), "Token does not exist");
        return ownerOf(_tokenId);
    }

    /// @dev 여러 토큰 ID로 소유자 주소 조회
    function getOwnerOfTokenBatch(uint256[] memory _tokenIds) public view returns (address[] memory) {
        address[] memory owners = new address[](_tokenIds.length);

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(_exists(_tokenIds[i]), "Token does not exist");
            owners[i] = ownerOf(_tokenIds[i]);
        }

        return owners;
    }

    /// @dev 최대 발행 수량 설정
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyRole(FACTORY_ROLE) {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupplyUpdated(_maxTotalSupply);
    }

    /// @dev 사용자 주소로 보유 중인 모든 NFT ID 조회
    function getOwnerdTokenIds(address _owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](tokenCount);
        uint256 currentIndex = 0;
        uint256 totalTokens = totalSupply();

        for (uint256 i = 0; i < totalTokens; i++) {
            if (ownerOf(i) == _owner) {
                ownedTokenIds[currentIndex] = i;
                currentIndex++;
            }
        }

        return ownedTokenIds;
    }
}