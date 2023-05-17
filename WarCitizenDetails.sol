// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WarCitizenDetails {
	uint256 public constant ALL_RARITY = 0;

	struct Details {
		uint256 id;
		uint256 rarity;
		uint256 level;
		uint256 work_effort;
		uint256 name;
		uint256 surname;
		uint256 gender;
		uint256 profession;
		uint256 live_since;
	}

	function encode(Details memory details) internal pure returns (uint256 encoded) {
		encoded |= details.id;
		encoded |= uint256(details.rarity) << 32;
		encoded |= uint256(details.level) << 40;
		encoded |= uint256(details.work_effort) << 56;
		encoded |= uint256(details.name) << 72;
		encoded |= uint256(details.surname) << 88;
		encoded |= uint256(details.gender) << 104;
		encoded |= uint256(details.profession) << 120;
		encoded |= uint256(details.live_since) << 152;
	}

	function decode(uint256 encoded) internal pure returns (Details memory details) {
		details.id = encoded & ((1 << 32) - 1);
		details.rarity = (encoded >> 32) & ((1 << 8) - 1);
		details.level = (encoded >> 40) & ((1 << 16) - 1);
		details.work_effort = (encoded >> 56) & ((1 << 16) - 1);
		details.name = (encoded >> 72) & ((1 << 16) - 1);
		details.surname = (encoded >> 88) & ((1 << 16) - 1);
		details.gender = (encoded >> 104) & ((1 << 16) - 1);
		details.profession = (encoded >> 120) & ((1 << 32) - 1);
		details.live_since = (encoded >> 152) & ((1 << 32) - 1);
		return details;
	}
}
