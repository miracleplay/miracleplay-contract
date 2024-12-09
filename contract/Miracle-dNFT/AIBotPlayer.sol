// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AIBotPlayerNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // 메타데이터 초기 설정 여부를 추적
    mapping(uint256 => bool) private _initializedTokens;

    // 메타데이터 업데이트 권한을 가진 주소
    mapping(address => bool) private _metadataUpdaters;

    // 이벤트 정의
    event MetadataUpdated(uint256 indexed tokenId, string newUri);
    event MetadataInitialized(uint256 indexed tokenId, string uri);
    event UpdaterAdded(address updater);
    event UpdaterRemoved(address updater);

    constructor() ERC721("AI Bot Player", "AIBP") Ownable(msg.sender) {}

    // 업데이터 권한 관리
    modifier onlyUpdater() {
        require(_metadataUpdaters[msg.sender] || owner() == msg.sender, "Not authorized");
        _;
    }

    // NFT 민팅
    function mint(address to) public onlyOwner returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(to, newTokenId);
        return newTokenId;
    }

    // 초기 메타데이터 설정 (1회만 가능)
    function initializeMetadata(uint256 tokenId, string memory uri) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!_initializedTokens[tokenId], "Already initialized");

        _setTokenURI(tokenId, uri);
        _initializedTokens[tokenId] = true;

        emit MetadataInitialized(tokenId, uri);
    }

    // 메타데이터 업데이트 (권한 있는 주소만 가능)
    function updateMetadata(uint256 tokenId, string memory uri) public onlyUpdater {
        require(_exists(tokenId), "Token does not exist");
        require(_initializedTokens[tokenId], "Not initialized");

        _setTokenURI(tokenId, uri);

        emit MetadataUpdated(tokenId, uri);
    }

    // 업데이터 추가
    function addUpdater(address updater) public onlyOwner {
        _metadataUpdaters[updater] = true;
        emit UpdaterAdded(updater);
    }

    // 업데이터 제거
    function removeUpdater(address updater) public onlyOwner {
        _metadataUpdaters[updater] = false;
        emit UpdaterRemoved(updater);
    }

    // OpenZeppelin 오버라이드
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}