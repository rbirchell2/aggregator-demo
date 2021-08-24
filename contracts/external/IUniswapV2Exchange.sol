// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


interface IUniswapV2Exchange {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}
