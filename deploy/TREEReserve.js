const BigNumber = require('bignumber.js')

module.exports = async ({ getNamedAccounts, deployments, getChainId, ethers }) => {
  const { deploy, get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/get-config')

  const treeDeployment = await get('TREE')
  const lpRewardsDeployment = await get('LPRewards')
  const timelockDeployment = await get('Timelock')
  const uniswapFactoryContract = await ethers.getContractAt('IUniswapV2Factory', config.uniswapFactory)
  const treePairAddress = await uniswapFactoryContract.getPair(treeDeployment.address, config.reserveToken)

  const deployResult = await deploy('TREEReserve', {
    from: deployer,
    args: [
      BigNumber(config.charityCut).toFixed(),
      BigNumber(config.rewardsCut).toFixed(),
      BigNumber(config.maxSlippageFactor).toFixed(),
      treeDeployment.address,
      timelockDeployment.address,
      config.charity,
      config.reserveToken,
      lpRewardsDeployment.address,
      treePairAddress,
      config.uniswapRouter
    ]
  })
  if (deployResult.newlyDeployed) {
    log(`TREEReserve deployed at ${deployResult.address}`)
  }
}
module.exports.tags = ['TREEReserve', 'stage1']
module.exports.dependencies = ['TREE', 'LPRewards', 'Timelock']
