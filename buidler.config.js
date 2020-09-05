usePlugin('@nomiclabs/buidler-waffle')
usePlugin('@nomiclabs/buidler-ganache')
usePlugin('buidler-deploy')

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
      fork: 'https://mainnet.infura.io/v3/2f4ac5ce683c4da09f88b2b564d44199',
      unlockedAccounts: [],
      gasLimit: 1e7,
      gasPrice: 1e11
    }
  }
}
