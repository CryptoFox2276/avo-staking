// require('@nomicfoundation/hardhat-toolbox');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');

require('dotenv').config(); // .env
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: '0.8.20',
        settings: {
            optimizer: {
              enabled: true,
              runs: 1
            }
         },
         allowUnlimitedContractSize: true,
    },
    defaultNetwork: 'ftmTestnet',
    namedAccounts: {
        deployer: {
          default: 0,
        },
    },
    networks: {
        localhost: {
          timeout: 120000,
          forking: {
            url: "https://rpc.ftm.tools/"
          }
        },
        hardhat: {
          allowUnlimitedContractSize: true,
          forking: {
            url: "https://rpc.ftm.tools/"
          }
        },
        ftmTestnet: {
          url: "https://rpc.testnet.fantom.network",
          accounts: [process.env.PV_KEY],
          gas: 5000000,
          gasPrice:  50000000000,
          allowUnlimitedContractSize: true
        },
        fantom: {
          url: "https://rpc.ftm.tools/",
          accounts: [process.env.PV_KEY],
        },
        goerli: {
            url: `https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161`,
            accounts: [`${process.env.PV_KEY}`],
        },
        avalanche: {
          url: `https://api.avax.network/ext/bc/C/rpc`,
          chainId: 43114,
          gasPrice: 225000000000,
          accounts: [process.env.PV_KEY]
        }
    },
    etherscan: {
        apiKey: `${process.env.API_KEY}`,
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: true,
        strict: false,
        only: [':ERC20$'],
    },
};
