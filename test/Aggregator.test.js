
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const { accounts, contract } = require('@openzeppelin/test-environment');
const { BN, expectEvent, expectRevert, ether, balance, time } = require('@openzeppelin/test-helpers');
const { expect } = require("chai");
const Aggregator = contract.fromArtifact("Arrgegator");
const ERC20 = contract.fromArtifact("MockERC20");
const MockRouter = contract.fromArtifact("MockRouter");
const MockPair = contract.fromArtifact("MockUniswapV2Pair");
const MockFactory = contract.fromArtifact("MockFactory");

const [firstAccount, secondAccount, eth] = accounts;

function withPrecision(n) {
    return new BN(n).mul(new BN(10).pow(new BN(18)));
}


function toDispaly(n) {
    return new BN(n).div(new BN(10).pow(new BN(18)));
}


describe('Aggregator', function () {

    beforeEach(async function () {

        //Mock Token A & B 
        this.tokenA = await ERC20.new("TokenA", "TA");
        this.tokenB = await ERC20.new("TokenB", "TB");



        //simulate uni amm
        this.uniTokenPair = await MockPair.new(this.tokenA.address, this.tokenB.address);
        this.uniRouter = await MockRouter.new(this.uniTokenPair.address);


        //simulate sushi amm
        this.sushiTokenPair = await MockPair.new(this.tokenA.address, this.tokenB.address);
        this.sushiRouter = await MockRouter.new(this.sushiTokenPair.address);


        //init factory
        this.uniFactory = await MockFactory.new(this.uniTokenPair.address);
        this.sushiFactory = await MockFactory.new(this.sushiTokenPair.address);

        this.aggregator = await Aggregator.new();
        await this.aggregator.initialize(this.uniFactory.address, this.sushiFactory.address);


        //mint token to first account for add liquidity
        await this.tokenA.mint(firstAccount, withPrecision(10000));
        await this.tokenB.mint(firstAccount, withPrecision(10000));

        //mint token to second account for swap
        await this.tokenA.mint(secondAccount, withPrecision(2000));

        //uni add liquidity

        await this.tokenA.approve(this.uniRouter.address, withPrecision(4000), { from: firstAccount });
        await this.tokenB.approve(this.uniRouter.address, withPrecision(6000), { from: firstAccount });
        await this.uniRouter.addLiquidity(this.tokenA.address, this.tokenB.address, withPrecision(4000), withPrecision(6000), 0, 0, firstAccount, 0, { from: firstAccount });


        //sushi add liquidity
        await this.tokenA.approve(this.sushiRouter.address, withPrecision(6000), { from: firstAccount });
        await this.tokenB.approve(this.sushiRouter.address, withPrecision(4000), { from: firstAccount });
        await this.sushiRouter.addLiquidity(this.tokenA.address, this.tokenB.address, withPrecision(6000), withPrecision(4000), 0, 0, firstAccount, 0, { from: firstAccount });

    })


    describe("swap", function () {

        it("calculateMarketReturn ", async function () {
            marketsReturn = await this.aggregator.calculateMarketReturn(this.tokenA.address,this.tokenB.address,withPrecision(2000));
            uniReturn = marketsReturn[0];
            sushiReturn = marketsReturn[1];
            expect(uniReturn).to.be.bignumber.greaterThan(withPrecision(1995));
            expect(sushiReturn).to.be.bignumber.greaterThan(withPrecision(997));
        })

        it("execute swap", async function () {
            await this.tokenA.approve(this.aggregator.address, withPrecision(2000), { from: secondAccount });
            await this.aggregator.swap(this.tokenA.address, this.tokenB.address, withPrecision(2000), 0, withPrecision(1995), { from: secondAccount })
            bestMarketReturn = await this.tokenB.balanceOf(secondAccount);
            expect(bestMarketReturn).to.be.bignumber.greaterThan(withPrecision(1995));
            console.log(`bestMarketReturn:${toDispaly(bestMarketReturn)}`);
        })

    }
    )
})
