// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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

    IWarCastleToken public contract_castle;
    IWarCitizenToken public contract_citizen;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

    // Mapping from owner address to token ID.
	mapping(uint256 => uint256[]) public castle_citizens;
    mapping(uint256 => uint256) public citizens_castle;

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

    function getCitizenCastle(uint256 citizenId) external view returns (uint256) {
        return citizens_castle[citizenId];
    }

    function getCastleCitizens(uint256 castleId) external view returns (uint256[] memory) {
        return castle_citizens[castleId];
    }

    function allocateCitizen(uint256 castleId, uint256 citizenId) public {
        require(contract_castle.isOwnerOf(msg.sender, castleId), "Castle not owned by sender");
        require(contract_citizen.isOwnerOf(msg.sender, citizenId), "Citizen not owned by sender");

        uint256 baseDetails = contract_castle.getTokenDetails(castleId);

        WarCastleDetails.Details memory castle_detail;
		castle_detail = WarCastleDetails.decode(baseDetails);

        uint256[] storage citizens_ids = castle_citizens[castleId];
        require(citizens_ids.length+1 <= castle_detail.max_citizens, "Castle max citizen reached");
        require(citizens_castle[citizenId] != castleId, "Citizen already in castle");

        if (citizens_castle[citizenId] != 0) {
            deallocateCitizen(citizens_castle[citizenId], citizenId);
        }

        citizens_castle[citizenId] = castleId;
        citizens_ids.push(citizenId);
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

        require(citizens_castle[citizenId] == castleId, "Citizen not in castle");

        uint256[] storage newData = castle_citizens[castleId];
        for (uint256 index = 0; index < castle_citizens[castleId].length; index++) {
            if (castle_citizens[castleId][index] != citizenId) {
                newData.push(citizenId);
            }
        }
        // Clear the castle citizens array
        delete castle_citizens[castleId];
        castle_citizens[castleId] = newData;

        // Clear the citizen castle array
        delete citizens_castle[citizenId];
    }

    function deallocateAllCitizens(uint256 castleId) public {
        // Release OpenSea proxy to deallocate when trade
        if (msg.sender != address(contract_castle) && msg.sender != address(contract_citizen)) {
            require(contract_castle.isOwnerOf(msg.sender, castleId), string.concat("Castle not owned by sender ", Strings.toHexString(msg.sender)));
        }
        for (uint256 index = 0; index < castle_citizens[castleId].length; index++) {
            delete citizens_castle[castle_citizens[castleId][index]];
        }
        delete castle_citizens[castleId];
    }

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

	function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}