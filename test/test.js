const { getNamedAccounts, deployments, ethers } = require('@nomiclabs/buidler')
const { expect } = require('chai')
const BigNumber = require('bignumber.js')

const { get } = deployments

const config = require('../deploy-configs/get-config')
const HOUR = 60 * 60
const DAY = 24 * HOUR
const PRECISION = BigNumber(1e18).toFixed()
const REG_POOL_TREES = 1e21 // 1000 TREE per regular pool
const ZERO_ADDR = '0x0000000000000000000000000000000000000000'
const SNX_ADDR = '0xc011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f'
const YCRV_ADDR = '0xdf5e0e81dff6faf3a7e52ba697820c5e32d806a8'

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
  const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', config.uniswapRouter)
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
})

describe('TREE', () => {
  let tree

  beforeEach(async () => {
    await setupTest()
    const treeDeployment = await get('TREE')
    tree = await ethers.getContractAt('TREE', treeDeployment.address)
  })

  it('should not have owner', async () => {
    expect(await tree.owner()).to.equal(ZERO_ADDR, 'has non zero owner')
  })

  it('should have correct reserve and rebaser addresses', async () => {
    const reserveDeployment = await get('TREEReserve')
    const rebaserDeployment = await get('TREERebaser')
    expect(await tree.reserve()).to.equal(reserveDeployment.address, 'has wrong reserve address')
    expect(await tree.rebaser()).to.equal(rebaserDeployment.address, 'has wrong rebaser address')
  })
})

describe('Farming', () => {
  let tree

  beforeEach(async () => {
    await setupTest()
    const treeDeployment = await get('TREE')
    tree = await ethers.getContractAt('TREE', treeDeployment.address)
  })

  it('should give correct reward to regular pool', async () => {
    const { deployer } = await getNamedAccounts()

    // get SNX from Uniswap
    const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', config.uniswapRouter)
    const wethAddress = await uniswapRouterContract.WETH()
    const deadline = BigNumber(1e20).toFixed() // a loooooong time in the future
    await uniswapRouterContract.swapExactETHForTokens(0, [wethAddress, SNX_ADDR], deployer, deadline, { from: deployer, value: ethers.utils.parseEther('1'), gasLimit: 2e5 })

    // stake SNX into forest
    const snxContract = await ethers.getContractAt('IERC20', SNX_ADDR)
    const snxBalance = await snxContract.balanceOf(deployer)
    const snxForestDeployment = await get('SNXForest')
    const snxForestContract = await ethers.getContractAt('TREERewards', snxForestDeployment.address)
    await snxContract.approve(snxForestDeployment.address, snxBalance, { from: deployer })
    await snxForestContract.stake(snxBalance, { from: deployer })

    // wait 7 days
    await timeTravel(7 * DAY)

    // withdraw SNX + reward
    await snxForestContract.exit({ from: deployer })

    // should have received all TREE in pool
    expect(await tree.balanceOf(deployer)).to.be.least(BigNumber(REG_POOL_TREES).minus(1e18).toFixed())
    expect(await tree.balanceOf(deployer)).to.be.most(BigNumber(REG_POOL_TREES).toFixed())
  })

  it('should give correct reward to LP pool', async () => {
    const { deployer } = await getNamedAccounts()

    // stake LP tokens into forest
    const uniswapFactoryContract = await ethers.getContractAt('IUniswapV2Factory', config.uniswapFactory)
    const treePairAddress = await uniswapFactoryContract.getPair(tree.address, config.reserveToken)
    const treePairContract = await ethers.getContractAt('IERC20', treePairAddress)
    const lpTokenBalance = await treePairContract.balanceOf(deployer)
    const lpRewardsDeployment = await get('LPRewards')
    const lpRewardsContract = await ethers.getContractAt('TREERewards', lpRewardsDeployment.address)
    await treePairContract.approve(lpRewardsDeployment.address, lpTokenBalance, { from: deployer })
    await lpRewardsContract.stake(lpTokenBalance, { from: deployer })

    // wait 7 days
    await timeTravel(7 * DAY)

    // withdraw LP tokens + reward
    await lpRewardsContract.exit({ from: deployer })

    // should have received all TREE in pool
    expect(await tree.balanceOf(deployer)).to.be.least(BigNumber(config.lpRewardInitial).minus(1e18).toFixed())
    expect(await tree.balanceOf(deployer)).to.be.most(BigNumber(config.lpRewardInitial).toFixed())
  })
})

