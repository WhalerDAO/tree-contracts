module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log } = deployments
  const { deployer } = await getNamedAccounts()

  const treeDeployment = await get('TREE')
  const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
  const treeOwner = await treeContract.owner()
  if (treeOwner !== '0x0000000000000000000000000000000000000000') {
    await treeContract.renounceOwnership({ from: deployer })
    log('Burned TREE admin key')
  }

  const treeReserveDeployment = await get('TREEReserve')
  const treeReserveContract = await ethers.getContractAt('TREEReserve', treeReserveDeployment.address)
  const treeReserveOwner = await treeReserveContract.owner()
  if (treeReserveOwner !== '0x0000000000000000000000000000000000000000') {
    await treeReserveContract.renounceOwnership({ from: deployer })
    log('Burned TREEReserve admin key')
  }

  const lpRewardsDeployment = await get('LPRewards')
  const lpRewardsContract = await ethers.getContractAt('TREERewards', lpRewardsDeployment.address)
  const rewardDistributionAddress = await lpRewardsContract.rewardDistribution()
  if (treeReserveDeployment.address.toLowerCase() !== rewardDistributionAddress.toLowerCase()) {
    await lpRewardsContract.setRewardDistribution(treeReserveDeployment.address, { from: deployer })
    log(`Set rewardDistribution of LPRewards to TREEReserve at ${treeReserveDeployment.address}`)
    await lpRewardsContract.renounceOwnership({ from: deployer })
    log('Burned LPRewards admin key')
  }

  const forests = require('../deploy-configs/forests.json')
  for (const { symbol } of forests) {
    const forestName = `${symbol}Forest`
    const forestDeployment = await get(forestName)
    const forestContract = await ethers.getContractAt('TREERewards', forestDeployment.address)
    const rewardDistributionAddress = await forestContract.rewardDistribution()
    if (treeReserveDeployment.address.toLowerCase() !== rewardDistributionAddress.toLowerCase()) {
      await forestContract.setRewardDistribution(treeReserveDeployment.address, { from: deployer })
      log(`Set rewardDistribution of ${forestName} to TREEReserve at ${treeReserveDeployment.address}`)
      await forestContract.renounceOwnership({ from: deployer })
      log(`Burned ${forestName} admin key`)
    }
  }
}
module.exports.tags = ['burn-admin-keys', 'stage1']
module.exports.dependencies = ['LPRewards', 'TREE', 'TREEReserve', 'Forests']
module.exports.runAtTheEnd = true
