const BigNumber = require('bignumber.js')

module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log, save } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/mainnet.json')
  const forests = require('../deploy-configs/forests.json')

  const treeDeployment = await get('TREE')
  const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
  const treeRewardsFactoryDeployment = await get('TREERewardsFactory')
  const treeRewardsFactoryContract = await ethers.getContractAt('TREERewardsFactory', treeRewardsFactoryDeployment.address)

  for (const { symbol, address, treeAmount } of forests) {
    const forestName = `${symbol}Forest`
    const starttime = config.rewardStartTimestamp
    const treeRewardsAddress = await treeRewardsFactoryContract.callStatic.createRewards(
      starttime,
      address, // stake `symbol` token
      treeDeployment.address, // reward TREE
      { from: deployer }
    )
    const deployReceipt = await treeRewardsFactoryContract.createRewards(
      starttime,
      address, // stake `symbol` token
      treeDeployment.address, // reward TREE
      { from: deployer }
    )
    const forestContract = await ethers.getContractAt('TREERewards', treeRewardsAddress)
    await save(forestName, { abi: forestContract.abi, address: treeRewardsAddress, receipt: deployReceipt })
    log(`${forestName} deployed at ${treeRewardsAddress}`)

    // mint TREE and notify reward
    await forestContract.setRewardDistribution(deployer, { from: deployer })
    await treeContract.ownerMint(forestContract.address, BigNumber(treeAmount).toFixed(), { from: deployer })
    log(`Minted ${BigNumber(treeAmount).div(1e18).toFixed()} TREE to ${forestName} at ${treeRewardsAddress}`)
    await forestContract.notifyRewardAmount(BigNumber(treeAmount).toFixed(), { from: deployer, gasLimit: 7e4 })
  }
}
module.exports.tags = ['Forests', 'stage1']
module.exports.dependencies = ['TREE', 'TREERewardsFactory']
module.exports.skip = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { getOrNull } = deployments
  const forests = require('../deploy-configs/forests.json')
  for (const { symbol } of forests) {
    const forestName = `${symbol}Forest`
    const forestDeployment = await getOrNull(forestName)
    if (!forestDeployment) {
      return false
    }
  }
  return true
}
