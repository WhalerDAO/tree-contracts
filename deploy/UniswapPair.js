module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/mainnet.json')

  const treeDeployment = await get('TREE')

  const uniswapFactoryContract = await ethers.getContractAt('IUniswapV2Factory', config.uniswapFactory)
  const existingPairAddress = await uniswapFactoryContract.getPair(treeDeployment.address, config.reserveToken)
  if (existingPairAddress === '0x0000000000000000000000000000000000000000') {
    const uniswapPairAddress = await uniswapFactoryContract.callStatic.createPair(treeDeployment.address, config.reserveToken, { from: deployer })
    await uniswapFactoryContract.createPair(treeDeployment.address, config.reserveToken, { from: deployer })
    log(`UniswapPair deployed at ${uniswapPairAddress}`)
  }
}
module.exports.tags = ['UniswapPair', 'stage1']
module.exports.dependencies = ['TREE']
