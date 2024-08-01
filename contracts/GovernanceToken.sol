//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract GovernanceToken is ERC20 {
    constructor() ERC20("Test Governance Token", "tGovToken") {
        _mint(msg.sender, 100000 ether);
    }
}