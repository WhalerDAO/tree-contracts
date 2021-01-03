const { network: { provider }, assert } = require('hardhat');
const BigNumber = require('bignumber.js');
const HDWalletProvider = require("@truffle/hdwallet-provider");
const Web3 = require("web3");
var Contract = require("web3-eth-contract");
const {expect} = require('chai');

require('dotenv').config();
const config = require("../deploy-configs/v2/get-config");

// Load contracts
var reserve = loadContract(config, 'reserve');
var rebaser = loadContract(config, "rebaser");
var gov = loadContract(config, "gov");
var tree = loadcontract(config, "tree");
var charity = loadContract(config, "charity");
var dai = loadContract(config, "dai");

const Router = artifacts.require('Router');


var loadContract = function(contractName) {
    let abi = JSON.parse(`../contracts/abi/${contractName}.json`);
    let address = config.contractName.address;

    let contractObj = new Contract(abi, address);
    return contractObj;
}

describe("TREE v2", function () {
    let accounts;
    let deployer;
    let router;

    before(async function () {
        let pk = process.env.PRIVATE_KEY;
        let infura = `${config.infura}/${process.env.INFURA_KEY}`;
        const provider = new HDWalletProvider(pk, infura);
        const w = new Web3(provider);
        accounts = await w.eth.getAccounts();
        deployer = accounts[0];

        // Deploy router
        router = await Router.new(
            gov.address,
            charity.address,
            lpRewards.address,
            omniBridge.address,
            BigNumber(config.charityCut).toFixed(),
            BigNumber(config.rewardsCut).toFixed(),
            BigNumber(config.oldReserveBalance).toFixed(),
            BigNumber(config.treeSupply).toFixed(),
            config.targetPrice,
            BigNumber(config.targetPriceMultiplier).toFixed()
        );
        
    });

    contract("Router", async function() {
        it("Should switch uniswap router used on reserve");
        const gov = provider
        impersonateAccount(GOV);

        await reserve.setUniswapRouter(deployer);
        assert.equal(
            reserve.uniswapRouter(), deployer,
            `Router set to: ${reserve.uniswapRouter()}`
        );
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
/*