const { network: {provider}, expect } = require('hardhat');
const fs = require('fs')

require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-waffle");

require('dotenv').config();

const config = require("../deploy-configs/get-config");

// Import contracts
const PausedReserve = artifacts.require('PausedReserve');
const UniswapRouterManipulator = artifacts.require('UniswapRouterManipulator');
const OracleManipulator = artifacts.require('UniswapOracleManipulator');
const UniswapPairManipulator = artifacts.require('UniswapPairManipulator');
const OmniBridgeManipulator = artifacts.require('OmniBridgeManipulator');

describe("TREE v1.1", () => {
    
    let tx;
    let user;
    let dai;
    let rebaser;
    let reserve;
    let pausedReserve;
    let uniswapRouterManipulator;
    let oracleManipulator;
    let uniswapPairManipulator;
    let omniBridgeManipulator;
    let oldReserveDaiBalance;

    var loadContract = function(contractName, deployer) {
        let rawdata = fs.readFileSync(`./contracts/abi/${contractName}.json`);
        let json = JSON.parse(rawdata);
        let address = config.addresses[contractName];
        let contract = new ethers.Contract(address, json, deployer);
        return contract;
    }

    before(async () => {
        let accounts = await ethers.getSigners();
        user = accounts[0]; 

        // Load pre-deployed contracts
        const signer = await ethers.provider.getSigner(config.addresses.gov);
        dai = loadContract('dai', signer);
        rebaser = loadContract('rebaser', signer);
        reserve = loadContract('reserve', signer);

        // Fund gov to submit transactions and impersonate the gov address
        await user.sendTransaction({to:config.addresses.gov, value:ethers.utils.parseEther('10')});
        await provider.request({method:'hardhat_impersonateAccount', params:[config.addresses.gov]});

        // Deploy new contracts
        pausedReserve = await PausedReserve.new();
        uniswapRouterManipulator = await UniswapRouterManipulator.new();
        oracleManipulator = await OracleManipulator.new();
        uniswapPairManipulator = await UniswapPairManipulator.new();
        omniBridgeManipulator = await OmniBridgeManipulator.new();

        // Set addresses needed to manipulate the reserve & rebaser contracts
        await reserve.setCharity(pausedReserve.address);
        await reserve.setUniswapRouter(uniswapRouterManipulator.address);
        await rebaser.setOracle(oracleManipulator.address);
        await reserve.setUniswapPair(uniswapPairManipulator.address);
        tx = await reserve.setOmniBridge(omniBridgeManipulator.address);

        // wait for last tx to clear
        await tx.wait();
    });

    it("Manipulated rebase sends all DAI from reserve v1.0 to reserve v1.1", async function () {
        
        oldReserveDaiBalance = await dai.balanceOf(reserve.address);
        tx = await rebaser.rebase();
        await tx.wait();

        let newReserveDaiBalance = await dai.balanceOf(pausedReserve.address);
        expect(oldReserveDaiBalance).to.equal(newReserveDaiBalance);
    });

    it("Reserve v1.1 can withdraw a defined amount of DAI if tx sent from gov", async function () {
        
        await pausedReserve.withdraw(user.address, 123456789, false, {from:config.addresses.gov});
        let userDaiBalance = await dai.balanceOf(user.address);
        
        expect(userDaiBalance).to.equal(123456789);
    });

    it("Reserve v1.1 can withdraw max DAI if tx sent from gov", async function () { 
        
        await provider.request({method:'hardhat_impersonateAccount', params:[config.addresses.gov]});
        await pausedReserve.withdraw(user.address, 0, true, {from:config.addresses.gov});
        
        let newReserveDaiBalance = await dai.balanceOf(pausedReserve.address);
        let userDaiBalance = await dai.balanceOf(user.address);

        expect(newReserveDaiBalance).to.equal(0);
        expect(userDaiBalance).to.equal(oldReserveDaiBalance);
    });
});
