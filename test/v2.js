const { network: { provider } } = require('hardhat');
const BigNumber = require('bignumber.js');
const {expect} = require('chai');
const config = require("../deploy-configs/v2/get-config");
require('dotenv').config();


const TREE = '0xCE222993A7E4818E0D12BC56376c5a60f92A5783';
const RESERVE = '0x390a8Fb3fCFF0bB0fCf1F91c7E36db9c53165d17';
const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
const REBASER = '0x504397F81b1676710815f09CC3F3e1F3ee46c455';
const GOV = config.gov;
const CHARITY = config.charity;

const Router = artifacts.require('Router');


const setNextBlockTime = async time => provider.send('evm_setNextBlockTimestamp', [time]);
const mineNextBlock = async () => provider.send('evm_mine');

const impersonateAccount = async address => provider.send('hardhat_impersonateAccount', [address]);
const stopImpersonatingAccount = async address => provider.send('hardhat_stopImpersonatingAccount', [address]);

const takeSnapshot = async () => provider.send('evm_snapshot');
const revertToSnapshot = async id => provider.send('evm_revert', [id]);
const reset = async () => provider.send('hardhat_reset');


describe("TREE v2", function () {
    let accounts;

    before(async function () {
        const config = require("../deploy-configs/v2/get-config");
        const provider = new HDWalletProvider(process.env.PRIVATE_KEY, `${config.infura}/${process.env.INFURA_KEY}`);
        const w = new Web3(provider);
        accounts = await w.eth.getAccounts();

        // Deploy router
        router = await Router.new(
            config.gov,
            config.charity,
            config.lpRewards,
            config.omniBridge,
            BigNumber(config.charityCut).toFixed(),
            BigNumber(config.rewardsCut).toFixed(),
            BigNumber(config.oldReserveBalance).toFixed(),
            BigNumber(config.treeSupply).toFixed(),
            config.targetPrice,
            BigNumber(config.targetPriceMultiplier).toFixed()
        );
    });

    describe("Migrations", function() {
        it("Should switch uniswap oracle used on reserve");
        
    });

});