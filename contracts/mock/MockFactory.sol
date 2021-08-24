// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


import "../external/IUniswapV2Factory.sol";
contract MockFactory is IUniswapV2Factory {

    IUniswapV2Exchange internal pair;

    constructor (address _pair) public { pair = IUniswapV2Exchange(_pair);}

    function getPair(IERC20 tokenA, IERC20 tokenB) override external view returns (IUniswapV2Exchange){
        return pair;
    }
}