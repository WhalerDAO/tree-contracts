const { network: {provider} } = require('hardhat');
const fs = require('fs')

require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-waffle");

require('dotenv').config();
const config = require("../deploy-configs/v2/get-config");

// Import contracts
const UniswapRouterManipulator = artifacts.require('UniswapRouterManipulator');
const OracleManipulator = artifacts.require('UniswapOracleManipulator');
const UniswapPairManipulator = artifacts.require('UniswapPairManipulator');
const OmniBridgeManipulator = artifacts.require('OmniBridgeManipulator');

describe("TREE v1.1", () => {
    
    let deployer;
    let dai;
    let rebaser;
    let reserve;
    let uniswapRouterManipulator;
    let oracleManipulator;
    let uniswapPairManipulator;
    let omniBridgeManipulator;

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

        // Load pre-deployed contracts
        const signer = await ethers.provider.getSigner(config.addresses.gov);
        dai = loadContract('dai', signer);
        rebaser = loadContract('rebaser', signer);
        reserve = loadContract('reserve', signer);

        // Fund gov to submit transactions
        deployer.sendTransaction({to:config.addresses.gov, value:ethers.utils.parseEther('10')});

        // Deploy new contracts from primary address
        uniswapRouterManipulator = await UniswapRouterManipulator.new();
        oracleManipulator = await OracleManipulator.new();
        uniswapPairManipulator = await UniswapPairManipulator.new();
        omniBridgeManipulator = await OmniBridgeManipulator.new();

        // Now we'll impersonate gov and send tx's from that address
        await provider.request({method:'hardhat_impersonateAccount', params:[config.addresses.gov]});

        // Set addresses needed to manipulate our rebaser
        await rebaser.setOracle(oracleManipulator.address);
        await reserve.setUniswapUniswapRouter(uniswapRouterManipulator.address);
        await reserve.setCharity(uniswapRouterManipulator.address);
        await reserve.setUniswapPair(uniswapPairManipulator.address);
        let tx = await reserve.setOmniBridge(omniBridgeManipulator.address);

        // wait for last tx to clear before rebasing
        await tx.wait();
    });

    it("", async function () {
        // check balances
        console.log(`\nReserve DAI balance: ${await dai.balanceOf(reserve.address)}`);
        console.log('Rebasing...');
        let tx  = await rebaser.rebase();
        await tx.wait();
        console.log('Done');
        console.log(`Reserve DAI balance: ${await dai.balanceOf(reserve.address)}`);
        console.log(`RouterManipulator DAI balance: ${await dai.balanceOf(uniswapRouterManipulator.address)}`);
    });
});
