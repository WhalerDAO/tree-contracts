const { getNamedAccounts, deployments, ethers } = require('@nomiclabs/buidler')
const BigNumber = require('bignumber.js')

const config = require('../deploy-configs/get-config')
const UNI_ROUTER_ADDR = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
const YCRV_ADDR = '0xdf5e0e81dff6faf3a7e52ba697820c5e32d806a8'

// travel `time` seconds forward in time
const timeTravel = (time) => {
  return ethers.provider.send('evm_increaseTime', [time])
}

async function main () {
  const { get } = deployments
  const { deployer } = await getNamedAccounts()

  // deploy stage 1
  await deployments.fixture('stage1')

  // provide liquidity to TREE-yUSD UNI-V2 pair

  const amount = BigNumber(100).times(1e18).toFixed()
  const yUSDContract = await ethers.getContractAt('IERC20', config.reserveToken)
  const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', UNI_ROUTER_ADDR)
  const wethAddress = await uniswapRouterContract.WETH()
  const deadline = BigNumber(1e20).toFixed() // a loooooong time in the future
  // buy yCRV with ETH
  await uniswapRouterContract.swapExactETHForTokens(0, [wethAddress, YCRV_ADDR], deployer, deadline, { from: deployer, value: ethers.utils.parseEther('5'), gasLimit: 2e5 })
  // deposit yCRV into yUSD vault
  const yCRVContract = await ethers.getContractAt('IERC20', YCRV_ADDR)
  const yVaultABI = [{ constant: false, inputs: [{ internalType: 'uint256', name: '_amount', type: 'uint256' }], name: 'deposit', outputs: [], payable: false, stateMutability: 'nonpayable', type: 'function' }]
  const yUSDVault = await ethers.getContractAt(yVaultABI, config.reserveToken)
  const yCRVBalance = await yCRVContract.balanceOf(deployer)
  await yCRVContract.approve(config.reserveToken, yCRVBalance, { from: deployer })
  await yUSDVault.deposit(yCRVBalance, { from: deployer })
  // add Uniswap liquidity
  const treeDeployment = await get('TREE')
  const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
  await treeContract.approve(uniswapRouterContract.address, amount, { from: deployer })
  await yUSDContract.approve(uniswapRouterContract.address, amount, { from: deployer })
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
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
