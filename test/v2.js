const { network: { provider } } = require('hardhat');
const BigNumber = require('bignumber.js');
const HDWalletProvider = require("@truffle/hdwallet-provider");
const Web3 = require("web3");
var Contract = require("web3-eth-contract");
const {expect, assert} = require('chai');
const fs = require('fs')

require("@nomiclabs/hardhat-truffle5");
require('dotenv').config();
const config = require("../deploy-configs/v2/get-config");

// Load contracts
const Router = artifacts.require('Router');


var loadContract = function(contractName) {
    let rawdata = fs.readFileSync(`./contracts/abi/${contractName}.json`);
    let json = JSON.parse(rawdata);
    let address = config.addresses[contractName];
    return new Contract(json, address);
}

describe("TREE v2", function () {
    let accounts;
    let deployer;
    let router;

    // Pre-deployed contracts
    var reserve = loadContract('reserve');
    var rebaser = loadContract("rebaser");
    var gov = loadContract("gov");
    // var charity = loadContract("charity");
    var lpRewards = loadContract('lpRewards');
    var omniBridge = loadContract('omniBridge');
    
    var tree = loadContract("tree");
    var dai = loadContract("dai");

    before(async function () {
        let pk = process.env.PRIVATE_KEY;
        let url = `${config.infura}/${process.env.INFURA_KEY}`;
        const provider = new HDWalletProvider(pk, url);
        const w = new Web3(provider);
        accounts = await w.eth.getAccounts();
        deployer = accounts[0];

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
            await expect(reserve.methods.setUniswapRouter(newRouterAddr))
                .to.emit(newRouterAddr, "SetUniswapRouter");
            
            // let uniswapRouter = await reserve.uniswapRouter.call();
            // make sure SetUniswapRouter(newRouterAddr) was emitted
            // console.log(uniswapRouter);
            // assert.equal(
            //     await uniswapRouter, newRouterAddr,
            //     `Router set to: ${uniswapRouter}`
            // );
            assert.equal(1,1);
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