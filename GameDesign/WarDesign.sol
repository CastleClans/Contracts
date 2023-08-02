// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../WarCastleDetails.sol";
import "../WarCitizenDetails.sol";
import "./IWarDesign.sol";
import "../Utils.sol";

contract WarDesign is AccessControlUpgradeable, UUPSUpgradeable, IWarDesign {
	struct StatsRange {
		uint256 min;
		uint256 max;
	}

	struct CastleStats {
		StatsRange defense;
		StatsRange power;
		StatsRange work_improvement;
		StatsRange max_citizens;
	}

	struct CitizenStats {
		StatsRange name;
		StatsRange surname;
		StatsRange gender;
		StatsRange profession;
		StatsRange work_effort;
	}

	using WarCastleDetails for WarCastleDetails.Details;
	using WarCitizenDetails for WarCitizenDetails.Details;

	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
	bytes32 public constant DESIGNER_ROLE = keccak256("DESIGNER_ROLE");

	// Mapping from rarity to stats.
	mapping(uint256 => CastleStats) private castleRarityStats;
	mapping(uint256 => CitizenStats) private citizenRarityStats;

	// Castle variables
	uint256[] private castle_drop_rate;
	uint256 private castle_mintCost;
	uint256 private castle_maxLevel;
	uint256[][] private castle_upgradeCosts;
	uint256[] private castle_move_cost;
	string private castle_baseURI;

	// Citizen variables
	uint256[] private citizen_drop_rate;
	uint256 private citizen_mintCost;
	uint256 private citizen_maxLevel;
	uint256[][] private citizen_upgradeCosts;
	string private citizen_baseURI;

	function initialize() public initializer {
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(UPGRADER_ROLE, msg.sender);
		_setupRole(DESIGNER_ROLE, msg.sender);

		castleRarityStats[0] = CastleStats(StatsRange(1, 3), StatsRange(1, 3), StatsRange(1, 2), StatsRange(10, 15));
		castleRarityStats[1] = CastleStats(StatsRange(3, 6), StatsRange(3, 6), StatsRange(2, 3), StatsRange(15, 20));
		castleRarityStats[2] = CastleStats(StatsRange(6, 9), StatsRange(6, 9), StatsRange(3, 4), StatsRange(20, 25));
		castleRarityStats[3] = CastleStats(StatsRange(9, 12), StatsRange(9, 12), StatsRange(4, 5), StatsRange(25, 30));
		castleRarityStats[4] = CastleStats(StatsRange(12, 15), StatsRange(12, 15), StatsRange(5, 6), StatsRange(30, 35));

		castle_drop_rate = [5007, 2654, 1532, 607, 201];
		castle_mintCost = 100 ether;
		castle_maxLevel = 4;
		castle_baseURI = "https://metadata.castleclans.com/castle/";

		castle_upgradeCosts.push([21 ether, 34 ether, 55 ether, 89 ether]);
		castle_upgradeCosts.push([34 ether, 55 ether, 89 ether, 144 ether]);
		castle_upgradeCosts.push([55 ether, 89 ether, 144 ether, 233 ether]);
		castle_upgradeCosts.push([89 ether, 144 ether, 233 ether, 377 ether]);
		castle_upgradeCosts.push([144 ether, 233 ether, 377 ether, 610 ether]);

		castle_move_cost = [21 ether, 34 ether, 55 ether, 89 ether, 144 ether];

		// Citizen
		citizenRarityStats[0] = CitizenStats(StatsRange(1, 20), StatsRange(1, 20), StatsRange(0,100), StatsRange(1, 5), StatsRange(2, 5));
		citizenRarityStats[1] = CitizenStats(StatsRange(1, 40), StatsRange(1, 40), StatsRange(0,100), StatsRange(1, 10), StatsRange(5, 8));
		citizenRarityStats[2] = CitizenStats(StatsRange(1, 60), StatsRange(1, 60), StatsRange(0,100), StatsRange(2, 15), StatsRange(8, 11));
		citizenRarityStats[3] = CitizenStats(StatsRange(1, 80), StatsRange(1, 80), StatsRange(0,100), StatsRange(3, 20), StatsRange(11, 14));
		citizenRarityStats[4] = CitizenStats(StatsRange(1, 100), StatsRange(1, 100), StatsRange(0,100), StatsRange(4, 25), StatsRange(14, 17));

		citizen_drop_rate = [8287, 1036, 518, 104, 56];
		citizen_mintCost = 10 ether;
		citizen_maxLevel = 4;
		citizen_baseURI = "https://metadata.castleclans.com/citizen/";

		citizen_upgradeCosts.push([3 ether, 4 ether, 6 ether, 9 ether]);
		citizen_upgradeCosts.push([4 ether, 6 ether, 9 ether, 15 ether]);
		citizen_upgradeCosts.push([6 ether, 9 ether, 15 ether, 24 ether]);
		citizen_upgradeCosts.push([9 ether, 15 ether, 24 ether, 38 ether]);
		citizen_upgradeCosts.push([15 ether, 24 ether, 38 ether, 61 ether]);
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

	function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	/* Castle Functions */
	function getCastleRarityStats() external view returns (CastleStats[] memory) {
		uint256 size = castle_drop_rate.length;
		CastleStats[] memory result = new CastleStats[](size);
		for (uint256 i = 0; i < size; ++i) {
			result[i] = castleRarityStats[i];
		}
		return result;
	}

	function getCastleDropRate() external view returns (uint256[] memory) {
		return castle_drop_rate;
	}

	function getCastleMintCost() external view returns (uint256) {
		return castle_mintCost;
	}

	function getCastleMaxLevel() external view returns (uint256) {
		return castle_maxLevel;
	}

	function getCastleUpgradeCost(uint256 rarity, uint256 level) external view returns (uint256) {
		return castle_upgradeCosts[rarity][level];
	}

	function getCastleUpgradeCosts() external view returns (uint256[][] memory) {
		return castle_upgradeCosts;
	}

	function getCastleMoveCosts() external view returns (uint256[] memory) {
		return castle_move_cost;
	}

	function getCastleMoveCost(uint256 rarity) external view returns (uint256) {
		return castle_move_cost[rarity];
	}

	function getCastleBaseURI() external view returns (string memory) {
		return castle_baseURI;
	}

	function createRandomWarCastleToken(uint256 seed, uint256 id) external view override returns (uint256 nextSeed, uint256 encodedDetails) {
		WarCastleDetails.Details memory wc_details;

		wc_details.id = id;
		wc_details.foundation = block.number;

		(seed, wc_details.rarity) = Utils.weightedRandom(seed, castle_drop_rate);
		CastleStats storage stats = castleRarityStats[wc_details.rarity];

		(seed, wc_details.defense) = Utils.randomRangeInclusive(seed, stats.defense.min, stats.defense.max);
		(seed, wc_details.power) = Utils.randomRangeInclusive(seed, stats.power.min, stats.power.max);
		(seed, wc_details.work_improvement) = Utils.randomRangeInclusive(seed, stats.work_improvement.min, stats.work_improvement.max);
		(seed, wc_details.max_citizens) = Utils.randomRangeInclusive(seed, stats.max_citizens.min, stats.max_citizens.max);

		nextSeed = seed;
		encodedDetails = wc_details.encode();
	}

	/* Citizen functions */
	function getCitizenRarityStats() external view returns (CitizenStats[] memory) {
		uint256 size = citizen_drop_rate.length;
		CitizenStats[] memory result = new CitizenStats[](size);
		for (uint256 i = 0; i < size; ++i) {
			result[i] = citizenRarityStats[i];
		}
		return result;
	}

	function getCitizenDropRate() external view returns (uint256[] memory) {
		return citizen_drop_rate;
	}

	function getCitizenMintCost() external view returns (uint256) {
		return citizen_mintCost;
	}

	function getCitizenMaxLevel() external view returns (uint256) {
		return citizen_maxLevel;
	}

	function getCitizenUpgradeCost(uint256 rarity, uint256 level) external view returns (uint256) {
		return citizen_upgradeCosts[rarity][level];
	}

	function getCitizenUpgradeCosts() external view returns (uint256[][] memory) {
		return citizen_upgradeCosts;
	}

	function getCitizeBaseURI() external view returns (string memory) {
		return citizen_baseURI;
	}

	function createRandomWarCitizenToken(uint256 seed, uint256 id) external view returns (uint256 nextSeed, uint256 encodedDetails) {
		WarCitizenDetails.Details memory wc_details;

		wc_details.id = id;
		wc_details.live_since = block.number;

		(seed, wc_details.rarity) = Utils.weightedRandom(seed, citizen_drop_rate);
		CitizenStats storage stats = citizenRarityStats[wc_details.rarity];

		(seed, wc_details.name) = Utils.randomRangeInclusive(seed, stats.name.min, stats.name.max);
		(seed, wc_details.surname) = Utils.randomRangeInclusive(seed, stats.surname.min, stats.surname.max);
		(seed, wc_details.profession) = Utils.randomRangeInclusive(seed, stats.profession.min, stats.profession.max);
		(seed, wc_details.work_effort) = Utils.randomRangeInclusive(seed, stats.work_effort.min, stats.work_effort.max);

		// To define gender, we create a random number
		(seed, wc_details.gender) = Utils.randomRangeInclusive(seed, stats.gender.min, stats.gender.max);
		// And extract the average of 2  (0 = Man, 1 = Woman)
		wc_details.gender = wc_details.gender % 2;

		nextSeed = seed;
		encodedDetails = wc_details.encode();
	}
}
