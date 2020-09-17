const BigNumber = require('bignumber.js')

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/get-config')

  const treeDeployment = await get('TREE')
  const oracleDeployment = await get('UniswapOracle')
  const reserveDeployment = await get('TREEReserve')

  const deployResult = await deploy('TREERebaser', {
    from: deployer,
    args: [BigNumber(config.minimumRebaseInterval).toFixed(), BigNumber(config.deviationThreshold).toFixed(),
      BigNumber(config.rebaseMultiplier).toFixed(), treeDeployment.address,
      oracleDeployment.address, reserveDeployment.address, config.gov]
  })
  if (deployResult.newlyDeployed) {
    log(`TREERebaser deployed at ${deployResult.address}`)
  }
}
module.exports.tags = ['TREERebaser', 'stage1']
module.exports.dependencies = ['TREE', 'UniswapOracle', 'TREEReserve']
