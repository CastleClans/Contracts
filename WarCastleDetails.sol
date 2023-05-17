// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WarCastleDetails {
	uint256 public constant ALL_RARITY = 0;

	struct Details {
		uint256 id;
		uint256 rarity;
		uint256 level;
		uint256 defense;
		uint256 power;
		uint256 work_improvement;
		uint256 max_citizens;
		uint256 foundation;
	}

	function encode(Details memory details) internal pure returns (uint256) {
		uint256 encodedData;
		encodedData |= details.id;
		encodedData |= details.rarity << 32;
		encodedData |= details.level << 40;
		encodedData |= details.defense << 56;
		encodedData |= details.power << 72;
		encodedData |= details.work_improvement << 88;
		encodedData |= details.max_citizens << 120;
		encodedData |= details.foundation << 152;
		return encodedData;
	}

	function decode(uint256 encodedData) internal pure returns (Details memory details) {
		details.id = encodedData & ((1 << 32) - 1);
		details.rarity = (encodedData >> 32) & ((1 << 8) - 1);
		details.level = (encodedData >> 40) & ((1 << 16) - 1);
		details.defense = (encodedData >> 56) & ((1 << 16) - 1);
		details.power = (encodedData >> 72) & ((1 << 16) - 1);
		details.work_improvement = (encodedData >> 88) & ((1 << 16) - 1);
		details.max_citizens = (encodedData >> 120) & ((1 << 32) - 1);
		details.foundation = (encodedData >> 152) & ((1 << 32) - 1);
		return details;
	}
}
