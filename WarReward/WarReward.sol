// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract WarReward is Initializable, AccessControlUpgradeable {
    using SafeMath for uint256;

    bytes32 public constant REWARD_SETTER_ROLE = keccak256("REWARD_SETTER_ROLE");
    IERC20 public token;

    // Structure for reward store
    struct Reward {
		uint256 timestamp; // Timestamp of the reward.
		uint256 amount; // Amount of reward coins
        bool claimed; // Status of the reward
	}

    // Mapping from address to rewards
	mapping(address => Reward[]) public reward_pool;
    
    // Stores how many coins is avaible for next reward distribution
    uint256 public avaible_in_pool;

    function initialize(IERC20 _token, uint256 pool_amount) public initializer {
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);  
        _setupRole(REWARD_SETTER_ROLE, msg.sender);  

        token = _token;
        avaible_in_pool = pool_amount;
    }

    function setRewardsBatch(address[] calldata _players, uint256[] calldata _amounts) external onlyRole(REWARD_SETTER_ROLE) {
        require(_players.length == _amounts.length, "Arrays must be of equal length");
        for (uint256 i = 0; i < _players.length; i++) {
            require(avaible_in_pool >= _amounts[i], "Reward pool is empty");
            reward_pool[_players[i]].push(Reward(block.timestamp, _amounts[i], false));
            avaible_in_pool -= _amounts[i];
        }
    }

    function getAvaibleCoinsInPool() public view returns (uint256) {
        return avaible_in_pool;
    }

    function getRewards() public view returns (Reward[] memory) {
        return getPlayerRewards(msg.sender);
    }

    function getAvaibleRewardCoins() public view returns (uint256) {
        return getPlayerAvaibleRewardCoins(msg.sender);
    }

    function getPlayerRewards(address player) public view returns (Reward[] memory) {
        return reward_pool[player];
    }

    function getPlayerAvaibleRewardCoins(address player) public view returns (uint256) {
        Reward[] storage rewards = reward_pool[player];
        uint256 coins = 0;
        for (uint256 i = 0; i < rewards.length; ++i) {
            if (!rewards[i].claimed) {
                coins += rewards[i].amount;
            }
        }
        return coins;
    }

    function claim(uint256 reward_index) external {
        Reward[] storage rewards = reward_pool[msg.sender];
        require(rewards.length >= reward_index, "Reward index doesn't exists");
        require(!rewards[reward_index].claimed, "Reward already claimed");

        // Calculates the % of fee to withdraw rewards
        // 0 day = 50%
        // 1 day = 40%
        // 2 day = 30%
        // 3 day = 20%
        // 4 day = 10%
        // 5 day = 0%
        
        uint256 passed_days = (block.timestamp - rewards[reward_index].timestamp).div(86400);

        // Fix for milisseconds block timestamp
        if (block.timestamp > 1687895782*1000) {
			passed_days = passed_days.div(1000);
		}

        uint256 fee = 100;
        if (passed_days < 1) {
            fee = 50;
        } else if (passed_days < 2) {
            fee = 40;
        } else if (passed_days < 3) {
            fee = 30;
        } else if (passed_days < 4) {
            fee = 20;
        } else if (passed_days < 5) {
            fee = 10;
        } else {
            fee = 0;
        }
        require(token.transfer(msg.sender, rewards[reward_index].amount - ((rewards[reward_index].amount/100)*fee)), "Transfer failed");
        rewards[reward_index].claimed = true;
    }
}
