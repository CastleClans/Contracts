// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./WarCoinSales.sol";

/**
 * @dev PreSaleWarCoinVesting will be blocked and release 10% each month.
 * Hence, the vestingDuration should be 10 months from the beginning.
 *
 */
contract PreSaleWarCoinVesting is WarCoinSales {
	constructor(address _token, address _owner, uint256 _startingPrice) WarCoinSales(_token, _owner, _startingPrice, 10) {}
}

/**
 * @dev WarCoinPreSaleFactory is the main and is the only contract should be deployed.
 * Notice: remember to config the Token address and approriate startAtTimeStamp
 */
contract WarCoinPreSaleFactory {
	// address to track other information
	address public owner;
	address public preSaleWarCoinVesting;

	constructor(address token_address) {
		owner = msg.sender;

		PreSaleWarCoinVesting _preSaleWarCoinVesting = new PreSaleWarCoinVesting(token_address, owner, 1);
		preSaleWarCoinVesting = address(_preSaleWarCoinVesting);
	}
}
