const { ethers, waffle } = require("hardhat");

const sleep = async (seconds) => {
  return new Promise((resolve) => setTimeout(resolve, seconds * 1000));
};

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

async function main() {
  const [deployer] = await ethers.getSigners();

  // const TheXdaoNFTContract = await deploy("TheXdaoNFT");
  const initialMint = ethers.utils.parseEther("10000000000").toString();

  const hertzToken = await deploy("Hertz", initialMint);
  const tgrToken = await deploy("TgrToken", initialMint);  

  // const TheXdaoMarketContract = await deploy("TheXdaoMarket");

  const TheXdaoAuctionContract = await deploy("TheXdaoAuction", hertzToken.address, deployer.address);  
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
