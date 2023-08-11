// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../IERC20Burnable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../GameDesign/IWarDesign.sol";
import "../WarCastleDetails.sol";
import "../WarCastle/IWarCastleToken.sol";

import "../WarCitizen/IWarCitizenToken.sol";
import "../WarCitizenDetails.sol";
import "../Utils.sol";
import "./IWarLogic.sol";

contract WarLogic is AccessControlUpgradeable, UUPSUpgradeable, IWarLogic {
	using WarCastleDetails for WarCastleDetails.Details;
	using WarCitizenDetails for WarCitizenDetails.Details;
	using Counters for Counters.Counter;

	using EnumerableSet for EnumerableSet.UintSet;
	using EnumerableMap for EnumerableMap.UintToUintMap;

	IWarCastleToken public contract_castle;
	IWarCitizenToken public contract_citizen;
	IWarDesign public contract_design;
	IERC20Burnable public contract_coin;

	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

	// Mapping from owner address to token ID.
	mapping(uint256 => EnumerableSet.UintSet) private castle_citizens;
	mapping(address => EnumerableMap.UintToUintMap) private citizens_allocation;

	mapping(int256 => mapping(int256 => uint256)) private map_castles;
	mapping(uint256 => int256[2]) private castle_map;

	int256 max_castle_distance = 10;
	Counters.Counter public totalCastlesInMap;

	constructor(IERC20Burnable coinToken_, address designAddress) {
		contract_coin = coinToken_;
		contract_design = IWarDesign(designAddress);
	}

	function initialize() public initializer {
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(UPGRADER_ROLE, msg.sender);
		_setupRole(DESIGNER_ROLE, msg.sender);
	}

	function getCastleWorkEffort(uint256 castleId) external view returns (uint256, uint256) {
		uint256 total_citizen_effort = 0;
		uint256 size = castle_citizens[castleId].length();
		WarCitizenDetails.Details memory citizen_details;
		for (uint256 i = 0; i < size; ++i) {
			uint256 citizenId = castle_citizens[castleId].at(i);
			citizen_details = WarCitizenDetails.decode(contract_citizen.getTokenDetails(citizenId));
			total_citizen_effort += citizen_details.work_effort + citizen_details.level;
		}
		WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(contract_castle.getTokenDetails(castleId));
		return (total_citizen_effort, (castle_detail.work_improvement + castle_detail.level));
	}

	function getCitizenCastle(uint256 citizenId) external view returns (uint256) {
		return this.getCitizenCastleOfOwner(msg.sender, citizenId);
	}

	function getCitizenCastleOfOwner(address owner, uint256 citizenId) external view returns (uint256) {
		(, uint256 val) = citizens_allocation[owner].tryGet(citizenId);
		return val;
	}

	function getCastleCitizens(uint256 castleId) external view returns (uint256[] memory) {
		return castle_citizens[castleId].values();
	}

	function allocateCitizen(uint256 castleId, uint256 citizenId) public {
		require(contract_castle.isOwnerOf(msg.sender, castleId), "Castle not owned by sender");
		require(contract_citizen.isOwnerOf(msg.sender, citizenId), "Citizen not owned by sender");
		require(isCastlePlaced(castleId), "Castle must be placed in the world");

		WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(contract_castle.getTokenDetails(castleId));

		require(castle_citizens[castleId].length() + 1 <= castle_detail.max_citizens, "Castle max citizen reached");

		(, uint256 citizenCastle) = citizens_allocation[msg.sender].tryGet(citizenId);
		require(citizenCastle != castleId, "Citizen already in castle");

		if (citizenCastle != 0) {
			deallocateCitizen(citizenCastle, citizenId);
		}

		WarCitizenDetails.Details memory citizen_details;
		citizen_details = WarCitizenDetails.decode(contract_citizen.getTokenDetails(citizenId));

		castle_citizens[castleId].add(citizenId);
		citizens_allocation[msg.sender].set(citizenId, castleId);
	}

	function deallocateCitizen(uint256 castleId, uint256 citizenId) public {
		// Release OpenSea proxy (allowed to use castle/citizen contracts) to deallocate when trading
		if (msg.sender != address(contract_castle) && msg.sender != address(contract_citizen)) {
			require(contract_castle.isOwnerOf(msg.sender, castleId), string.concat("Castle not owned by sender ", Strings.toHexString(msg.sender)));
			require(contract_citizen.isOwnerOf(msg.sender, citizenId), string.concat("Citizen not owned by sender ", Strings.toHexString(msg.sender)));
		}
	
		address citizenOwner = contract_citizen.ownerOf(citizenId);
		(, uint256 citizenCastle) = citizens_allocation[citizenOwner].tryGet(citizenId);
		
		if (citizenCastle > 0) {
			require(citizenCastle == castleId, "Citizen not in castle");
			citizens_allocation[citizenOwner].remove(citizenId);
			castle_citizens[castleId].remove(citizenId);
		}
	}

	function deallocateAllCitizens(uint256 castleId) public {
		// Release OpenSea proxy to deallocate when trade
		if (msg.sender != address(contract_castle) && msg.sender != address(contract_citizen)) {
			require(contract_castle.isOwnerOf(msg.sender, castleId), string.concat("Castle not owned by sender ", Strings.toHexString(msg.sender)));
		}
		uint256 size = castle_citizens[castleId].length();
		for (uint256 index = 0; index < size; ++index) {
			uint256 citizenId = castle_citizens[castleId].at(index);
			address citizenOwner = contract_citizen.ownerOf(citizenId);
			citizens_allocation[citizenOwner].remove(citizenId);
		}
		delete castle_citizens[castleId];
	}

	function getMapChunk(int256 _x, int256 _y, int256 _size) public view returns (int256[][] memory) {
		require(_size >= 0, "Size must be non-negative");

		uint256 size = uint256(_size);

		int256[][] memory result = new int256[][](size);
		for (int256 index_x = _x; index_x < _x + _size; index_x++) {
			result[uint256(index_x - _x)] = new int256[](size);
			for (int256 index_y = _y; index_y < _y + _size; index_y++) {
				uint256 tile_castle = getTile(index_x, index_y);
				if (tile_castle > 0) {
					result[uint256(index_x - _x)][uint256(index_y - _y)] = SafeCast.toInt256(tile_castle);
				}
			}
		}
		return result;
	}

	function placeCastle(uint256 castle_id, int256 _x, int256 _y) public {
		require(contract_castle.isOwnerOf(msg.sender, castle_id), "Castle not owned by sender");
		require(_x != 0 || _y != 0, "Position 0,0 is invalid");
		require(getTile(_x, _y) == 0, "Position already taken");
		require(!isCastlePlaced(castle_id), "Castle already placed");

		bool loopCheck = true;
		bool canPlace = false;

		if (totalCastlesInMap.current() > 0) {
			for (int256 index_x = (_x - max_castle_distance); index_x < _x + max_castle_distance + 1; index_x++) {
				if (loopCheck == false) {
					break;
				}
				for (int256 index_y = (_y - max_castle_distance); index_y < _y + max_castle_distance + 1; index_y++) {
					uint256 _tmpCastleId = getTile(index_x, index_y);
					if (_tmpCastleId != 0) {
						if (index_x >= _x - 1 && index_x <= _x + 1 && index_y >= _y - 1 && index_y <= _y + 1) {
							loopCheck = false;
							canPlace = false;
							break;
						} else {
							canPlace = true;
						}
					}
				}
			}
			require(canPlace == true, "Cannot place castle at this location");
		} else {
			require(_x >= max_castle_distance * -1 && _x <= max_castle_distance && _y >= max_castle_distance * -1 && _y <= max_castle_distance, "Cannot place castle too close or too far from other castle");
		}

		totalCastlesInMap.increment();
		map_castles[_x][_y] = castle_id;
		castle_map[castle_id][0] = _x;
		castle_map[castle_id][1] = _y;
	}

	function moveCastle(uint256 castleId, int256 new_x, int256 new_y) public {
		require(contract_castle.isOwnerOf(msg.sender, castleId), "Castle not owned by sender");
		require(isCastlePlaced(castleId), "Castle not placed yet");

		// Burn coin token.
		WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(contract_castle.getTokenDetails(castleId));
		contract_coin.burnFrom(msg.sender, contract_design.getCastleMoveCost(castle_detail.rarity));

		(int256 _x, int256 _y) = getCastlePosition(castleId);
		totalCastlesInMap.decrement();
		map_castles[_x][_y] = 0;
		castle_map[castleId][0] = 0;
		castle_map[castleId][1] = 0;

		placeCastle(castleId, new_x, new_y);
	}

	function clearBurnedCastle(uint256 castleId) public {
		require(!contract_castle.exists(castleId), "Token must be burned");
		if (isCastlePlaced(castleId)) {
			(int256 _x, int256 _y) = getCastlePosition(castleId);
			totalCastlesInMap.decrement();
			map_castles[_x][_y] = 0;
			castle_map[castleId][0] = 0;
			castle_map[castleId][1] = 0;
		}
	}

	function removeClastle(uint256 castleId) public {
		require(contract_castle.isOwnerOf(msg.sender, castleId) == false, "Castle not owned by sender");
		require(isCastlePlaced(castleId) == true, "Castle not placed yet");

		// Burn coin token.
		WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(contract_castle.getTokenDetails(castleId));
		contract_coin.burnFrom(msg.sender, contract_design.getCastleMoveCost(castle_detail.rarity));

		(int256 _x, int256 _y) = getCastlePosition(castleId);
		totalCastlesInMap.decrement();
		map_castles[_x][_y] = 0;
		castle_map[castleId][0] = 0;
		castle_map[castleId][1] = 0;
	}

	function getTotalCastlesInMap() public view returns (uint256) {
		return totalCastlesInMap.current();
	}

	function getTile(int256 _x, int256 _y) public view returns (uint256) {
		return map_castles[_x][_y];
	}

	function isCastlePlaced(uint256 castle_id) public view returns (bool) {
		int256[2] memory tmp = castle_map[castle_id];
		if (tmp[0] == 0 && tmp[1] == 0) {
			return false;
		}
		return true;
	}

	function getCastlePosition(uint256 castle_id) public view returns (int256, int256) {
		return (castle_map[castle_id][0], castle_map[castle_id][1]);
	}

	function setCastle(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_castle = IWarCastleToken(contractAddress);
	}

	function setCitizen(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_citizen = IWarCitizenToken(contractAddress);
	}

	function setDesign(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_design = IWarDesign(contractAddress);
	}

	function setCoin(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_coin = IERC20Burnable(contractAddress);
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

	function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}
