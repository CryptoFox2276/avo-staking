// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TgrToken is ERC20 {
    constructor(uint256 initialSupply) ERC20('TGR', 'TGR') {
        _mint(msg.sender, initialSupply);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
}