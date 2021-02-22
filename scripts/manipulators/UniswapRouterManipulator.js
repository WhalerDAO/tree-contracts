const Router = artifacts.require('Router');
const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const BigNumber = require("bignumber.js");

require("dotenv").config();


const main = async function () {
    
    const config = require("../deploy-configs/v2/get-config");
    const provider = new HDWalletProvider(process.env.PRIVATE_KEY, `${config.http}/${process.env.HTTP_KEY}`);
    const w = new Web3(provider);
    const accounts = await w.eth.getAccounts();

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
    console.log(`Router address: ${router.address}`);
}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });