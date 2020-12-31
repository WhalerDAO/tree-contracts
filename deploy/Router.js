const Router = artifacts.require('Router');
const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");

require("dotenv").config();


const main = async function () {
    
    const config = require("../deploy-configs/v2/get-config");
    const provider = new HDWalletProvider(process.env.PRIVATE_KEY, `${config.infura}/${process.env.INFURA_KEY}`);
    const w = new Web3(provider);
    const accounts = await w.eth.getAccounts();

    router = await Router.new();
    console.log(`Router address: ${router.address}`);
}


main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });