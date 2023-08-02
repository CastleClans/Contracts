// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';

abstract contract WarCoinSales is Ownable {
	// Address of Token.
	IERC20 public coinToken;
	using SafeMath for uint256;

	// Starting timestamp of vesting
	// Will be used as a starting point for all dates calculations.
	// The first vesting will happen one month after this timestamp
	uint256 public dexLaunchTimestamp;

	// Vesting duration in seconds
	uint256 public vestingDuration;
	uint256 public vestingStartingPrice;

	// Vesting cliff is one month
	// 365*(60*60*24) / 12
	 uint256 internal constant SECONDS_PER_MONTH = 2628000;

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
	// @param _dexLaunchTimestamp the starting timestamp of vesting , in seconds.
	// @param _vestingDuration the duration since _dexLaunchTimestamp until the vesting ends, in months.
	constructor(address _token, address _owner, uint256 _vestingStartingPrice, uint256 _vestingDuration) {
		require(_token != address(0), "zero-address");
		require(_owner != address(0), "zero-address");
		coinToken = IERC20(_token);
		_transferOwnership(_owner);
		vestingDuration = _vestingDuration;
		vestingStartingPrice = _vestingStartingPrice;
	}

	function setDexLaunchDate(uint256 _dexLaunchTimestamp) public onlyOwner {
		require(dexLaunchTimestamp == 0, "Sales already started");
		dexLaunchTimestamp = _dexLaunchTimestamp;
	}

	function calculatePriceFromLiquidity(address token0, address token1, uint24 fee, address factory) public view returns (uint256) {
		address pool_address = IUniswapV3Factory(factory).getPool(token0, token1, fee);
		IUniswapV3Pool pool = IUniswapV3Pool(pool_address);
		(uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
		uint256 amount0 = FullMath.mulDiv(pool.liquidity(), FixedPoint96.Q96, sqrtPriceX96);
		uint256 amount1 = FullMath.mulDiv(pool.liquidity(), sqrtPriceX96, FixedPoint96.Q96);
		return (amount1 * 10**ERC20(token1).decimals()) / amount0;
	}

	function getPrice() public view returns (uint256) {
		// Mainet
		// address token0 = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270); // WMATIC
		// address token1 = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); // USDT
		// address factory = address(0x1F98431c8aD98523631AE4a59f267346ea31F984); // UniswalV3 Factory
		// Testnet
		address token0 = address(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889); // WMATIC
		address token1 = address(0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa); // WETH
		address factory = address(0x1F98431c8aD98523631AE4a59f267346ea31F984); // UniswapV3 Factory
		uint24 fee = 100; // Base pool fee
		return calculatePriceFromLiquidity(token0, token1, fee, factory);
	}

	// @dev addBeneficiary registers a beneficiary and deposit a
	// corresponded amount of token for this beneficiary
	//
	// The owner can call this function many times to update
	// (additionally desposit) the amount of token for this beneficiary
	// @param _beneficiary Address of the beneficiary
	// @param _amount Amount of token belongs to this beneficiary
	function addBeneficiary(address _beneficiary, uint256 _amount) public onlyOwner {
		require(_beneficiary != address(0), "zero-address");
		// Based on ERC20 standard, to transfer funds to this contract,
		// the owner must first call approve() to allow to transfer token to this contract.
		require(coinToken.transferFrom(_msgSender(), address(this), _amount), "Transfer vesting wallet failed");

		// update storage data
		Beneficiary storage bf = beneficiaries[_beneficiary];
		bf.initialBalance = bf.initialBalance.add(_amount);

		emit Deposit(_beneficiary, bf.initialBalance, block.timestamp);
	}

	// @dev Withraws the vested token and sends beneficiary
	// Only the beneficiary can call this function
	function withdraw() public {
		require(dexLaunchTimestamp > 0, "Pre sales withdraw not avaible yet");

		Beneficiary storage bf = beneficiaries[msg.sender];
		require(bf.initialBalance > 0, "Sender must be beneficiary");
		
		uint256 monthsVestable;
		uint256 tokenVestable;
		
		(monthsVestable, tokenVestable) = calculateClaimable(msg.sender);
		require(tokenVestable > 0, "Nothing to be vested yet");

		require(coinToken.transfer(msg.sender, tokenVestable), "Transfer token failed");

		// update data in blockchain storage
		bf.monthsClaimed = bf.monthsClaimed.add(monthsVestable);
		bf.totalClaimed = bf.totalClaimed.add(tokenVestable);

		emit Claim(msg.sender, tokenVestable, block.timestamp);
	}

	// calculateWithrawable calculates the claimable token of the beneficiary
	// claimable token each month is rounded if it is a decimal number
	// So the rest of the token will be claimed on the last month (the duration is over)
	// @param _beneficiary Address of the beneficiary
	function calculateClaimable(address _beneficiary) public view returns (uint256, uint256) {
		Beneficiary storage bf = beneficiaries[_beneficiary];
		require(bf.initialBalance > 0, "Beneficiary not found");
		
		uint256 _now = block.timestamp;
		if (_now < dexLaunchTimestamp) {
			return (0, 0);
		}

		uint256 elapsedTime = _now.sub(dexLaunchTimestamp);
		uint256 elapsedMonths = elapsedTime.div(SECONDS_PER_MONTH);

		// Fix for milisseconds block timestamp
		if (_now > 1687895782*1000) {
			elapsedMonths = elapsedMonths.div(1000);
		}

		if (elapsedMonths < 1) {
			return (0, 0);
		}

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
		require(bf.initialBalance > 0, "Beneficiary not found");
		return (bf.initialBalance, bf.monthsClaimed, bf.totalClaimed);
	}
}