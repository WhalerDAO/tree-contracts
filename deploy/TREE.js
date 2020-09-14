const BigNumber = require('bignumber.js')

module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../deploy-configs/get-config')

  const deployResult = await deploy('TREE', {
    from: deployer
  })
  if (deployResult.newlyDeployed) {
    log(`TREE deployed at ${deployResult.address}`)

    if (config.isTesting) {
      // for testing convenience, we mint some TREE for the deployer
      const treeContract = await ethers.getContractAt('TREE', deployResult.address)
      await treeContract.ownerMint(deployer, BigNumber(1e20).toFixed(), { from: deployer })
      log(`TESTING: Minted 100 TREE for deployer ${deployer}`)
    }
  }
}
module.exports.tags = ['TREE', 'stage1']
module.exports.dependencies = []
