// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



interface IAggregator {
  

    
    /// @notice find the best market to execute swap
    /// @param fromToken  fromToken
    /// @param toToken   toToken
    /// @param amount  amount
    function calculateMarketReturn(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount
    ) external view returns(uint256[] memory markets); // [Uniswap,SushiSwap,etc.]

    

    /// @notice find the best market to execute swap
    /// @param fromToken  fromToken
    /// @param toToken   toToken
    /// @param amount    input amount of fromToken
    /// @param minReturn   minReturn of toToken output
    /// @param marketID marketID
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 marketID,
        uint256 minReturn
    ) external payable;

}