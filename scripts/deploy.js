const PausedReserve = artifacts.require('PausedReserve');
const UniswapRouterManipulator = artifacts.require('UniswapRouterManipulator');
const OracleManipulator = artifacts.require('UniswapOracleManipulator');
const UniswapPairManipulator = artifacts.require('UniswapPairManipulator');
const OmniBridgeManipulator = artifacts.require('OmniBridgeManipulator');

const Web3 = require('web3');
const BigNumber = require('bignumber.js');
const HDWalletProvider = require('@truffle/hdwallet-provider');

require('dotenv').config();


const main = async function () {

    const config = require("../deploy-configs/get-config");
    const provider = new HDWalletProvider(process.env.PRIVATE_KEY, `${config.http}/${process.env.HTTP_KEY}`);


}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
