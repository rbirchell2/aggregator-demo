// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./IAggregator.sol";
import "./lib/UniswapV2ExchangeLib.sol";
import "./external/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

contract Arrgegator is IAggregator, Initializable {
    using UniversalERC20 for IERC20;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;
    uint256 public constant DEXES_COUNT = 2;
    uint256 public constant MARKET_UNISWAP = 0;
    uint256 public constant MARKET_SUSHISWAP = 1;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Factory public sushiSwapFactory;

    function initialize(address _uniswapV2Factory, address _sushiSwapFactory)
        external
        initializer
    {
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);
        sushiSwapFactory = IUniswapV2Factory(_sushiSwapFactory);
    }

    /// @notice find the best market to execute swap
    /// @param fromToken  fromToken
    /// @param toToken   toToken
    /// @param amount  amount
    function calculateMarketReturn(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount
    ) public override view returns (uint256[] memory) {
        uint256[] memory markets = new uint256[](DEXES_COUNT);
        function(IERC20, IERC20, uint256) view returns (uint256)[DEXES_COUNT] memory reserves = [
            _calculateUniswapV2, 
            _calculateSushiSwap
        ];
        for (uint256 i = 0; i < DEXES_COUNT; i++) {
            markets[i] = reserves[i](fromToken, toToken, amount);
        }
        return markets;
    }

    /// @notice find the best market to execute swap
    /// @param fromToken  fromToken
    /// @param toToken   toToken
    /// @param amount    input amount of fromToken
    /// @param marketID marketID
    /// @param minReturn   minReturn
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount,
        uint256 marketID,
        uint256 minReturn
    ) public override payable {
        if (fromToken == toToken) {
            return;
        }
        fromToken.universalTransferFrom(msg.sender, address(this), amount);
        uint256 confirmed = fromToken.universalBalanceOf(address(this));

        require(marketID <= DEXES_COUNT, "invalid request");

        function(IERC20, IERC20, uint256) returns (uint256)[DEXES_COUNT] memory _swap = [
            _swapOnUniswap,
            _swapOnSushiswap
        ];

        _swap[marketID](fromToken, toToken, confirmed);
        uint256 returnAmount = toToken.universalBalanceOf(address(this));
        require(
            returnAmount >= minReturn,
            "OneSplit: actual return amount is less than minReturn"
        );
        toToken.universalTransfer(msg.sender, returnAmount);
        fromToken.universalTransfer(
            msg.sender,
            fromToken.universalBalanceOf(address(this))
        );
    }

    function _calculateUniswapV2(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount
    ) internal view returns (uint256) {
        IERC20 fromTokenReal = fromToken;
        IERC20 toTokenReal = toToken;
        IUniswapV2Exchange fromExchange = uniswapV2Factory.getPair(
            fromTokenReal,
            toTokenReal
        );
        if (fromExchange != IUniswapV2Exchange(0)) {
            return fromExchange.getReturn(fromTokenReal, toTokenReal, amount);
        }
    }

    function _calculateSushiSwap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount
    ) internal view returns (uint256) {
        IERC20 fromTokenReal = fromToken;
        IERC20 toTokenReal = toToken;
        IUniswapV2Exchange fromExchange = sushiSwapFactory.getPair(
            fromTokenReal,
            toTokenReal
        );
        if (fromExchange != IUniswapV2Exchange(0)) {
            return fromExchange.getReturn(fromTokenReal, toTokenReal, amount);
        }
    }

    function _swapOnUniswap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount
    ) internal returns (uint256) {
        IERC20 fromTokenReal = fromToken;
        IERC20 toTokenReal = toToken;
        IUniswapV2Exchange exchange = uniswapV2Factory.getPair(
            fromTokenReal,
            toTokenReal
        );
        uint256 returnAmount = exchange.getReturn(
            fromTokenReal,
            toTokenReal,
            amount
        );

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(address(fromTokenReal)) < uint256(address(toTokenReal))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }
    }

    function _swapOnSushiswap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 amount
    ) internal returns (uint256) {
        IERC20 fromTokenReal = fromToken;
        IERC20 toTokenReal = toToken;
        IUniswapV2Exchange exchange = sushiSwapFactory.getPair(
            fromTokenReal,
            toTokenReal
        );
        uint256 returnAmount = exchange.getReturn(
            fromTokenReal,
            toTokenReal,
            amount
        );

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint256(address(fromTokenReal)) < uint256(address(toTokenReal))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }
    }

    function _infiniteApproveIfNeeded(IERC20 token, address to) internal {
        if ((token.allowance(address(this), to) >> 255) == 0) {
            token.universalApprove(to, uint256(-1));
        }
    }
}
