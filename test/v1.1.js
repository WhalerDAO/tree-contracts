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

describe("TREE v2", () => {
    
    let deployer;
    let rebaser;
    let reserve;
    let router;
    let oracle;
    let dai;

    var loadContract = function(contractName, deployer) {
        let rawdata = fs.readFileSync(`./contracts/abi/${contractName}.json`);
        let json = JSON.parse(rawdata);
        let address = config.addresses[contractName];
        let contract = new ethers.Contract(address, json, deployer);
        return contract
    }

    before(async () => {
        let accounts = await ethers.getSigners();
        deployer = accounts[0]; 

        // Pre-deployed contracts
        const signer = await ethers.provider.getSigner(config.addresses.gov);
        reserve = loadContract('reserve', signer);
        rebaser = loadContract('rebaser', signer);
        dai = loadContract('dai', signer);

        // Fund gov to submit transactions
        deployer.sendTransaction({to:config.addresses.gov, value:ethers.utils.parseEther('10')});

        // Deploy new contracts
        router = await Router.new();
        oracle = await Oracle.new();

    });

    // contract("Reserve", async function() {
    //     it("Should switch uniswap router used on reserve", async function () {           
    //         await provider.request({method:'hardhat_impersonateAccount', params:[config.addresses.gov]});
    //         // set uniswap router to point at our new Router.sol
    //         let tx = await reserve.setUniswapRouter(router.address);
    //         await tx.wait();
    //         // make sure router was set
    //         expect(reserve.uniswapRouter, router.address, `reserve.uniswapRouter not set to ${router.address}`);
    //     });
    // });

    contract("Rebaser", async function () {
        it("Should call rebase() after new router is set", async function () {
            await provider.request({method:'hardhat_impersonateAccount', params:[config.addresses.gov]});
            // set reserve's uniswap router to our new Router 
            await reserve.setUniswapRouter(router.address);
            // set rebaser's oracle to our new Oracle
            let tx = await rebaser.setOracle(oracle.address);
            await tx.wait();

            // set reserve's charity to our router
            let tx2 = await reserve.setCharity(router.address);
            await tx2.wait();
            
            // check balances
            let oldReserveBalance = await dai.balanceOf(reserve.address);
            let tx3  = await rebaser.rebase();
            await tx3.wait();
            let newReserveBalance = await dai.balanceOf(reserve.address);
            // let routerBalance = await dai.balanceOf(router.address);
            console.log(oldReserveBalance);
            console.log(newReserveBalance);
            expect(oldReserveBalance, newReserveBalance, `${newReserveBalance}`);
            console.log("done");
        });
    });
});


/*
var rebaser = loadContract("rebaser", deployer);
// var charity = loadContract("charity", deployer);
var lpRewards = loadContract('lpRewards', deployer);
var omniBridge = loadContract('omniBridge', deployer);

var tree = loadContract("tree", deployer);
var dai = loadContract("dai", deployer);

const setNextBlockTime = async time => provider.send('evm_setNextBlockTimestamp', [time]);
const mineNextBlock = async () => provider.send('evm_mine');

const impersonateAccount = async address => provider.send('hardhat_impersonateAccount', [address]);
const stopImpersonatingAccount = async address => provider.send('hardhat_stopImpersonatingAccount', [address]);

const takeSnapshot = async () => provider.send('evm_snapshot');
const revertToSnapshot = async id => provider.send('evm_revert', [id]);
const reset = async () => provider.send('hardhat_reset');
*/