describe('Rebasing', () => {
  let tree, rebaser, reserve

  beforeEach(async () => {
    await setupTest()
    const treeDeployment = await get('TREE')
    tree = await ethers.getContractAt('TREE', treeDeployment.address)
    const rebaserDeployment = await get('TREERebaser')
    rebaser = await ethers.getContractAt('TREERebaser', rebaserDeployment.address)
    const reserveDeployment = await get('TREEReserve')
    reserve = await ethers.getContractAt('TREEReserve', reserveDeployment.address)
  })

  it('should not rebase when price delta is below threshold', async () => {
    await expect(rebaser.rebase()).to.be.reverted
  })

  it('should rebase when price is above peg by threshold delta', async () => {
    const { deployer } = await getNamedAccounts()

    // purchase yUSD
    const yUSDContract = await ethers.getContractAt('IERC20', config.reserveToken)
    const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', config.uniswapRouter)
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

    // sell yUSD for TREE
    const amount = BigNumber(100).times(1e18).toFixed()
    await yUSDContract.approve(config.uniswapRouter, amount, { from: deployer })
    await uniswapRouterContract.swapExactTokensForTokens(amount, 0, [config.reserveToken, tree.address], deployer, deadline, { from: deployer, gasLimit: 3e5 })

    // wait 12 hours
    await timeTravel(config.oraclePeriod)

    // check TREE price and minted token amount
    const oracleDeployment = await get('UniswapOracle')
    const oracleContract = await ethers.getContractAt('UniswapOracle', oracleDeployment.address)
    await oracleContract.update()
    const price = (await oracleContract.consult(tree.address, PRECISION))
    const priceDelta = price.sub(PRECISION).mul(config.rebaseMultiplier.toString()).div(PRECISION)
    const expectedMintTreeAmount = priceDelta.mul(await tree.totalSupply()).div(PRECISION)

    // rebase
    const lpRewardsDeployment = await get('LPRewards')
    const lpRewardsTreeBalance = await tree.balanceOf(lpRewardsDeployment.address)
    const omniBridgeContract = await ethers.getContractAt('IOmniBridge', config.omniBridge)
    const omniBridgeYUSDBalance = await omniBridgeContract.mediatorBalance(config.reserveToken)
    await expect(rebaser.rebase({ from: deployer, gasLimit: 6e5 }))
      .to.emit(rebaser, 'Rebase').withArgs(expectedMintTreeAmount)

    // check TREE balances
    const TREEUNIReserve = BigNumber((100 * 100) / (100 + 0.997 * 100))
    const expectedSellTREEAmount = TREEUNIReserve.times(200).sqrt().minus(TREEUNIReserve).div(0.997).times(PRECISION)
    const expectedReceiveYUSDAmount = BigNumber(200).minus(TREEUNIReserve.times(200).div(TREEUNIReserve.plus(expectedSellTREEAmount.div(PRECISION).times(0.997)))).times(PRECISION)
    let expectedCharityAmount = expectedReceiveYUSDAmount.times(config.charityCut).div(BigNumber(PRECISION).minus(config.rewardsCut))
    const expectedReserveBalance = ethers.BigNumber.from(expectedReceiveYUSDAmount.minus(expectedCharityAmount).integerValue().toString())
    expectedCharityAmount = ethers.BigNumber.from(expectedCharityAmount.integerValue().toString())
    const expectedLPRewardsBalanceChange = ethers.BigNumber.from(expectedSellTREEAmount.times(config.rewardsCut).div(BigNumber(PRECISION).minus(config.charityCut)).integerValue().toString())
    const actualOmniBridgeYUSDBalanceChange = (await omniBridgeContract.mediatorBalance(config.reserveToken)).sub(omniBridgeYUSDBalance)
    const actualLPRewardsBalanceChange = (await tree.balanceOf(lpRewardsDeployment.address)).sub(lpRewardsTreeBalance)
    const actualReserveBalance = await yUSDContract.balanceOf(reserve.address)
    expect(actualOmniBridgeYUSDBalanceChange).to.be.most(expectedCharityAmount.add(1e9))
    expect(actualOmniBridgeYUSDBalanceChange).to.be.least(expectedCharityAmount.sub(1e9))
    expect(actualLPRewardsBalanceChange).to.be.most(expectedLPRewardsBalanceChange.add(1e9))
    expect(actualLPRewardsBalanceChange).to.be.least(expectedLPRewardsBalanceChange.sub(1e9))
    expect(actualReserveBalance).to.be.most(expectedReserveBalance.add(1e9))
    expect(actualReserveBalance).to.be.least(expectedReserveBalance.sub(1e9))
  })
})

