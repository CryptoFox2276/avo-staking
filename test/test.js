const { ethers } = require('hardhat');
const { assert, expect } = require("chai");
const { time } = require('@nomicfoundation/hardhat-network-helpers');

const deploy = async (contractName, ...args) => {
  const factory = await ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...args);
  await contract.deployed();
  console.log("Deployed", contractName, contract.address);
  await verify(contract, args);
  return contract;
};

const verify = async (contract, args, retry = 3) => {
  if (["hardhat", "localhost"].includes(network.name)) return;
  console.log("********************************************************");
  for (let i = 0; i < retry; i++) {
    try {
      await hre.run("verify:verify", {
        address: contract.address,
        constructorArguments: args,
      });
      break;
    } catch (ex) {
      console.log("\t* Failed verify", args.join(","), ex.message);
      await sleep(5);
    }
  }
  console.log("********************************************************");
};

describe('Staking contract', () => {


});
