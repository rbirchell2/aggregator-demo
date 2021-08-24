
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


interface IDollar {
    function burn(address account, uint256 amount) external;
    function mint(address account, uint256 amount) external;


    
}
