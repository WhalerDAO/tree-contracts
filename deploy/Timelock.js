module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../v1/deploy-configs/get-config')

  const deployResult = await deploy('Timelock', {
    from: deployer,
    args: [
      deployer, // set deployer as temporary admin
      config.timelockLength,
      config.amb,
      config.l2ChainID
    ]
  })
  if (deployResult.newlyDeployed) {
    log(`Timelock deployed at ${deployResult.address}`)
  }
}
module.exports.tags = ['Timelock', 'stage1']
module.exports.dependencies = []
