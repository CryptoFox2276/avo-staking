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
        },
        hardhat: {
          allowUnlimitedContractSize: true,
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
        customChains: [
            {
                network: "arbitrumSepolia",
                chainId: 421614,
                urls: {
                    apiURL: "https://api-sepolia.arbiscan.io/api",
                    browserURL: "https://sepolia.arbiscan.io"
                }
            },
            {
                network: 'arbitrumOne',
                chainId: 42161,
                urls: {
                    apiURL: "https://api.arbiscan.com/api",
                    browserURL: "https://sepolia.arbiscan.io/"
                }
            },
        ]
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: true,
        strict: false,
        only: [':ERC20$'],
    },
};
