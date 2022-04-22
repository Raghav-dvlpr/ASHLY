/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * truffleframework.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

const HDWalletProvider = require('@truffle/hdwallet-provider');

require('dotenv').config()
const infuraKey = "e8ba5639ca444d1f9384eadb679fdcef"//process.env.infuraKey;
const etherscan_key = process.env.etherscan_key;
const mnemonic = "find adjust slow shoe blind strike lunch weapon junk flower hub leader"//process.env.secret;
const privateKey = process.env.privateKey;

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },

    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },

    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    ropsten: {
      provider: () => new HDWalletProvider({
        mnemonic,
        providerOrUrl: `https://ropsten.infura.io/v3/` + infuraKey,
        chainId: 3,
      }),
      network_id: 3,       // Ropsten's id
      gas: 5500000,        // Ropsten has a lower block limit than mainnet
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },
    
    rinkeby: {
      provider: () => new HDWalletProvider({
        mnemonic,
        providerOrUrl: `https://rinkeby.infura.io/v3/` + infuraKey,
        chainId: 4,
      }),
      network_id: 4,       // Ropsten's id
      gas: 5500000,        // Ropsten has a lower block limit than mainnet
      confirmations: 1,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

    live: {
      provider: function () {
        return new HDWalletProvider({
          privateKeys: [privateKey],
          providerOrUrl: `https://mainnet.infura.io/v3/` + infuraKey,
          chainId: 1,
        })
      },
      gas: 4000000,
      confirmations: 1,
      gasPrice: 50e9,
      network_id: 1,
      skipDryRun: true
    },

    polygonMainnet: {
      provider: function () {
        return new HDWalletProvider({
          privateKeys: [privateKey],
          providerOrUrl: `https://polygon-mainnet.infura.io/v3/` + infuraKey,
          chainId: 137,
        })
      },
      network_id: 137,
      confirmations: 2,
      gas: 4000000,
      gasPrice: 121e9,
      timeoutBlocks: 750,
      skipDryRun: true,
      chainId: 137,
    },

    polygonMumbai: {
      provider: function () {
        return new HDWalletProvider({
          mnemonic: {
            phrase: mnemonic
          },
          providerOrUrl: `https://matic-mumbai.chainstacklabs.com`,
          chainId: 80001,
        })
      },
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      chainId: 80001
    },

    velas_testnet: {
      provider: () => new HDWalletProvider({
        mnemonic,
        providerOrUrl: `https://evmexplorer.testnet.velas.com/rpc`,
        chainId: 111,
      }),
      network_id: 111,       // Ropsten's id
      gas: 5500000,        // Ropsten has a lower block limit than mainnet
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

    velas_mainnet: {
      provider: () => new HDWalletProvider({
        privateKeys: [privateKey],
        providerOrUrl: `https://evmexplorer.velas.com/rpc`,
        chainId: 106,
      }),
      network_id: 106,       // Ropsten's id
      gas: 5500000,
      gasPrice: 5e9,     // Ropsten has a lower block limit than mainnet
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

    bsc_testnet: {
      provider: function () {
        return new HDWalletProvider({
          mnemonic: {
            phrase: mnemonic
          },
          // providerOrUrl: `https://data-seed-prebsc-1-s1.binance.org:8545`,
          providerOrUrl: `https://data-seed-prebsc-2-s1.binance.org:8545/`,
          chainId: 97,
        })
      },
      network_id: 97,
      // confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
      chainId: 97,
    },

    bsc: {
      provider: function () {
        return new HDWalletProvider({
          mnemonic: {
            phrase: mnemonic
          },
          providerOrUrl: `https://bsc-dataseed1.binance.org`,
          chainId: 56,
        })
      },
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
      chainId: 56,
    },

    // Useful for private networks
    // private: {
    // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
    // network_id: 2111,   // This network is yours, in the cloud.
    // production: true    // Treats this network as if it was a public net. (default: false)
    // }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.1",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "byzantium"
      }
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: "13F5F467PPFUFQJR6NIX11PNMIKBEIDR2K",
    bscscan: "8S6D63BGEW74PFIU8Z2F31XRR51YGDUV4E"

  }


}
