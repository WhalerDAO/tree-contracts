const BigNumber = require('bignumber.js')

module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { deploy, get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/mainnet.json')

  const treeDeployment = await get('TREE')
  const uniswapFactoryContract = await ethers.getContractAt('IUniswapV2Factory', config.uniswapFactory)
  const treePairAddress = await uniswapFactoryContract.getPair(treeDeployment.address, config.reserveToken)

  const deployResult = await deploy('LPRewards', {
    from: deployer,
    contract: 'TREERewards',
    args: [
      Math.floor(Date.now() / 1e3) + config.rewardWaitTime,
      treePairAddress, // stake TREE-yCRV UNI-V2 LP token
      treeDeployment.address // reward TREE
    ]
  })

  // mint TREE and notify reward
  if (deployResult.newlyDeployed) {
    log(`LPRewards deployed at ${deployResult.address}`)
    const lpRewardsContract = await ethers.getContractAt('TREERewards', deployResult.address)
    const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
    await lpRewardsContract.setRewardDistribution(deployer, { from: deployer })
    await treeContract.ownerMint(lpRewardsContract.address, BigNumber(config.lpRewardInitial).toFixed(), { from: deployer })
    await lpRewardsContract.notifyRewardAmount(BigNumber(config.lpRewardInitial).toFixed(), { from: deployer })
  }
}
module.exports.tags = ['LPRewards', 'stage1']
module.exports.dependencies = ['TREE']
module.exports.skip = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { getOrNull } = deployments
  const lpRewardsDeployment = await getOrNull('LPRewards')
  return !!lpRewardsDeployment
}
