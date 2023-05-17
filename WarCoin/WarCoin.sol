// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract WarCoin is ERC20, ERC20Burnable {
    constructor() ERC20("WarCoin", "WCOIN") {
        _mint(msg.sender, 100000000 * 10**uint256(decimals()));
    }

    function burn(uint256 amount) override public virtual {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) override public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}