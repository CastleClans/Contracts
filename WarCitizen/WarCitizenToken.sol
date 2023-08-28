// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "../IERC20Burnable.sol";
import "../WarCitizenDetails.sol";
import "../GameDesign/IWarDesign.sol";
import "../ContextMixin.sol";
import "../WarLogic/IWarLogic.sol";

contract WarCitizenToken is ERC721Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ContextMixin, ERC721BurnableUpgradeable {
	struct CreateTokenRequest {
		uint256 targetBlock; // Use future block.
		uint16 count; // Amount of tokens to mint.
	}

	using Counters for Counters.Counter;
	using WarCitizenDetails for WarCitizenDetails.Details;
	using EnumerableSet for EnumerableSet.UintSet;

	event TokenCreateRequested(address to, uint256 block);
	event TokenCreated(address to, uint256 tokenId, uint256 details);

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

	uint256 private constant maskLast8Bits = uint256(0xff);
	uint256 private constant maskFirst248Bits = ~uint256(0xff);

	IERC20Burnable public coinToken;
	Counters.Counter public tokenIdCounter;

	// Mapping from owner address to token ID.
	// mapping(address => uint256[]) public tokenIds;
	mapping(address => EnumerableSet.UintSet) private tokenIds;


	// Mapping from token ID to token details.
	mapping(uint256 => uint256) public tokenDetails;

	// Mapping from owner address to token requests.
	mapping(address => CreateTokenRequest[]) public tokenRequests;

	// Mapping from owner to receive gifted token
	mapping(address => uint256) public tokenGifts;

	IWarDesign public design;
	IWarLogic public logic;

	constructor(IERC20Burnable coinToken_) {
		coinToken = coinToken_;
	}

	function initialize() public initializer {
		__ERC721_init("War Citizen Token", "WCTZ");
		__AccessControl_init();
		__Pausable_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(PAUSER_ROLE, msg.sender);
		_setupRole(UPGRADER_ROLE, msg.sender);
		_setupRole(DESIGNER_ROLE, msg.sender);

		tokenIdCounter.increment(); // Skip token 0, so we can check ownership from logic contract
	}

	function isApprovedForAll(address _owner, address _operator) public override view returns (bool isOperator) {
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        // otherwise, use the default ERC721Upgradeable.isApprovedForAll()
        return ERC721Upgradeable.isApprovedForAll(_owner, _operator);
    }

	 /**
     * @dev Gets the balance of the specified address.
     * @param owner address to query the balance of
     * @return uint256 representing the amount owned by the passed address
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return tokenIds[owner].length();
    }

	/**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender() internal override view returns (address sender) {
        return ContextMixin.msgSender();
    }

	function _baseURI() internal view override returns (string memory) {
		return design.getCitizeBaseURI();
	}

	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
		require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
		return string.concat(_baseURI(),string.concat(Strings.toString(tokenId), ".json"));
	}

	function contractURI() public view virtual returns (string memory) {
        return "https://metadata.castleclans.com/contract-citizens.json";
    }

	function pause() public onlyRole(PAUSER_ROLE) {
		_pause();
	}

	function unpause() public onlyRole(PAUSER_ROLE) {
		_unpause();
	}

	function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, AccessControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	/** Burns a list of citizens. */
	function burn(uint256 id) public virtual override {
		require(ownerOf(id) == msg.sender, "Token not owned");
		_burn(id);
	}

	/** Burns a list of citizens. */
	function burnBatch(uint256[] memory ids) external {
		for (uint256 i = 0; i < ids.length; ++i) {
			require(ownerOf(ids[i]) == msg.sender, "Token not owned");
			_burn(ids[i]);
		}
	}

	/** Sets the design. */
	function setDesign(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		design = IWarDesign(contractAddress);
	}

	/** Sets the logic contract. */
	function setLogic(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		logic = IWarLogic(contractAddress);
	}

	/** Returns if address if owner of tokenId */
	function isOwnerOf(address owner, uint256 tokenId) external view returns (bool) {
		return (ownerOf(tokenId) == owner ? true : false);
	}

	function getAddressTokens(address to) external view returns (uint256[] memory) {
		return tokenIds[to].values();
	}

	function getAddressTokensCount(address to) external view returns (uint256) {
		return tokenIds[to].length();
	}

	/** Gets token details for the specified owner. */
	function getTokenDetailsByOwner(address to) external view returns (uint256[] memory) {
		uint256[] memory result = new uint256[](tokenIds[to].length());
        for (uint256 index = 0; index < tokenIds[to].length(); index++) {
			result[index] = tokenDetails[tokenIds[to].at(index)];
        }
		return result;
	}

	/** Gets token details for the specified id. */
	function getTokenDetails(uint256 tokenId) external view returns (uint256) {
		return tokenDetails[tokenId];
	}

	struct Recipient {
		address to;
		uint256 count;
	}

	/* Updates the amount of gift tokens avaible for the address */
	function giftPlayer(address _address, uint256 amount) public onlyRole(UPGRADER_ROLE) {
		tokenGifts[_address] += amount;
	}

	/* Return the amount of gift tokens avaible for the address */
	function getGiftedTokens(address _address) public view returns (uint256) {
		return tokenGifts[_address];
	}

	/** Mints tokens. */
	function mint(uint256 count) external {
		require(!paused(), "Mint paused");
		require(count > 0, "No token to mint");
		require(count <= 10, "Max 10 mints per block");

		// Verify if owner have any gift avaible to mint
		uint256 gifts = getGiftedTokens(msg.sender);
		
		// Burn coins if minting paid tokens
		if (gifts < count) {
			coinToken.burnFrom(msg.sender, design.getCitizenMintCost() * (count-gifts));
			tokenGifts[msg.sender] -= gifts;
		} else {
			tokenGifts[msg.sender] -= count;
		}

		// Create requests.
		requestCreateToken(msg.sender, count);
	}

	/** Requests a create token request. */
	function requestCreateToken(address to, uint256 count) internal {
		// Create request.
		uint256 targetBlock = block.number + 5;
		tokenRequests[to].push(CreateTokenRequest(targetBlock, uint16(count)));
		emit TokenCreateRequested(to, targetBlock);
	}

	/** Gets the number of tokens that can be processed at the moment. */
	function getPendingTokens(address to) external view returns (uint256) {
		uint256 result;
		CreateTokenRequest[] storage requests = tokenRequests[to];
		for (uint256 i = 0; i < requests.length; ++i) {
			CreateTokenRequest storage request = requests[i];
			if (block.number > request.targetBlock) {
				result += request.count;
			} else {
				break;
			}
		}
		return result;
	}

	/** Gets the number of tokens that can be processed.  */
	function getProcessableTokens(address to) external view returns (uint256) {
		uint256 result;
		CreateTokenRequest[] storage requests = tokenRequests[to];
		for (uint256 i = 0; i < requests.length; ++i) {
			result += requests[i].count;
		}
		return result;
	}

	/** Processes token requests. */
	function processTokenRequests() external {
		require(!paused(), "Mint paused");

		address to = msg.sender;
		CreateTokenRequest[] storage requests = tokenRequests[to];
		for (uint256 i = requests.length; i > 0; --i) {
			CreateTokenRequest storage request = requests[i - 1];

			uint256 targetBlock = request.targetBlock;
			require(block.number > targetBlock, "Target block not arrived");
			uint256 seed = uint256(blockhash(targetBlock));
			if (seed == 0) {
				// Re-roll seed.
				targetBlock = (block.number & maskFirst248Bits) + (targetBlock & maskLast8Bits);
				if (targetBlock >= block.number) {
					targetBlock -= 256;
				}
				seed = uint256(blockhash(targetBlock));
			}

			createToken(to, request.count, seed);
			requests.pop();
		}
	}

	/** Creates token(s) with a random seed. */
	function createToken(address to, uint256 count, uint256 seed) internal {
		uint256 details;
		for (uint256 i = 0; i < count; ++i) {
			uint256 id = tokenIdCounter.current();

			uint256 tokenSeed = uint256(keccak256(abi.encode(seed, id)));
			(, details) = design.createRandomWarCitizenToken(tokenSeed, id);

			tokenIdCounter.increment();
			tokenDetails[id] = details;
			_safeMint(to, id);
			emit TokenCreated(to, id, details);
		}
	}

	/** Upgrades the specified token. */
	function upgrade(uint256 baseId, uint256 burnId) external {
		require(!paused(), "Upgrade paused");
		require(ownerOf(baseId) == msg.sender, "Base Citizen not owned");
		require(ownerOf(burnId) == msg.sender, "Burn Citizen not owned");

		// Check level.
		WarCitizenDetails.Details memory wc_details;
		wc_details = WarCitizenDetails.decode(tokenDetails[baseId]);

		require(wc_details.level+1 <= design.getCitizenMaxLevel(), "Citizen already at Max level");

		WarCitizenDetails.Details memory wc_details_burn;
		wc_details_burn = WarCitizenDetails.decode(tokenDetails[burnId]);

		require(wc_details.rarity == wc_details_burn.rarity, "Citizens not at same rarity"); 
		require(wc_details.level == wc_details_burn.level, "Citizens not at same level");

		// Burn coin token.
		coinToken.burnFrom(msg.sender, design.getCitizenUpgradeCost(wc_details.rarity, wc_details.level));
		
		// Deallocate the citizen if needed
		uint256 castleId = logic.getCitizenCastleOfOwner(msg.sender, burnId);
		if (castleId != 0) {
			logic.deallocateCitizen(castleId, burnId);
		}
		// Burn the token
		burn(burnId);

		// Update the citizen data at chain
		wc_details.level += 1;
		tokenDetails[baseId] = WarCitizenDetails.encode(wc_details);
	}

	function _transfer(address from, address to, uint256 tokenId) internal override {
		ERC721Upgradeable._transfer(from, to, tokenId);
	}

	function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override {
		// Not minting, burn or transfer
		if (from != address(0)) {
			// Check if citizen is inside a castle and deallocate
			uint256 castleId = logic.getCitizenCastleOfOwner(from, tokenId);
			if (castleId != 0) {
				logic.deallocateCitizen(castleId, tokenId);
			}

			// Decrement the owner token counter
			tokenIds[from].remove(tokenId);
		}
		if (to == address(0)) {
			// Need to clear the tokenDetails of tokenId if burn
			delete tokenDetails[tokenId];
		} else {
			// Add the tokenID to the new owner
			tokenIds[to].add(tokenId);
		}
		super._beforeTokenTransfer(from, to, tokenId, batchSize);
	}
}
