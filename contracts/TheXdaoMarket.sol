// TheXdao Market contract
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./TheXdaoNFT.sol";
import "./interfaces/IBEP20.sol";

interface ITheXdaoNFT {
	function initialize(string memory _name, string memory _uri, address creator, bool bPublic) external;	
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function creatorOf(uint256 _tokenId) external view returns (address);
	function royalties(uint256 _tokenId) external view returns (uint256);	
}

contract TheXdaoMarket is Ownable, ERC721Holder {
    using SafeMath for uint256;
	
	uint256 constant public PERCENTS_DIVIDER = 1000;

	uint256 public feeAdmin = 25;	
	address public adminAddress; 	

    IBEP20 public governanceToken;

    /* Pairs to swap NFT _id => price */
	struct Pair {
		uint256 pair_id;
		address collection;
		uint256 token_id;
		address creator;
		address owner;
		uint256 price;
        uint256 creatorFee;
        bool bValid;		
	}

	bool private initialisable;
	address[] public collections;
	// collection address => creator address

	// token id => Pair mapping
    mapping(uint256 => Pair) public pairs;
	uint256 public currentPairId;
    
	uint256 public totalEarning; /* Total TheXdao Token */
	uint256 public totalSwapped; /* Total swap count */

	/** Events */
    event CollectionCreated(address collection_address, address owner, string name, string uri, bool isPublic);
    event ItemListed(uint256 id, address collection, uint256 token_id, uint256 price, address creator, address owner, uint256 creatorFee);
	event ItemDelisted(uint256 id);
    event Swapped(address buyer, Pair pair);

	constructor () {		
		initialisable = true;
	}
	function initialize(
		address _governanceToken, 
		address _adminAddress 
		) external onlyOwner {
		require(initialisable, "initialize() can be called only one time.");
		initialisable = false;
		governanceToken = IBEP20(_governanceToken);
		adminAddress = _adminAddress;
        createCollection("TheXdao", "https://ipfs.io/ipfs/Qmb2xi5DHBbTj9QXKcvEdU8RphvLKL9ggUyH9kdAh7dbgG", true);		
	}    

	function setFeeAddress(address _adminAddress) external onlyOwner {		
        adminAddress = _adminAddress;		
    }


	function createCollection(string memory _name, string memory _uri, bool bPublic) public returns(address collection) {
		bytes memory bytecode = type(TheXdaoNFT).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_uri, _name, block.timestamp));
        assembly {
            collection := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ITheXdaoNFT(collection).initialize(_name, _uri, msg.sender, bPublic);
		collections.push(collection);		
		emit CollectionCreated(collection, msg.sender, _name, _uri, bPublic);
	}
	

    function list(address _collection, uint256 _token_id, uint256 _price) OnlyItemOwner(_collection,_token_id) public {
		require(_price > 0, "invalid price");		

		ITheXdaoNFT nft = ITheXdaoNFT(_collection);        
        nft.safeTransferFrom(msg.sender, address(this), _token_id);

		currentPairId = currentPairId.add(1);

		pairs[currentPairId].pair_id = currentPairId;
		pairs[currentPairId].collection = _collection;
		pairs[currentPairId].token_id = _token_id;
		pairs[currentPairId].creator = nft.creatorOf(_token_id);
        pairs[currentPairId].creatorFee = nft.royalties(_token_id);
		pairs[currentPairId].owner = msg.sender;		
		pairs[currentPairId].price = _price;	
        pairs[currentPairId].bValid = true;	

        emit ItemListed(currentPairId, 
			_collection,
			_token_id, 
			_price, 
			pairs[currentPairId].creator,
			msg.sender,
			pairs[currentPairId].creatorFee
		);
    }

    function delist(uint256 _id) external {        
        require(pairs[_id].bValid, "not exist");

        require(msg.sender == pairs[_id].owner || msg.sender == owner(), "Error, you are not the owner");        
        ITheXdaoNFT(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pairs[_id].token_id);        
        pairs[_id].bValid = false;
        emit ItemDelisted(_id);        
    }


    function buy(uint256 _id) external ItemExists(_id) {
        require(pairs[_id].bValid, "invalid Pair id");
		require(pairs[_id].owner != msg.sender, "owner can not buy");

		Pair memory pair = pairs[_id];
		uint256 totalAmount = pair.price;
		uint256 token_balance = governanceToken.balanceOf(msg.sender);
		require(token_balance >= totalAmount, "insufficient token balance");

		// transfer TheXdao token to adminAddress
		require(governanceToken.transferFrom(msg.sender, adminAddress, totalAmount.mul(feeAdmin).div(PERCENTS_DIVIDER)), "failed to transfer Admin fee");
		
		// transfer IgarataArt token to creator
		require(governanceToken.transferFrom(msg.sender, pair.creator, totalAmount.mul(pair.creatorFee).div(PERCENTS_DIVIDER)), "failed to transfer creator fee");
		
		// transfer TheXdao token to owner
		uint256 ownerPercent = PERCENTS_DIVIDER.sub(feeAdmin).sub(pair.creatorFee);
		require(governanceToken.transferFrom(msg.sender, pair.owner, totalAmount.mul(ownerPercent).div(PERCENTS_DIVIDER)), "failed to transfer to owner");

		// transfer NFT token to buyer
		ITheXdaoNFT(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.token_id);
		
		pairs[_id].bValid = false;

		totalEarning = totalEarning.add(totalAmount);
		totalSwapped = totalSwapped.add(1);

        emit Swapped(msg.sender, pair);		
    }

	function getCollections() public view returns (address[] memory) {
		return collections;
	}

	modifier OnlyItemOwner(address tokenAddress, uint256 tokenId){
        ITheXdaoNFT tokenContract = ITheXdaoNFT(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender, 'Invalid owner of token ID');
        _;
    }

    modifier ItemExists(uint256 id){
        require(id <= currentPairId && pairs[id].pair_id == id, "Could not find item");
        _;
    }

}