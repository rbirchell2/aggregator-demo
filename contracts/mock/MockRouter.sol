pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import "../external/Decimal.sol";
import "./MockUniswapV2Pair.sol";

contract MockRouter {
    using SafeMath for uint256;
    using Decimal for Decimal.D256;

    MockUniswapV2Pair private PAIR;
    address public WETH;

    constructor(address pair) public {
        PAIR = MockUniswapV2Pair(pair);
    }


    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    uint256 private totalLiquidity;
    uint256 private constant LIQUIDITY_INCREMENT = 10000;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint,
        uint,
        address to,
        uint
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        address pair = address(PAIR);
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = LIQUIDITY_INCREMENT;
        (uint112 reserves0, uint112 reserves1, ) = PAIR.getReserves();
        IERC20(token).transferFrom(to, pair, amountToken);
        PAIR.mintAmount{value: amountETH}(to, LIQUIDITY_INCREMENT);
        totalLiquidity += LIQUIDITY_INCREMENT;
        uint112 newReserve0 = uint112(reserves0) + uint112(amountETH);
        uint112 newReserve1 = uint112(reserves1) + uint112(amountToken);
        PAIR.setReserves(newReserve0, newReserve1);
    }

    function addLiquidity(
        address token0,
        address token1,
        uint amountToken0Desired,
        uint amountToken1Desired,
        uint,
        uint,
        address to,
        uint
    ) external returns (uint, uint, uint liquidity) {
        address pair = address(PAIR);

        (uint amountA, uint amountB) = _addLiquidity(token0, token1, amountToken0Desired, amountToken1Desired, 0, 0);

        IERC20(token0).transferFrom(to, pair, amountA);
        IERC20(token1).transferFrom(to, pair, amountB);

        liquidity = PAIR.mintLiquidity(to);

    }

      function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint 
    ) external returns (uint amountA, uint amountB) {

        IERC20(address(PAIR)).transferFrom(msg.sender, address(PAIR), liquidity); // send liquidity to pair

        (uint amount0, uint amount1) = PAIR.burn(to);
    

        (address token0,) = sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    function setWETH(address weth) public {
        WETH = weth;
    }

    function removeLiquidityETH(
        address,
        uint liquidity,
        uint,
        uint,
        address to,
        uint
    ) external returns (uint amountToken, uint amountETH) {

        Decimal.D256 memory percentWithdrawal = Decimal.ratio(liquidity, totalLiquidity);
        Decimal.D256 memory ratio = ratioOwned(to);
        (amountETH, amountToken) = PAIR.burnEth(to, ratio.mul(percentWithdrawal));

        (uint112 reserves0, uint112 reserves1, ) = PAIR.getReserves();
        uint112 newReserve0 = uint112(reserves0) - uint112(amountETH);
        uint112 newReserve1 = uint112(reserves1) - uint112(amountToken);

        PAIR.setReserves(newReserve0, newReserve1);
        transferLiquidity(liquidity);
    }

    function transferLiquidity(uint liquidity) internal {
        PAIR.transferFrom(msg.sender, address(PAIR), liquidity); // send liquidity to pair

    }

    function ratioOwned(address to) public view returns (Decimal.D256 memory) {   
        uint256 balance = PAIR.balanceOf(to);
        uint256 total = PAIR.totalSupply();
        return Decimal.ratio(balance, total);
    }


        // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
     
            (address input, address output) = (path[0], path[1]);
            (address token0,) = sortTokens(input, output);
            uint amountOut = amounts[1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            PAIR.swap(
                amount0Out, amount1Out, _to, new bytes(0)
            );
        
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external  ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        safeTransferFrom(path[0],msg.sender,address(PAIR),amounts[0]);
        _swap(amounts, path, to);
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        (uint reserveIn, uint reserveOut) = getReserves(path[0],path[1]);
        amounts[1] = getAmountOut(amounts[0], reserveIn, reserveOut);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = PAIR.getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

        // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
       
        (uint reserveA, uint reserveB,) = PAIR.getReserves();
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
        // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

}
