module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log } = deployments
  const { deployer } = await getNamedAccounts()
  const config = require('../v1/deploy-configs/get-config')

  const timelockDeployment = await get('Timelock')
  const timelockContract = await ethers.getContractAt('Timelock', timelockDeployment.address)
  const initialized = await timelockContract.admin_initialized()
  if (!initialized) {
    await timelockContract.setPendingAdmin(config.gov, { from: deployer })
    log(`Initialized Timelock with admin ${config.gov}`)
  }
}
module.exports.tags = ['Timelock-init', 'stage2']
module.exports.dependencies = []
module.exports.runAtTheEnd = true
