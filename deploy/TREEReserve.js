const BigNumber = require('bignumber.js')

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy, get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/get-config')

  const treeDeployment = await get('TREE')
  const lpRewardsDeployment = await get('LPRewards')
  const oracleDeployment = await get('UniswapOracle')

  const deployResult = await deploy('TREEReserve', {
    from: deployer,
    args: [
      BigNumber(config.charityCut).toFixed(),
      BigNumber(config.rewardsCut).toFixed(),
      BigNumber(config.maxSlippageFactor).toFixed(),
      treeDeployment.address,
      config.gov,
      config.charity,
      config.reserveToken,
      lpRewardsDeployment.address,
      oracleDeployment.address,
      config.uniswapRouter
    ]
  })
  if (deployResult.newlyDeployed) {
    log(`TREEReserve deployed at ${deployResult.address}`)
  }
}
module.exports.tags = ['TREEReserve', 'stage1']
module.exports.dependencies = ['TREE', 'LPRewards', 'UniswapOracle']
