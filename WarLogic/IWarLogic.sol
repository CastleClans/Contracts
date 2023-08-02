// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWarLogic {
	function setCastle(address contractAddress) external;
	function setCitizen(address contractAddress) external;
	function getCitizenCastle(uint256 citizenId) external view returns (uint256);
	function getCitizenCastleOfOwner(address owner, uint256 citizenId) external view returns (uint256);
	function getCastleCitizens(uint256 castleId) external view returns (uint256[] memory);
	function allocateCitizen(uint256 castleId, uint256 citizenId) external;
	function deallocateCitizen(uint256 castleId, uint256 citizenId) external;
	function _deallocateCitizen(address citizen_owner, uint256 castleId, uint256 citizenId) external;
	function deallocateAllCitizens(uint256 castleId) external;
	function _deallocateAllCitizens(address owner, uint256 castleId) external;
	function getCastleWorkEffort(uint256 castleId) external view returns (uint256, uint256);
	function getMapChunk(int256 _x, int256 _y, int256 _size) external view returns (int256[][] memory);
	function placeCastle(uint256 castle_id, int256 _x, int256 _y) external;
	function moveCastle(uint256 castleId, int256 new_x, int256 new_y) external;
	function clearBurnedCastle(uint256 castleId) external;
	function removeClastle(uint256 castleId) external;
	function getTotalCastlesInMap() external view returns (uint256);
	function getTile(int256 _x, int256 _y) external view returns (uint256);
	function isCastlePlaced(uint256 castle_id) external view returns (bool);
	function getCastlePosition(uint256 castle_id) external view returns (int256, int256);
}
