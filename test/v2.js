const { network: { provider }, waffle , web3} = require('hardhat');
const BigNumber = require('bignumber.js');
var Contract = require("web3-eth-contract");
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

    var loadContract = function(contractName) {
        let rawdata = fs.readFileSync(`./contracts/abi/${contractName}.json`);
        let json = JSON.parse(rawdata);
        let address = config.addresses[contractName];
        let contract = new web3.eth.Contract(json, address);
        return contract
    }

    // let pk = process.env.PRIVATE_KEY;
    // let url = `${config.infura}/${process.env.INFURA_KEY}`;
 
    before(async () => {
        accounts = await web3.eth.getAccounts();
        deployer = accounts[0];

        // Pre-deployed contracts
        reserve = loadContract('reserve');
        gov = loadContract("gov");
        var rebaser = loadContract("rebaser");
        // var charity = loadContract("charity");
        var lpRewards = loadContract('lpRewards');
        var omniBridge = loadContract('omniBridge');

        var tree = loadContract("tree");
        var dai = loadContract("dai");

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
            await provider.send('hardhat_impersonateAccount', [gov.options.address]);

            // set uniswap router to point at our new Router.sol
            let newRouterAddr = deployer;
            const tx = await reserve.methods.setUniswapRouter(newRouterAddr).send({from: gov.options.address});
            let receipt = await tx.wait();
            const event = receipt.events.find((e) => e.event === "setUniswapRouter");
            expect(event).to.not.be.undefined;
            // await expectEvent(receipt, 'SetUniswapRouter', {
            //     _newValue: newRouterAddr
            // });
            // await expect(reserve.methods.setUniswapRouter(newsssRouterAddr))
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
const setNextBlockTime = async time => provider.send('evm_setNextBlockTimestamp', [time]);
const mineNextBlock = async () => provider.send('evm_mine');

const impersonateAccount = async address => provider.send('hardhat_impersonateAccount', [address]);
const stopImpersonatingAccount = async address => provider.send('hardhat_stopImpersonatingAccount', [address]);

const takeSnapshot = async () => provider.send('evm_snapshot');
const revertToSnapshot = async id => provider.send('evm_revert', [id]);
const reset = async () => provider.send('hardhat_reset');
*/