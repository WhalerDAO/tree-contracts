const BigNumber = require('bignumber.js')

module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { deploy, get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/mainnet.json')
  const forests = require('../deploy-configs/forests.json')

  const treeDeployment = await get('TREE')

  for (const { symbol, address, treeAmount } of forests) {
    const forestName = `${symbol}Forest`
    const deployResult = await deploy(forestName, {
      from: deployer,
      contract: 'TREERewards',
      args: [
        Math.floor(Date.now() / 1e3) + config.rewardWaitTime,
        address, // stake `symbol` token
        treeDeployment.address // reward TREE
      ]
    })

    // mint TREE and notify reward
    if (deployResult.newlyDeployed) {
      log(`${forestName} deployed at ${deployResult.address}`)
      const forestContract = await ethers.getContractAt('TREERewards', deployResult.address)
      const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
      await forestContract.setRewardDistribution(deployer, { from: deployer })
      await treeContract.ownerMint(forestContract.address, BigNumber(treeAmount).toFixed(), { from: deployer })
      log(`Minted ${BigNumber(treeAmount).div(1e18).toFixed()} TREE to ${forestName} at ${deployResult.address}`)
      await forestContract.notifyRewardAmount(BigNumber(treeAmount).toFixed(), { from: deployer })
    }
  }
}
module.exports.tags = ['Forests', 'stage1']
module.exports.dependencies = ['TREE']
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
