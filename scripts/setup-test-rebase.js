const { getNamedAccounts, deployments, ethers } = require('@nomiclabs/buidler')
const BigNumber = require('bignumber.js')

const config = require('../deploy-configs/get-config')
const UNI_ROUTER_ADDR = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
const HOUR = 60 * 60

// travel `time` seconds forward in time
const timeTravel = (time) => {
  return ethers.provider.send('evm_increaseTime', [time])
}

async function main() {
  const { get } = deployments
  const { deployer } = await getNamedAccounts()

  // deploy stage 1
  await deployments.fixture('stage1')

  // provide liquidity to TREE-dai UNI-V2 pair

  const amount = BigNumber(100).times(1e18).toFixed()
  const daiContract = await ethers.getContractAt('IERC20', config.reserveToken)
  const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', UNI_ROUTER_ADDR)
  const wethAddress = await uniswapRouterContract.WETH()
  const deadline = BigNumber(1e20).toFixed() // a loooooong time in the future

  // buy DAI with ETH
  await uniswapRouterContract.swapExactETHForTokens(0, [wethAddress, config.reserveToken], deployer, deadline, { from: deployer, value: ethers.utils.parseEther('5'), gasLimit: 2e5 })

  // add Uniswap liquidity
  const treeDeployment = await get('TREE')
  const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
  await treeContract.approve(uniswapRouterContract.address, amount, { from: deployer })
  await daiContract.approve(uniswapRouterContract.address, amount, { from: deployer })
  await uniswapRouterContract.addLiquidity(treeContract.address, config.reserveToken, amount, amount, 0, 0, deployer, deadline, { from: deployer, gasLimit: 3e6 })

  // deploy stage 2
  const oracleDeployment = await get('UniswapOracle')
  const oracleContract = await ethers.getContractAt('UniswapOracle', oracleDeployment.address)
  await oracleContract.init({ from: deployer })

  // wait for farming activation
  const travelTime = config.rewardStartTimestamp - Math.floor(Date.now() / 1e3)
  if (travelTime > 0) {
    await timeTravel(travelTime)
  }

  // setup rebase

  // sell dai for TREE
  await daiContract.approve(UNI_ROUTER_ADDR, amount, { from: deployer })
  await uniswapRouterContract.swapExactTokensForTokens(amount, 0, [config.reserveToken, treeDeployment.address], deployer, deadline, { from: deployer, gasLimit: 3e5 })

  // wait till next oracle update
  await timeTravel(config.oraclePeriod)

  // check TREE price and minted token amount
  await oracleContract.update({ from: deployer })

  // rebase
  const rebaserDeployment = await get('TREERebaser')
  const rebaser = await ethers.getContractAt('TREERebaser', rebaserDeployment.address)
  await rebaser.rebase({ from: deployer })
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
