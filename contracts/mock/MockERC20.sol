// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IDollar.sol";



contract MockERC20 is IDollar, ERC20 {




    constructor(string memory name, string memory symbol) public ERC20(name, symbol){

    }

    function mint(address to, uint256 amount)
    override external
    {
    _mint(to, amount);
    }

    function burn(address from, uint256 amount)
    override external
    {
    _burn(from, amount);
    }

}