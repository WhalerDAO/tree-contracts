module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/get-config')

  const treeDeployment = await get('TREE')

  const uniswapFactoryContract = await ethers.getContractAt('IUniswapV2Factory', config.uniswapFactory)
  const existingPairAddress = await uniswapFactoryContract.getPair(treeDeployment.address, config.reserveToken)
  if (existingPairAddress === '0x0000000000000000000000000000000000000000') {
    let token0, token1
    if (parseInt(treeDeployment.address) < parseInt(config.reserveToken)) {
      token0 = treeDeployment.address
      token1 = config.reserveToken
    } else {
      token1 = treeDeployment.address
      token0 = config.reserveToken
    }
    const uniswapPairAddress = ethers.utils.getCreate2Address(
      config.uniswapFactory,
      ethers.utils.keccak256(token0 + token1.slice(2)),
      '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'
    )
    await uniswapFactoryContract.createPair(treeDeployment.address, config.reserveToken, { from: deployer })
    log(`UniswapPair deployed at ${uniswapPairAddress}`)
  }
}
module.exports.tags = ['UniswapPair', 'stage1']
module.exports.dependencies = ['TREE']
