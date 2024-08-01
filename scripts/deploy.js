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
  const hertzTokenAddress = "0x8E212C976498d1F903E946D32FE2151ccA589a5B";
  const tgrTokenAddress = "0xd6d54474E976C7efA7f160E61D544d7393cE2B89";
  const agentAddress = "";
  
  const lockedTime = 5 * 60;

  // Escrow = await deploy("Escrow");
  const initialMint = ethers.utils.parseEther("1000000").toString();
  const accounts = await ethers.getSigners();
  console.log('Accounts Length:', accounts.length);
  const deployer = accounts[0];
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress(),
  );

  const provider = waffle.provider;

  let nonce = await provider.getTransactionCount(deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  let hertzToken, tgrToken, agent;
  
  if(hertzTokenAddress !== '') {
    hertzToken = await ethers.getContractAt('Hertz', hertzTokenAddress);
    console.log(hertzToken.address)
  } else {
    hertzToken = await deploy("Hertz", initialMint);
  }

  if(tgrTokenAddress !== '') {
    tgrToken = await ethers.getContractAt('TgrToken', tgrTokenAddress);
    console.log(tgrToken.address)
  } else {
    tgrToken = await deploy("TgrToken", initialMint);  
  }
  
  const task = await deploy("Task");

  if(agentAddress !== '') {
    agent = await ethers.getContractAt('Agent', agentAddress);
    console.log(agent.address)
  } else {
    agent = await deploy("Agent", task.address, lockedTime);
  }

  const multiCall = await deploy("Multicall3");

  let tx = await agent.setToken(tgrToken.address);
  await tx.wait();

  tx = await agent.setLevels(0, 0);
  await tx.wait();  
  
  tx = await agent.setLevels(1, ethers.utils.parseUnits("10"));
  await tx.wait();
  
  tx = await agent.setLevels(2, ethers.utils.parseUnits("100"));
  await tx.wait();
  
  tx = await agent.setLevels(3, ethers.utils.parseUnits("500"));
  await tx.wait();
  
  tx = await agent.setLevels(4, ethers.utils.parseUnits("5000"));
  await tx.wait();
  
  tx = await agent.setLevels(5, ethers.utils.parseUnits("50000"));
  await tx.wait();

  tx = await task.setTokens(tgrToken.address, hertzToken.address);
  await tx.wait();

  tx = await task.setAgentContract(agent.address);
  await tx.wait();

  tx = await task.setJobTypes(JOBTYPES);
  await tx.wait();

  for (let i = 0; i < accounts.length; i++) {
      await hertzToken
          .connect(accounts[i])
          .approve(task.address, ethers.utils.parseUnits('1000000'));
  }

  for (let i = 0; i < accounts.length; i++) {
      await tgrToken
          .connect(accounts[i])
          .approve(agent.address, ethers.utils.parseUnits('1000000'));
  }

  // Transfer some trgtokens to the accounts;
  // await tgrToken.transfer(accounts[1].address, ethers.utils.parseUnits('5000'))
  // await tgrToken.transfer(accounts[2].address, ethers.utils.parseUnits('500'))
  // await tgrToken.transfer(accounts[3].address, ethers.utils.parseUnits('100'))
  // await tgrToken.transfer(accounts[4].address, ethers.utils.parseUnits('1000'))
  // await tgrToken.transfer(accounts[5].address, ethers.utils.parseUnits('1000'))
  // await tgrToken.transfer(accounts[6].address, ethers.utils.parseUnits('1000'))

  // // Should stake tgrtokens for posting job;
  await agent.connect(accounts[0]).deposit(ethers.utils.parseUnits('50000'))
  // await agent.connect(accounts[1]).deposit(ethers.utils.parseUnits('5000'))
  // await agent.connect(accounts[2]).deposit(ethers.utils.parseUnits('500'))
  // await agent.connect(accounts[3]).deposit(ethers.utils.parseUnits('100'))
  // await agent.connect(accounts[4]).deposit(ethers.utils.parseUnits('1000'))
  // await agent.connect(accounts[5]).deposit(ethers.utils.parseUnits('1000'))
  // await agent.connect(accounts[6]).deposit(ethers.utils.parseUnits('1000'))

}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
