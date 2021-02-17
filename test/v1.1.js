const { network: {provider} } = require('hardhat');
const BigNumber = require('bignumber.js');
const {expect, assert} = require('chai');
const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const fs = require('fs')

require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-waffle");

require('dotenv').config();
const config = require("../deploy-configs/v2/get-config");
const { equal } = require('assert');

// Import contracts
const Router = artifacts.require('Router');
const Oracle = artifacts.require('UniswapOracleManipulator');
const UniswapPair = artifacts.require('UniswapPairManipulator');
const OmniBridge = artifacts.require('OmniBridgeManipulator');

describe("TREE v1.1", () => {
    
    let deployer;
    let dai;
    let rebaser;
    let reserve;
    let router;
    let oracle;
    let uniswapPair;
    let omniBridge;

    var loadContract = function(contractName, deployer) {
        let rawdata = fs.readFileSync(`./contracts/abi/${contractName}.json`);
        let json = JSON.parse(rawdata);
        let address = config.addresses[contractName];
        let contract = new ethers.Contract(address, json, deployer);
        return contract;
    }

    before(async () => {
        let accounts = await ethers.getSigners();
        deployer = accounts[0]; 

        // Pre-deployed contracts
        const signer = await ethers.provider.getSigner(config.addresses.gov);
        dai = loadContract('dai', signer);
        rebaser = loadContract('rebaser', signer);
        reserve = loadContract('reserve', signer);

        // Fund gov to submit transactions
        deployer.sendTransaction({to:config.addresses.gov, value:ethers.utils.parseEther('10')});

        // Deploy new contracts
        router = await Router.new();
        oracle = await Oracle.new();
        uniswapPair = await UniswapPair.new();
        omniBridge = await OmniBridge.new();
    });

    it("", async function () {
        let tx;
        await provider.request({method:'hardhat_impersonateAccount', params:[config.addresses.gov]});

        // set rebaser's oracle to our new Oracle
        tx = await rebaser.setOracle(oracle.address);
        await tx.wait();
        
        // set reserve's uniswap router to our new Router 
        tx = await reserve.setUniswapRouter(router.address);
        await tx.wait();
        
        // set reserve's charity to our router
        tx = await reserve.setCharity(router.address);
        await tx.wait();
        
        // set reserve's uniswapPair to our UniswapPairManipulator
        tx = await reserve.setUniswapPair(uniswapPair.address);
        await tx.wait();

        // set reserve's omniBridge to our OmniBridgeManipulator
        tx = await reserve.setOmniBridge(omniBridge.address);
        await tx.wait();

        // check balances
        console.log(`\nReserve DAI balance: ${await dai.balanceOf(reserve.address)}`);
        console.log('Rebasing...');
        tx  = await rebaser.rebase();
        await tx.wait();
        console.log('Done');
        console.log(`Reserve DAI balance: ${await dai.balanceOf(reserve.address)}`);
        console.log(`Router DAI balance: ${await dai.balanceOf(router.address)}`);
    });
});
