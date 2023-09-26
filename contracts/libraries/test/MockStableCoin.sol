// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../token/ERC20.sol";


// This contract represents a mock stable coin for testing purposes
contract MockStableCoin is ERC20 {
    constructor() ERC20("MockStableCoin", "MSTABLE", 6) {
        _mint(msg.sender, 1000000 * 10**decimals()); // Mint some initial tokens for testing
    }

    function mint(address to, uint256 amount) external  {
        _mint(to, amount);
    }
}