const { waffle, deployments, ethers } = require('@nomiclabs/buidler')
const chai = require('chai')
const BigNumber = require('bignumber.js')

const config = require('../deploy-configs/mainnet.json')
const HOUR = 60 * 60

// travel `time` seconds forward in time
const timeTravel = (time) => {
  return ethers.provider.send('evm_increaseTime', [time])
}

const setupTest = deployments.createFixture(async ({ deployments, getNamedAccounts, ethers }, options) => {
  const { get } = deployments
  const { deployer } = await getNamedAccounts()

  // deploy stage 1
  await deployments.fixture('stage1')

  // provide liquidity to TREE-yUSD UNI-V2 pair
  const amount = BigNumber(100).times(1e18).toFixed()
  const yUSDContract = await ethers.getContractAt('IERC20', config.reserveToken)
  const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D')
  const wethAddress = await uniswapRouterContract.WETH()
  const deadline = BigNumber(1e20).toFixed() // a loooooong time in the future
  const usdtAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7'
  await uniswapRouterContract.swapExactETHForTokens(0, [wethAddress, usdtAddress, config.reserveToken], deployer, deadline, { from: deployer, value: ethers.utils.parseEther('5'), gasLimit: 2e5 })
  const treeDeployment = await get('TREE')
  const treeContract = await ethers.getContractAt('IERC20', treeDeployment.address)
  await treeContract.approve(uniswapRouterContract.address, amount, { from: deployer })
  await yUSDContract.approve(uniswapRouterContract.address, amount, { from: deployer })
  await uniswapRouterContract.addLiquidity(treeContract.address, config.reserveToken, amount, amount, 0, 0, deployer, deadline, { from: deployer, gasLimit: 3e6 })

  // deploy stage 2
  const oracleDeployment = await get('UniswapOracle')
  const oracleContract = await ethers.getContractAt('UniswapOracle', oracleDeployment.address)
  await oracleContract.init({ from: deployer })

  // wait 12 hours for rebase activation
  await timeTravel(12 * HOUR)
})

describe('TREE', () => {
  beforeEach(async () => {
    await setupTest()
  })

  it('test1', async () => {
    console.log('1')
  })

  it('test2', async () => {
    console.log('2')
  })
})
