// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract WarCoinVesting is Ownable {
	// Address of Token.
	IERC20 public coinToken;
	using SafeMath for uint256;

	// Starting timestamp of vesting
	// Will be used as a starting point for all dates calculations.
	// The first vesting will happen one month after this timestamp
	uint256 public vestingStartAt;

	// Vesting duration in seconds
	uint256 public vestingDuration;

	// Vesting cliff is one month
	// 365*(60*60*24) / 12
	uint256 internal constant SECONDS_PER_MONTH = 2628000;

	// Percent of vested token which can be withraw per month;
	uint256 internal percent_unlease_per_month;

	// Beneficiary contains details of each beneficiary/investor
	struct Beneficiary {
		uint256 initialBalance;
		uint256 monthsClaimed;
		uint256 totalClaimed;
	}

	// beneficiaries tracks all beneficiary and store data in storage
	mapping(address => Beneficiary) public beneficiaries;

	// Event raised on each successful withdraw.
	event Claim(address beneficiary, uint256 amount, uint256 timestamp);

	// Event raised on each desposit
	event Deposit(address beneficiary, uint256 initialBalance, uint256 timestamp);

	// @dev constructor creates the vesting contract
	// @param _token Address of token
	// @param _owner Address of owner of this contract, a.k.a the CEO
	// @param _vestingStartAt the starting timestamp of vesting , in seconds.
	// @param _vestingDuration the duration since _vestingStartAt until the vesting ends, in months.
	constructor(address _token, address _owner, uint256 _vestingStartAt, uint256 _vestingDuration) {
		require(_token != address(0), "zero-address");
		require(_owner != address(0), "zero-address");
		coinToken = IERC20(_token);
		_transferOwnership(_owner);
		vestingStartAt = _vestingStartAt;
		vestingDuration = _vestingDuration;
	}

	// @dev addBeneficiary registers a beneficiary and deposit a
	// corresponded amount of token for this beneficiary
	//
	// The owner can call this function many times to update
	// (additionally desposit) the amount of token for this beneficiary
	// @param _beneficiary Address of the beneficiary
	// @param _amount Amount of token belongs to this beneficiary
	function addBeneficiary(address _beneficiary, uint256 _amount) public onlyOwner {
		//require(block.timestamp < vestingStartAt, "not-update-after-vesting-started");
		require(_beneficiary != address(0), "zero-address");
		// Based on ERC20 standard, to transfer funds to this contract,
		// the owner must first call approve() to allow to transfer token to this contract.
		require(coinToken.transferFrom(_msgSender(), address(this), _amount), "cannot-transfer-token-to-this-contract");

		// update storage data
		Beneficiary storage bf = beneficiaries[_beneficiary];
		bf.initialBalance = bf.initialBalance.add(_amount);

		emit Deposit(_beneficiary, bf.initialBalance, block.timestamp);
	}

	// @dev Claim withraws the vested token and sends beneficiary
	// Only the owner or the beneficiary can call this function
	// @param _beneficiary Address of the beneficiary
	function claimVestedToken(address _beneficiary) public onlyOwner {
		require(_msgSender() == _beneficiary, "must-be-onwer-or-beneficiary");
		uint256 monthsVestable;
		uint256 tokenVestable;
		(monthsVestable, tokenVestable) = calculateClaimable(_beneficiary);
		require(tokenVestable > 0, "nothing-to-be-vested");

		require(coinToken.transfer(_beneficiary, tokenVestable), "fail-to-transfer-token");

		// update data in blockchain storage
		Beneficiary storage bf = beneficiaries[_beneficiary];
		bf.monthsClaimed = bf.monthsClaimed.add(monthsVestable);
		bf.totalClaimed = bf.totalClaimed.add(tokenVestable);

		emit Claim(_beneficiary, tokenVestable, block.timestamp);
	}

	// calculateWithrawable calculates the claimable token of the beneficiary
	// claimable token each month is rounded if it is a decimal number
	// So the rest of the token will be claimed on the last month (the duration is over)
	// @param _beneficiary Address of the beneficiary
	function calculateClaimable(address _beneficiary) private view returns (uint256, uint256) {
		uint256 _now = block.timestamp;
		if (_now < vestingStartAt) {
			return (0, 0);
		}

		uint256 elapsedTime = _now.sub(vestingStartAt);
		uint256 elapsedMonths = elapsedTime.div(SECONDS_PER_MONTH);

		if (elapsedMonths < 1) {
			return (0, 0);
		}

		Beneficiary storage bf = beneficiaries[_beneficiary];
		require(bf.initialBalance > 0, "beneficiary-not-found");

		// If over vesting duration, all tokens vested
		if (elapsedMonths >= vestingDuration) {
			uint256 remaining = bf.initialBalance.sub(bf.totalClaimed);
			return (vestingDuration, remaining);
		} else {
			uint256 monthsVestable = elapsedMonths.sub(bf.monthsClaimed);
			uint256 tokenVestedPerMonth = bf.initialBalance.div(vestingDuration);
			uint256 tokenVestable = monthsVestable.mul(tokenVestedPerMonth);
			return (monthsVestable, tokenVestable);
		}
	}

	// view function to check status of a beneficiary
	function getBeneficiary(address _beneficiary) public view returns (uint256 initialBalance, uint256 monthsClaimed, uint256 totalClaimed) {
		Beneficiary storage bf = beneficiaries[_beneficiary];
		require(bf.initialBalance > 0, "beneficiary-not-found");
		return (bf.initialBalance, bf.monthsClaimed, bf.totalClaimed);
	}
}