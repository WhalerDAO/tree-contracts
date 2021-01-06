const { network: { provider }, waffle, ethers } = require('hardhat');
const BigNumber = require('bignumber.js');
const {expect, assert} = require('chai');
const { expectEvent } = require('@openzeppelin/test-helpers');
const fs = require('fs')

require("@nomiclabs/hardhat-truffle5");
// const {web3} = require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-waffle");

require('dotenv').config();
const config = require("../deploy-configs/v2/get-config");
const { equal } = require('assert');

// Load contracts
const Router = artifacts.require('Router');


describe("TREE v2", () => {
    let accounts;
    let deployer;
    let gov;
    let reserve;
    let router;

    var loadContract = function(contractName, deployer) {
        let rawdata = fs.readFileSync(`./contracts/abi/${contractName}.json`);
        let json = JSON.parse(rawdata);
        let address = config.addresses[contractName];
        let contract = new ethers.Contract(address, json, deployer);
        return contract
    }

    before(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];

        // Pre-deployed contracts
        reserve = loadContract('reserve', deployer);
        gov = loadContract("gov", deployer);

        // Deploy router
        router = await Router.new(
            config.addresses.gov,
            config.addresses.gov, // CHARITY
            config.addresses.lpRewards,
            config.addresses.omniBridge,
            BigNumber(config.charityCut).toFixed(),
            BigNumber(config.rewardsCut).toFixed(),
            BigNumber(config.oldReserveBalance).toFixed(),
            BigNumber(config.treeSupply).toFixed(),
            config.targetPrice,
            BigNumber(config.targetPriceMultiplier).toFixed()
        );

    });

    contract("Router", async function() {
        it("Should switch uniswap router used on reserve", async function () {
            
            // send funds to gov address
            deployer.sendTransaction({to:gov.address, value:ethers.utils.parseEther('10')});

            await provider.request({method:'hardhat_impersonateAccount', params:[gov.address]});

            // set uniswap router to point at our new Router.sol
            const tx = await reserve.setUniswapRouter(router.address);
            let receipt = await tx.wait();
            
            const event = tx.events.find((e) => e.event === "setUniswapRouter");
            expect(event).to.not.be.undefined;

            // await expectEvent(receipt, 'SetUniswapRouter', {
            //     _newValue: newRouterAddr
            // });
            // await expect(
            //     reserve.methods.setUniswapRouter(newRouterAddr).send({from:gov.address})
            //     )
            //     .to.emit(newRouterAddr, "SetUniswapRouter");
            
            // let uniswapRouter = reserve.uniswapRouter;
            // expect(uniswapRouter), newRouterAddr, `${newRouterAddr}`);
            // make sure SetUniswapRouter(newRouterAddr) was emitted
            // console.log(uniswapRouter.address);
            // assert.equal(
            //     await uniswapRouter, newRouterAddr,
            //     `Router set to: ${uniswapRouter}`
            // );
            // assert.equal(1,1);
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