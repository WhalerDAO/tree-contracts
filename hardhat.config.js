require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");

require("dotenv").config();

let alchemyApi = `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`;

module.exports = {
  solidity: {
    compilers: [{
      version: "0.8.0",
      optimizer: {
        enabled: true,
        runs: 1000
        }
    }]
  },
  mocha: {
    timeout: 60000 // Here is 2min but can be whatever timeout is suitable for you.
  },
  networks: {
    hardhat: {
      forking: {
        url: alchemyApi
      },
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000,
    },
    mainnet: {
      url: alchemyApi,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
}
