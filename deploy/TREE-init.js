module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log } = deployments
  const { deployer } = await getNamedAccounts()

  const treeDeployment = await get('TREE')
  const rebaserDeployment = await get('TREERebaser')
  const reserveDeployment = await get('TREEReserve')
  const treeContract = await ethers.getContractAt('TREE', treeDeployment.address)
  const treeRebaserAddress = await treeContract.rebaser()
  if (treeRebaserAddress === '0x0000000000000000000000000000000000000000') {
    await treeContract.initContracts(rebaserDeployment.address, reserveDeployment.address, { from: deployer })
    log('Initialized TREE')
  }
}
module.exports.tags = ['TREE-init', 'stage1']
module.exports.dependencies = ['TREE', 'TREERebaser', 'TREEReserve']
module.exports.runAtTheEnd = true
