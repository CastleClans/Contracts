// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../WarCastleDetails.sol";
import "../WarCastle/IWarCastleToken.sol";
import "../WarCastleDetails.sol";

import "../WarCitizen/IWarCitizenToken.sol";
import "../WarCitizenDetails.sol";
import "../Utils.sol";
import "./IWarLogic.sol";

contract WarLogic is AccessControlUpgradeable, UUPSUpgradeable, IWarLogic {
    using WarCastleDetails for WarCastleDetails.Details;
	using WarCitizenDetails for WarCitizenDetails.Details;
    using Counters for Counters.Counter;

    IWarCastleToken public contract_castle;
    IWarCitizenToken public contract_citizen;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

    // Mapping from owner address to token ID.
	mapping(uint256 => uint256[]) public castle_citizens;
    mapping(address => mapping(uint256 => uint256)) public citizens_castle;
    
    mapping (uint256 => Counters.Counter) private _citizens_castle_counter;
    mapping (address => Counters.Counter) private _tot_allocated;

    function initialize() public initializer {
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(UPGRADER_ROLE, msg.sender);
		_setupRole(DESIGNER_ROLE, msg.sender);
        // Variables mix
	}

    function setCastle(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_castle = IWarCastleToken(contractAddress);
	}

    function setCitizen(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_citizen = IWarCitizenToken(contractAddress);
	}

    function getCitizenCastle(address owner, uint256 citizenId) external view returns (uint256) {
        return citizens_castle[owner][citizenId];
    }

    function getCastleCitizens(uint256 castleId) external view returns (uint256[] memory) {
        return castle_citizens[castleId];
    }

    function getOwnerCitizensInCastle(address owner) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_tot_allocated[owner].current());
		uint256 index = 0;
		for (uint256 i = 0; i < _tot_allocated[owner].current(); ++i) {
			result[index] = citizens_castle[owner][i];
			index++;
		}
        return result;
    }

    function allocateCitizen(uint256 castleId, uint256 citizenId) public {
        require(contract_castle.isOwnerOf(msg.sender, castleId), "Castle not owned by sender");
        require(contract_citizen.isOwnerOf(msg.sender, citizenId), "Citizen not owned by sender");

        uint256 baseDetails = contract_castle.getTokenDetails(castleId);

        WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(baseDetails);

        uint256[] storage citizens_ids = castle_citizens[castleId];
        require(citizens_ids.length+1 <= castle_detail.max_citizens, "Castle max citizen reached");
        require(citizens_castle[msg.sender][citizenId] != castleId, "Citizen already in castle");

        if (citizens_castle[msg.sender][citizenId] != 0) {
            deallocateCitizen(citizens_castle[msg.sender][citizenId], citizenId);
        }

        citizens_castle[msg.sender][citizenId] = castleId;
        citizens_ids.push(citizenId);

        _tot_allocated[msg.sender].increment();
        _citizens_castle_counter[castleId].increment();
    }

    function deallocateCitizen(uint256 castleId, uint256 citizenId) public {
        // Release OpenSea proxy to deallocate when trade
        if (msg.sender != address(contract_castle) && msg.sender != address(contract_citizen)) {
            require(contract_castle.isOwnerOf(msg.sender, castleId), string.concat("Castle not owned by sender ", Strings.toHexString(msg.sender)));
            require(contract_citizen.isOwnerOf(msg.sender, citizenId), string.concat("Citizen not owned by sender ", Strings.toHexString(msg.sender)));
        }

        uint256 baseDetails = contract_castle.getTokenDetails(castleId);

        WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(baseDetails);

        require(citizens_castle[contract_citizen.ownerOf(citizenId)][citizenId] == castleId, "Citizen not in castle");

        uint256[] memory newData = new uint256[](_citizens_castle_counter[castleId].current());
        for (uint256 index = 0; index < castle_citizens[castleId].length; index++) {
            if (castle_citizens[castleId][index] != citizenId) {
                newData[newData.length] = citizenId;
            }
        }
        // Clear the castle citizens array
        delete castle_citizens[castleId];
        castle_citizens[castleId] = newData;

        // Clear the citizen castle array
        delete citizens_castle[contract_citizen.ownerOf(citizenId)][citizenId];

        _citizens_castle_counter[castleId].decrement();
        _tot_allocated[msg.sender].decrement();
    }

    function deallocateAllCitizens(uint256 castleId) public {
        // Release OpenSea proxy to deallocate when trade
        if (msg.sender != address(contract_castle) && msg.sender != address(contract_citizen)) {
            require(contract_castle.isOwnerOf(msg.sender, castleId), string.concat("Castle not owned by sender ", Strings.toHexString(msg.sender)));
        }
        for (uint256 index = 0; index < castle_citizens[castleId].length; index++) {
            address owner = contract_castle.ownerOf(castleId);
            delete citizens_castle[owner][castle_citizens[castleId][index]];
            _citizens_castle_counter[castleId].decrement();
            _tot_allocated[owner].decrement();
        }
        delete castle_citizens[castleId];
    }

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

	function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}