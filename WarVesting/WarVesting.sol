// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./WarCoinVesting.sol";

/**
 * @dev PrivateSaleWarCoinVesting will be blocked and release 10% each month.
 * Hence, the vestingDuration should be 10 months from the beginning.
 *
 */
contract PrivateSaleWarCoinVesting is WarCoinVesting {
	constructor(address _token, address _owner, uint256 _vestingStartAt) WarCoinVesting(_token, _owner, _vestingStartAt, 10) {}
}

/**
 * @dev TeamWarCoinVesting will be blocked for 1 year,
 * then releaseed linearly each month during the next year.
 * Hence, the _vestingStartAt should delay 1 year
 * and the vestingDuration should be 12 months.
 *
 */
contract TeamWarCoinVesting is WarCoinVesting {
	//uint256 private SECONDS_PER_YEAR = 31536000;
	constructor(address _token, address _owner, uint256 _vestingStartAt) WarCoinVesting(_token, _owner, (_vestingStartAt + 31536000), 12) {}
}

/**
 * @dev AdvisorWarCoinVesting will be blocked for 1 year,
 * then releaseed linearly each month during the next year.
 * Hence, the _vestingStartAt should delay 1 year
 * and the vestingDuration should be 12 months.
 *
 */
contract AdvisorWarCoinVesting is WarCoinVesting {
	//uint256 private SECONDS_PER_YEAR = 31536000;
	constructor(address _token, address _owner, uint256 _vestingStartAt) WarCoinVesting(_token, _owner, (_vestingStartAt + 31536000), 12) {}
}

/**
 * @dev DexLiquidityWarCoinVesting will be blocked for 1 month,
 * then releaseed 5% each month during the next year.
 * Hence, the _vestingStartAt should delay 1 month
 * and the vestingDuration should be 20 months.
 *
 */
contract DexLiquidityWarCoinVesting is WarCoinVesting {
	//uint256 private SECONDS_PER_MONTH = 2628000;
	constructor(address _token, address _owner, uint256 _vestingStartAt) WarCoinVesting(_token, _owner, (_vestingStartAt + 2628000), 20) {}
}

/**
 * @dev ReserveWarCoinVesting will be blocked for 1 year,
 * then releaseed linearly each month during the next 2 year.
 * Hence, the _vestingStartAt should delay 1 year
 * and the vestingDuration should be 24 months.
 *
 */
contract ReserveWarCoinVesting is WarCoinVesting {
	//uint256 private SECONDS_PER_YEAR = 31536000;
	constructor(address _token, address _owner, uint256 _vestingStartAt) WarCoinVesting(_token, _owner, (_vestingStartAt + 31536000), 24) {}
}

/**
 * @dev WarCoinVestingFactory is the main and is the only contract should be deployed.
 * Notice: remember to config the Token address and approriate startAtTimeStamp
 */
contract WarCoinVestingFactory {
	// put the token address here
	// This should be included in the contract for transparency
	address public TOKEN_ADDRESS = 0x0000000000000000000000000000000000000000;

	// put the startAtTimeStamp here
	// To test all contracts, change this timestamp to time in the past.
	uint256 public startAtTimeStamp = block.timestamp;

	// address to track other information
	address public owner;
	address public privateSaleWarCoinVesting;
	address public teamWarCoinVesting;
	address public advisorWarCoinVesting;
	address public dexLiquidityWarCoinVesting;
	address public reserveWarCoinVesting;

	constructor() {
		owner = msg.sender;

		PrivateSaleWarCoinVesting _privateSaleWarCoinVesting = new PrivateSaleWarCoinVesting(TOKEN_ADDRESS, owner, startAtTimeStamp);
		privateSaleWarCoinVesting = address(_privateSaleWarCoinVesting);

		TeamWarCoinVesting _teamWarCoinVesting = new TeamWarCoinVesting(TOKEN_ADDRESS, owner, startAtTimeStamp);
		teamWarCoinVesting = address(_teamWarCoinVesting);

		AdvisorWarCoinVesting _advisorWarCoinVesting = new AdvisorWarCoinVesting(TOKEN_ADDRESS, owner, startAtTimeStamp);
		advisorWarCoinVesting = address(_advisorWarCoinVesting);

		DexLiquidityWarCoinVesting _dexLiquidityWarCoinVesting = new DexLiquidityWarCoinVesting(TOKEN_ADDRESS, owner, startAtTimeStamp);
		dexLiquidityWarCoinVesting = address(_dexLiquidityWarCoinVesting);

		ReserveWarCoinVesting _reserveWarCoinVesting = new ReserveWarCoinVesting(TOKEN_ADDRESS, owner, startAtTimeStamp);
		reserveWarCoinVesting = address(_reserveWarCoinVesting);
	}
}
