// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract GLDToken is ERC20 {
    constructor() ERC20("SPACE", "SPACE") {
        _mint(msg.sender, 1050000 * 10 ** 8);
    }
}