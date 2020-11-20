usePlugin('@nomiclabs/buidler-waffle')
usePlugin('@nomiclabs/buidler-ethers')
usePlugin('buidler-deploy')
usePlugin('solidity-coverage')

extendEnvironment(bre => {
  bre.config.mocha.timeout = 600000
})

module.exports = {
  solc: {
    version: '0.6.6'
  },
  namedAccounts: {
    deployer: {
      default: 0
    }
  },
  networks: {
    ganache: {
      url: 'http://localhost:8545',
      gasLimit: 1e7,
      gasPrice: 54e9
    },
    coverage: {
      url: 'http://localhost:8555',
      gasLimit: 1e7,
      gasPrice: 1e11
    }
  }
}
