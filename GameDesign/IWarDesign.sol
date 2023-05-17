// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWarDesign {
	function getCastleDropRate() external view returns (uint256[] memory);

	function getCastleMintCost() external view returns (uint256);

	function getCastleMaxLevel() external view returns (uint256);

	function getCastleUpgradeCost(uint256 rarity, uint256 level) external view returns (uint256);

	function getCastleUpgradeCosts() external view returns (uint256[][] memory);

	function getCastleBaseURI() external view returns (string memory);

	function createRandomWarCastleToken(uint256 seed, uint256 id) external view returns (uint256 nextSeed, uint256 encodedDetails);

	function getCitizenDropRate() external view returns (uint256[] memory);

	function getCitizenMintCost() external view returns (uint256);

	function getCitizenMaxLevel() external view returns (uint256);

	function getCitizenUpgradeCost(uint256 rarity, uint256 level) external view returns (uint256);

	function getCitizenUpgradeCosts() external view returns (uint256[][] memory);

	function getCitizeBaseURI() external view returns (string memory);

	function createRandomWarCitizenToken(uint256 seed, uint256 id) external view returns (uint256 nextSeed, uint256 encodedDetails);
}
