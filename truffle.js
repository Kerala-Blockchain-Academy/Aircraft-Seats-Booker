const HDWalletProvider = require("truffle-hdwallet-provider");
const infuraKey = "83fea33b58c84f9e9956d916386d9c0c";
const testConfig = require("./config/test");
const mnemonic = "chunk talk matter recycle evidence tobacco warm monkey banana palace achieve print";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gas: 6500029,
    },
    ropsten: {
      provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/${infuraKey}`),
      network_id: 3,       // Ropsten's id
      gas: 6500029,        // Ropsten has a lower block limit than mainnet
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },
    test: {
      provider: () => new HDWalletProvider(testConfig.mnemonic, testConfig.url),
      network_id: 3,
      gas: 6000029,
    }
  },
  mocha: {
    reporter: "eth-gas-reporter",
    reporterOptions : {
      currency: "INR",
      gasPrice: 350
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};
