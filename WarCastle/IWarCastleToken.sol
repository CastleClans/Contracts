// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWarCastleToken {
    function getTokenDetailsByOwner(address to) external view returns (uint256[] memory);
    function getTokenDetails(uint256 tokenId) external view returns (uint256);
    function getAddressTokens(address to) external view returns (uint256[] memory);
    function isOwnerOf(address owner, uint256 tokenId) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
    function exists(uint256 tokenId) external view returns (bool);
}