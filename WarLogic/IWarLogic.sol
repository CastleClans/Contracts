// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWarLogic {
	function setCastle(address contractAddress) external;
	function setCitizen(address contractAddress) external;
	function getCitizenCastle(uint256 citizenId) external view returns (uint256);
	function getCastleCitizens(uint256 castleId) external view returns (uint256[] memory);
	function allocateCitizen(uint256 castleId, uint256 citizenId) external;
	function deallocateCitizen(uint256 castleId, uint256 citizenId) external;
}
