const { ethers, waffle } = require("hardhat");

const JOBTYPES = [
  'Art',
  'Audio Creation',
  'Backend Development',
  'Business Consulting and Project Management',
  'Fiction Writing',
  'Frontend Development',
  'Game Development',
  'Logo Design',
  'Misc Design',
  'Mobile Development',
  'Modeling',
  'Nonfiction Writing',
  'Proofreading',
  'Product Marketing',
  'Social Media Marketing',
  'Search Engine Optimization',
  'Translation',
  'Video and Animation',
  'Web Design',
  'Web Development'
]

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
        contract: 'contracts/TgrToken.sol:TgrToken',
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
  

}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
