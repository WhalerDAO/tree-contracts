const { network } = require('hardhat');

require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-waffle");

const PausedReserve = artifacts.require('PausedReserve');
const UniswapRouterManipulator = artifacts.require('UniswapRouterManipulator');
const OracleManipulator = artifacts.require('UniswapOracleManipulator');
const UniswapPairManipulator = artifacts.require('UniswapPairManipulator');
const OmniBridgeManipulator = artifacts.require('OmniBridgeManipulator');

require('dotenv').config();


const main = async function () {

    // Deploy the new reserve
    console.log(`Deploying PausedReserve...`)
    let pausedReserve = await PausedReserve.new();
    console.log(`PausedReserve: deployed at ${pausedReserve.address}`);

    // Deploy the manipulator contracts
    console.log(`Deploying UniswapRouterManipulator...`)
    let uniswapRouterManipulator = await UniswapRouterManipulator.new();
    console.log(`UniswapRouterManipulator: deployed at ${uniswapRouterManipulator.address}`);

    console.log(`Deploying OracleManipulator...`)
    let oracleManipulator = await OracleManipulator.new();
    console.log(`OracleManipulator: deployed at ${oracleManipulator.address}`);

    console.log(`Deploying UniswapPairManipulator...`)
    let uniswapPairManipulator = await UniswapPairManipulator.new();
    console.log(`UniswapPairManipulator: deployed at ${uniswapPairManipulator.address}`);
    
    console.log(`Deploying OmniBridgeManipulator...`)
    let omniBridgeManipulator = await OmniBridgeManipulator.new();
    console.log(`OmniBridgeManipulator: deployed at ${omniBridgeManipulator.address}`);
}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
