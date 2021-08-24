const Arrgegator = artifacts.require("Arrgegator");
const TokenA = artifacts.require("MockERC20");
const TokenB = artifacts.require("MockERC20");




async function deployTestnet(deployer) {
    aggregator = await deployer.deploy(Arrgegator);
    tokenA = await deployer.deploy(TokenA,"TokenA","TokenA");
    tokenB = await deployer.deploy(TokenA,"TokenB","TokenB");
}



module.exports = function (deployer) {
    deployer.then(async () => {
      console.log(deployer.network);
      switch (deployer.network) {
        case 'mainnet':
          await deployTestnet(deployer);
          break;
        case 'development':
          await deployTestnet(deployer);
          break;
        case 'rinkeby':
        case 'ropsten':
        case 'matictest':
          await deployTestnet(deployer);
          break;
        default:
          throw ("Unsupported network");
      }
    })
  };