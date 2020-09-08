const BigNumber = require('bignumber.js')

module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log, save } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/mainnet.json')

  const treeRewardsFactoryDeployment = await get('TREERewardsFactory')
  const treeRewardsFactoryContract = await ethers.getContractAt('TREERewardsFactory', treeRewardsFactoryDeployment.address)
  const treeDeployment = await get('TREE')
  const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
  const uniswapFactoryContract = await ethers.getContractAt('IUniswapV2Factory', config.uniswapFactory)
  const treePairAddress = await uniswapFactoryContract.getPair(treeDeployment.address, config.reserveToken)

  // deploy
  const starttime = config.rewardStartTimestamp
  const treeRewardsAddress = await treeRewardsFactoryContract.callStatic.createRewards(
    starttime,
    treePairAddress, // stake TREE-yCRV UNI-V2 LP token
    treeDeployment.address, // reward TREE
    { from: deployer }
  )
  const deployReceipt = await treeRewardsFactoryContract.createRewards(
    starttime,
    treePairAddress, // stake TREE-yCRV UNI-V2 LP token
    treeDeployment.address, // reward TREE
    { from: deployer }
  )
  const lpRewardsContract = await ethers.getContractAt('TREERewards', treeRewardsAddress)
  await save('LPRewards', { abi: lpRewardsContract.abi, address: treeRewardsAddress, receipt: deployReceipt })
  log(`LPRewards deployed at ${treeRewardsAddress}`)

  // mint TREE and notify reward
  await lpRewardsContract.setRewardDistribution(deployer, { from: deployer })
  await treeContract.ownerMint(lpRewardsContract.address, BigNumber(config.lpRewardInitial).toFixed(), { from: deployer })
  log(`Minted ${BigNumber(config.lpRewardInitial).div(1e18).toFixed()} TREE to LPRewards at ${treeRewardsAddress}`)
  await lpRewardsContract.notifyRewardAmount(BigNumber(config.lpRewardInitial).toFixed(), { from: deployer, gasLimit: 7e4 })
}
module.exports.tags = ['LPRewards', 'stage1']
module.exports.dependencies = ['TREE', 'TREERewardsFactory', 'UniswapPair']
module.exports.skip = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { getOrNull } = deployments
  const lpRewardsDeployment = await getOrNull('LPRewards')
  return !!lpRewardsDeployment
}
