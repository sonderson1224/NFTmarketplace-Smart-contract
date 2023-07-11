// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {
    address payable owner;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 listPrice = 0.05 ether;

    constructor() ERC721("NFTMarketplace", "NFTM") {
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
    }

    event ListedTokenCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    mapping(uint256 => ListedToken) private idToListedToken;

    function updateListPrice(uint256 _listPrice) public payable {
        require(owner == msg.sender, "Only owner can update listing price");
        listPrice = _listPrice;
    }

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    function getLatestIdToListedToken()
        public
        view
        returns (ListedToken memory)
    {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getListedForTokenId(
        uint256 tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    function createToken(
        string memory tokenURI,
        uint256 price
    ) public payable returns (uint) {
        require(msg.value == listPrice, "send required amount of ether");
        require(price > 0, "Make sure the price isn,t negative");

        _tokenIds.increment();

        uint256 currentTokenId = _tokenIds.current();

        _safeMint(msg.sender, currentTokenId);

        _setTokenURI(currentTokenId, tokenURI);

        createListedToken(currentTokenId, price);

        return currentTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );

        _transfer(msg.sender, address(this), tokenId);
    }

    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);

        uint currentIndex = 0;

        for (uint i = 0; i < nftCount; i++) {
            uint currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }

        return tokens;
    }

    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        // Important to get a count of all the NFTs that belongs to a user before making an array for them
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                itemCount += 1;
            }
        }

        // Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                uint currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function buyNft(uint256 tokenId) public payable {
        uint256 price = idToListedToken[tokenId].price;
        address seller = idToListedToken[tokenId].seller;

        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        idToListedToken[tokenId].owner = payable(msg.sender);
        idToListedToken[tokenId].currentlyListed = true;
        idToListedToken[tokenId].seller = payable(seller);
        _itemsSold.increment();

        // Transfer the NFT to the buyer
        _transfer(address(this), msg.sender, tokenId);
        payable(owner).transfer(listPrice);
        // Transfer the payment to the seller
        payable(idToListedToken[tokenId].seller).transfer(msg.value);
    }

    function executeSale(uint256 tokenId, uint256 resellPrice) public payable {
        uint256 price = idToListedToken[tokenId].price;
        address seller = idToListedToken[tokenId].seller;

        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        require(
            idToListedToken[tokenId].currentlyListed == true,
            "NFT is not currently listed for sale"
        );

        idToListedToken[tokenId].currentlyListed = true;
        idToListedToken[tokenId].seller = payable(msg.sender);
        idToListedToken[tokenId].price = resellPrice;

        _itemsSold.increment();

        approve(address(this), tokenId);
        _transfer(address(this), msg.sender, tokenId);

        payable(owner).transfer(price);
        payable(seller).transfer(msg.value);
    }

    function resellToken(uint256 tokenId, uint256 price) public payable {
        // require(
        //     idToListedToken[tokenId].owner == msg.sender,
        //     "Only item owner can perform this operation"
        // );
        // require(msg.value == listPrice, "Price must be equal to listing price");
        idToListedToken[tokenId].currentlyListed = false;
        idToListedToken[tokenId].price = price;
        idToListedToken[tokenId].seller = payable(address(this));
        idToListedToken[tokenId].owner = payable(msg.sender);
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    function fetchItemsListed() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToListedToken[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToListedToken[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function getOwnerOfToken(uint256 tokenId) public view returns (address) {
        return idToListedToken[tokenId].owner;
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(
            address(this).balance >= amount,
            "Insufficient contract balance"
        );
        payable(owner).transfer(amount);
    }

    function destruct() public onlyOwner {
        selfdestruct(payable(owner));
    }
}
