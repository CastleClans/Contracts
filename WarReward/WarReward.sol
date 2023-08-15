// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract WarReward is Initializable, AccessControlUpgradeable {
    bytes32 public constant REWARD_SETTER_ROLE = keccak256("REWARD_SETTER_ROLE");
    IERC20 public token;

    mapping(address => uint256) public rewards;

    function initialize(IERC20 _token) public initializer {
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);  
        _setupRole(REWARD_SETTER_ROLE, msg.sender);  

        token = _token;
    }

    function setRewardsBatch(address[] calldata _players, uint256[] calldata _amounts) external onlyRole(REWARD_SETTER_ROLE) {
        require(_players.length == _amounts.length, "Arrays must be of equal length");
        for (uint256 i = 0; i < _players.length; i++) {
            rewards[_players[i]] += _amounts[i];
        }
    }

    function getAvaibleReward() public view returns (uint256) {
        return rewards[msg.sender];
    }

    function getPlayerAvaibleReward(address player) public view returns (uint256) {
        return rewards[player];
    }

    function claim() external {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No rewards to claim");
        rewards[msg.sender] = 0;
        require(token.transfer(msg.sender, reward), "Transfer failed");
    }
}
