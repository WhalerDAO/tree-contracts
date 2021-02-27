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
    let pausedReserve = await PausedReserve.new();
    console.log(`pausedReserve: deployed at ${pausedReserve.address}`);

    // Deploy the manipulator contracts
    // let uniswapRouterManipulator = await UniswapRouterManipulator.new();
    // console.log(`uniswapRouterManipulator: deployed at ${uniswapRouterManipulator.address}`);
    
    // let oracleManipulator = await OracleManipulator.new();
    // console.log(`oracleManipulator: deployed at ${oracleManipulator.address}`);
    
    // let uniswapPairManipulator = await UniswapPairManipulator.new();
    // console.log(`uniswapPairManipulator: deployed at ${uniswapPairManipulator.address}`);
    
    // let omniBridgeManipulator = await OmniBridgeManipulator.new();
    // console.log(`omniBridgeManipulator: deployed at ${omniBridgeManipulator.address}`);
}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
