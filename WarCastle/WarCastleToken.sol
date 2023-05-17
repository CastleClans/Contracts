// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "../IERC20Burnable.sol";
import "../WarCastleDetails.sol";
import "../GameDesign/IWarDesign.sol";
import "../ContextMixin.sol";

contract WarCastleToken is ERC721Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ContextMixin {
	struct CreateTokenRequest {
		uint256 targetBlock; // Use future block.
		uint16 count; // Amount of tokens to mint.
	}

	using Counters for Counters.Counter;
	using WarCastleDetails for WarCastleDetails.Details;

	event TokenCreateRequested(address to, uint256 block);
	event TokenCreated(address to, uint256 tokenId, uint256 details);

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");
	bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");
	bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
	bytes32 public constant TRADER_ROLE = keccak256("TRADER_ROLE");

	uint256 private constant maskLast8Bits = uint256(0xff);
	uint256 private constant maskFirst248Bits = ~uint256(0xff);

	IERC20Burnable public coinToken;
	Counters.Counter public tokenIdCounter;
	
	// Mapping from owner to number of owned token
    mapping (address => Counters.Counter) private _ownedTokensCount;

	// Mapping from owner address to token ID.
	mapping(address => uint256[]) public tokenIds;

	// Mapping from token ID to token details.
	mapping(uint256 => uint256) public tokenDetails;

	// Mapping from owner address to token requests.
	mapping(address => CreateTokenRequest[]) public tokenRequests;

	IWarDesign public design;

	constructor(IERC20Burnable coinToken_) {
		coinToken = coinToken_;
	}

	function initialize() public initializer {
		__ERC721_init("War Castle Token", "WCST");
		__AccessControl_init();
		__Pausable_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(PAUSER_ROLE, msg.sender);
		_setupRole(UPGRADER_ROLE, msg.sender);
		_setupRole(DESIGNER_ROLE, msg.sender);
		_setupRole(CLAIMER_ROLE, msg.sender);
		_setupRole(BURNER_ROLE, msg.sender);
		_setupRole(TRADER_ROLE, msg.sender);

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
        return _ownedTokensCount[owner].current();
    }

	/**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender() internal override view returns (address sender) {
        return ContextMixin.msgSender();
    }

	function _baseURI() internal view override returns (string memory) {
		return design.getCastleBaseURI();
	}

	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
		require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
		return string.concat(
			_baseURI(),
			Strings.toString(tokenId)
		);
	}

	function contractURI() public view virtual returns (string memory) {
        return "https://metadata.castleclans.com/contract-castles";
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

	/** Burns a list of heroes. */
	function burn(uint256[] memory ids) external onlyRole(BURNER_ROLE) {
		for (uint256 i = 0; i < ids.length; ++i) {
			_burn(ids[i]);
			_ownedTokensCount[msg.sender].decrement();
		}
	}

	/** Sets the design. */
	function setDesign(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		design = IWarDesign(contractAddress);
	}

	/** Returns if address if owner of tokenId */
	function isOwnerOf(address owner, uint256 tokenId) external view returns (bool) {
		return (ownerOf(tokenId) == owner ? true : false);
	}

	/** Gets token details for the specified owner. */
	function getTokenDetailsByOwner(address to) external view returns (uint256[] memory) {
		uint256[] storage ids = tokenIds[to];
		uint256[] memory result = new uint256[](_ownedTokensCount[to].current());
		uint256 index = 0;
		for (uint256 i = 0; i < ids.length; ++i) {
			if (ownerOf(ids[i]) == to) {
				result[index] = tokenDetails[ids[i]];
				index++;
			}
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

	/** Mints tokens. */
	function mint(uint256 count) external {
		require(!paused(), "Mint paused");
		require(count > 0, "No token to mint");
		require(count <= 10, "Max 10 mints per block");

		// Burn coins
		coinToken.burnFrom(msg.sender, design.getCastleMintCost() * count);
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
			(seed, details) = design.createRandomWarCastleToken(tokenSeed, id);

			tokenIdCounter.increment();
			tokenDetails[id] = details;
			_safeMint(to, id);
			emit TokenCreated(to, id, details);
		}
	}

	/** Upgrades the specified token. */
	function upgrade(uint256 baseId) external {
		require(ownerOf(baseId) == msg.sender, "Castle Token not owned");
		require(!paused(), "Mint paused");

		// Check level.
		uint256 baseDetails = tokenDetails[baseId];
		WarCastleDetails.Details memory wc_details;
		wc_details = WarCastleDetails.decode(baseDetails);

		require(wc_details.level+1 <= design.getCastleMaxLevel(), "Castle already at Max level");

		// Burn coin token.
		coinToken.burnFrom(msg.sender, design.getCastleUpgradeCost(wc_details.rarity, wc_details.level));
		wc_details.level += 1;

		tokenDetails[baseId] = WarCastleDetails.encode(wc_details);
	}

	/** Update the specified castle reward. */
	function _transfer(address from, address to, uint256 tokenId) internal override onlyRole(TRADER_ROLE) {
		ERC721Upgradeable._transfer(from, to, tokenId);
	}

	function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override {
		super._beforeTokenTransfer(from, to, tokenId, batchSize);
		// Not minting, burn or transfer
		if (from != address(0)) {
			_ownedTokensCount[from].decrement();
		}
		if (to == address(0)) {
			// Need to clear the tokenDetails of tokenId if burn
			delete tokenDetails[tokenId];
		} else {
			// Add the tokenID to the new owner
			_ownedTokensCount[to].increment();
			uint256[] storage ids = tokenIds[to];
			ids.push(tokenId);
		}
	}
}
