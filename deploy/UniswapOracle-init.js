module.exports = async ({ ethers, getNamedAccounts, deployments, getChainId }) => {
  const { get, log } = deployments
  const { deployer } = await getNamedAccounts()

  const oracleDeployment = await get('UniswapOracle')
  const oracleContract = await ethers.getContractAt('UniswapOracle', oracleDeployment.address)
  const initialized = await oracleContract.initialized()
  if (!initialized) {
    await oracleContract.init({ from: deployer })
    log('Initialized UniswapOracle')
  }
}
module.exports.tags = ['UniswapOracle-init', 'stage2']
module.exports.dependencies = []
module.exports.runAtTheEnd = true
