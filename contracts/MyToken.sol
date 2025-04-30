// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Simplified ERC20 Token (v5.x)
/// @notice ERC20 with no emergency pause
contract MyToken is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) Ownable(_msgSender()) {
        uint256 supply = initialSupply_ * (10 ** decimals());
        _mint(_msgSender(), supply);
    }
}