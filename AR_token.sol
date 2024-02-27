// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract AR_token is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    constructor(address initialOwner)
        ERC20("AR_token", "AR")
        Ownable(initialOwner)
        ERC20Permit("AR_token")
    {
        _mint(msg.sender, 8400000000000 * 10 ** decimals());
        _mint(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 8400000000000 * 10 ** decimals());
        _mint(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 4200000000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}