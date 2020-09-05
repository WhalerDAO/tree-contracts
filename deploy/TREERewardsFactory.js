module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const rewardsDeployResult = await deploy('TREERewards', {
    from: deployer
  })
  if (rewardsDeployResult.newlyDeployed) {
    log(`TREERewards template deployed at ${rewardsDeployResult.address}`)
  }

  const rewardsFactoryDeployResult = await deploy('TREERewardsFactory', {
    from: deployer,
    args: [rewardsDeployResult.address]
  })
  if (rewardsFactoryDeployResult.newlyDeployed) {
    log(`TREERewardsFactory deployed at ${rewardsFactoryDeployResult.address}`)
  }
}
module.exports.tags = ['TREERewardsFactory', 'stage1']
module.exports.dependencies = []
