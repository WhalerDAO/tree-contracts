module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const deployResult = await deploy('TREE', {
    from: deployer
  })
  if (deployResult.newlyDeployed) {
    log(`TREE deployed at ${deployResult.address}`)
  }
}
module.exports.tags = ['TREE', 'stage1']
module.exports.dependencies = []
