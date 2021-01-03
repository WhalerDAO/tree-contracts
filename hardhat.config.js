/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require("@nomiclabs/hardhat-truffle5");
require("dotenv").config();
const config = require("../deploy-configs/v2/get-config");



module.exports = {
  solidity: "0.6.6",
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
        // take the last tx from the reserve contract at 
        // https://etherscan.io/tx/0x2ea334bc27e53eb7fb3f73f2e63d295e4fbec98555208a80c22d4659ba3b99fa
        // and increment that block by 100
        blockNumber: config.blockNumber
      },
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: [`${process.env.PRIVATE_KEY}`,]
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};