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
    defaultNetwork: 'hardhat',
    namedAccounts: {
        deployer: {
          default: 0,
        },
    },
    networks: {
        localhost: {
          timeout: 120000,
          forking: {
            url: "https://arb1.arbitrum.io/rpc"
          }
        },
        hardhat: {
          allowUnlimitedContractSize: true,
          forking: {
            url: "https://arb1.arbitrum.io/rpc"
          }
        },
        arbitrumSepolia: {
          url: "https://sepolia-rollup.arbitrum.io/rpc",
          accounts: [process.env.PV_KEY],
          allowUnlimitedContractSize: true
        },
        arbitrumOne: {
          url: "https://arb1.arbitrum.io/rpc",
          accounts: [process.env.PV_KEY],
        },
    },
    etherscan: {
      apiKey: {
        arbitrumSepolia: `${process.env.API_KEY}`,
        arbitrumOne: `${process.env.API_KEY}`
      },
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: true,
        strict: false,
        only: [':ERC20$'],
    },
};