describe('Reserve', () => {
  let tree, rebaser, reserve

  beforeEach(async () => {
    await setupTest()
    const treeDeployment = await get('TREE')
    tree = await ethers.getContractAt('TREE', treeDeployment.address)
    const rebaserDeployment = await get('TREERebaser')
    rebaser = await ethers.getContractAt('TREERebaser', rebaserDeployment.address)
    const reserveDeployment = await get('TREEReserve')
    reserve = await ethers.getContractAt('TREEReserve', reserveDeployment.address)
  })

  it('should sell TREE during rebase', async () => {
    const { deployer } = await getNamedAccounts()

    // purchase yUSD
    const yUSDContract = await ethers.getContractAt('IERC20', config.reserveToken)
    const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', config.uniswapRouter)
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

    // sell yUSD for TREE
    const amount = BigNumber(100).times(1e18).toFixed()
    await yUSDContract.approve(config.uniswapRouter, amount, { from: deployer })
    await uniswapRouterContract.swapExactTokensForTokens(amount, 0, [config.reserveToken, tree.address], deployer, deadline, { from: deployer, gasLimit: 3e5 })

    // wait 12 hours
    await timeTravel(config.oraclePeriod)

    // rebase
    await rebaser.rebase({ from: deployer, gasLimit: 6e5 })

    // check balances
    expect(await yUSDContract.balanceOf(reserve.address)).to.be.gt(0)
    expect(await tree.balanceOf(reserve.address)).to.be.equal(0)
  })

  it('should be able to burn TREE to get reserve token', async () => {
    const { deployer } = await getNamedAccounts()

    // purchase yUSD
    const yUSDContract = await ethers.getContractAt('IERC20', config.reserveToken)
    const uniswapRouterContract = await ethers.getContractAt('IUniswapV2Router02', config.uniswapRouter)
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

    // sell yUSD for TREE
    const amount = BigNumber(10).times(1e18).toFixed()
    await yUSDContract.approve(config.uniswapRouter, amount, { from: deployer })
    await uniswapRouterContract.swapExactTokensForTokens(amount, 0, [config.reserveToken, tree.address], deployer, deadline, { from: deployer, gasLimit: 3e5 })

    // send yUSD to reserve
    const reserveBalance = ethers.BigNumber.from(10).mul(PRECISION)
    await yUSDContract.transfer(reserve.address, reserveBalance, { from: deployer })

    // burn TREE balance and check return
    const treeBalance = await tree.balanceOf(deployer)
    expect(treeBalance).to.be.gt(0)
    const treeTotalSupply = await tree.totalSupply()
    const treeProportion = treeBalance.mul(PRECISION).div(treeTotalSupply)
    const expectedBurnReturn = reserveBalance.mul(treeProportion).div(PRECISION).mul(treeProportion).div(PRECISION)
    const yUSDBalance = await yUSDContract.balanceOf(deployer)
    await reserve.burnTREE(treeBalance, { from: deployer })
    const actualBurnReturn = (await yUSDContract.balanceOf(deployer)).sub(yUSDBalance)
    expect(actualBurnReturn).to.be.equal(expectedBurnReturn)
  })
})
