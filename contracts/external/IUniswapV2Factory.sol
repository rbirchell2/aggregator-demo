
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


import "./IUniswapV2Exchange.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IUniswapV2Factory {
    function getPair(IERC20 tokenA, IERC20 tokenB) external view returns (IUniswapV2Exchange pair);
}
