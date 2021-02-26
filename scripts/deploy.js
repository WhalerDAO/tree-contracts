const { network: {provider}, expect } = require('hardhat');
const fs = require('fs')

require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-waffle");

require('dotenv').config();


const main = async function () {

    const config = require("../deploy-configs/get-config");
    const provider = new HDWalletProvider(process.env.PRIVATE_KEY, `${config.http}/${process.env.HTTP_KEY}`);

    const PausedReserve = artifacts.require('PausedReserve');
    const UniswapRouterManipulator = artifacts.require('UniswapRouterManipulator');
    const OracleManipulator = artifacts.require('UniswapOracleManipulator');
    const UniswapPairManipulator = artifacts.require('UniswapPairManipulator');
    const OmniBridgeManipulator = artifacts.require('OmniBridgeManipulator');
}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
