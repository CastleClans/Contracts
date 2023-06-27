// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

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

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    IWarCastleToken public contract_castle;
    IWarCitizenToken public contract_citizen;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

    // Mapping from owner address to token ID.
    mapping(uint256 => EnumerableSet.UintSet) private castle_citizens;
    mapping(address => EnumerableMap.UintToUintMap) private citizens_allocation;

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

        WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(contract_castle.getTokenDetails(castleId));

        require(castle_citizens[castleId].length()+1 <= castle_detail.max_citizens, "Castle max citizen reached");
        
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
        _deallocateCitizen(msg.sender, castleId, citizenId);
    }

    function deallocateAllCitizens(uint256 castleId) public {
        _deallocateAllCitizens(msg.sender, castleId);
    }

    function _deallocateCitizen(address citizen_owner, uint256 castleId, uint256 citizenId) public {
        // Release OpenSea proxy (allowed to use castle/citizen contracts) to deallocate when trading
        if (msg.sender != address(contract_castle) && msg.sender != address(contract_citizen)) {
            require(contract_castle.isOwnerOf(msg.sender, castleId), string.concat("Castle not owned by sender ", Strings.toHexString(msg.sender)));
            require(contract_citizen.isOwnerOf(msg.sender, citizenId), string.concat("Citizen not owned by sender ", Strings.toHexString(msg.sender)));
        }

        (, uint256 citizenCastle) = citizens_allocation[citizen_owner].tryGet(citizenId);
        if (citizenCastle > 0) {
            require(citizenCastle == castleId, "Citizen not in castle");
            // citizens_allocation[citizen_owner].set(citizenId, 0);
            citizens_allocation[citizen_owner].remove(citizenId);
            castle_citizens[castleId].remove(citizenId);
        }
    }

    function _deallocateAllCitizens(address owner, uint256 castleId) public {
        // Release OpenSea proxy to deallocate when trade
        if (msg.sender != address(contract_castle) && msg.sender != address(contract_citizen)) {
            require(contract_castle.isOwnerOf(msg.sender, castleId), string.concat("Castle not owned by sender ", Strings.toHexString(msg.sender)));
        }
        uint256 size = castle_citizens[castleId].length();
        for (uint256 index = 0; index < size; index++) {
            citizens_allocation[owner].remove(castle_citizens[castleId].at(index));
            // citizens_allocation[owner].set(castle_citizens[castleId].at(index), 0);
        }
        delete castle_citizens[castleId];
    }

    function setCastle(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_castle = IWarCastleToken(contractAddress);
	}

    function setCitizen(address contractAddress) external onlyRole(DESIGNER_ROLE) {
		contract_citizen = IWarCitizenToken(contractAddress);
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

	function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}