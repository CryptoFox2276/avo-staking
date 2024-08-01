const { ethers } = require('hardhat');
const { assert, expect } = require("chai");
const { time } = require('@nomicfoundation/hardhat-network-helpers');

// const nowTimestamp = Math.floor((new Date().getTime()) / 1000);


const hertzAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
const tgrAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const taskAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
const agentAddress= "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9";
var timeStamp = 0;


const JOB_STATUS = {
    CREATED:0,
    VERIFYING:1,
    VERIFIED_POST:2,
    VALIDATIED_POST:3, 
    DENIED_POST:4,
    POSTED:5,
    INPROGRESSING:6,
    COMPLETED:7,
    VERIFYING_COMPLETED:8,
    VERIFIED_COMPLETED:9,
    VALIDATED_COMPLETED:10,
    DENIED_COMPLETED:11,
    DISPUTE_COMPLETED:12,
    VALIDATED_DISPUTE:13,
    DONE:14,
    WITHDRAWED:15
}

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

describe('Task contract', () => {
    let accounts = [];
    const initialMint = ethers.utils.parseEther("1000000").toString();
    let htzToken, tgrToken, agent, task, originalOwner;

    beforeEach(async () => {
        // await deployments.fixture(); // deploy all contracts
        accounts = await ethers.getSigners();
        console.log(accounts.length)
        originalOwner = accounts[0];
        deployer = accounts[0];
        htzToken = await ethers.getContractAt("Hertz", hertzAddress, deployer);
        tgrToken = await ethers.getContractAt("TgrToken", tgrAddress, deployer);
        agent = await ethers.getContractAt("Agent", agentAddress, deployer);
        task = await ethers.getContractAt("Task", taskAddress, deployer);
    });

    checkLevel = async () => {
        console.log();
        console.log("******* Levels of accounts *********");
        console.log("accounts[0]:", await agent.getLevelOfAgent(accounts[0].address));
        console.log("accounts[1]:", await agent.getLevelOfAgent(accounts[1].address));
        console.log("accounts[2]:", await agent.getLevelOfAgent(accounts[2].address));
        console.log("accounts[3]:", await agent.getLevelOfAgent(accounts[3].address));
        console.log("accounts[4]:", await agent.getLevelOfAgent(accounts[4].address));
        console.log("accounts[5]:", await agent.getLevelOfAgent(accounts[5].address));
        console.log("accounts[6]:", await agent.getLevelOfAgent(accounts[6].address));
        console.log("******** tgrToken Balance ************");
        console.log("tgrbalance of agent: ", ethers.utils.formatUnits(await tgrToken.balanceOf(agent.address), 18));
        console.log("tgrbalance0: ", ethers.utils.formatUnits(await agent.getStakedAmountOfAgent(accounts[0].address), 18));
        console.log("tgrbalance1: ", ethers.utils.formatUnits(await agent.getStakedAmountOfAgent(accounts[1].address), 18));
        console.log("tgrbalance2: ", ethers.utils.formatUnits(await agent.getStakedAmountOfAgent(accounts[2].address), 18));
        console.log("tgrbalance3: ", ethers.utils.formatUnits(await agent.getStakedAmountOfAgent(accounts[3].address), 18));
        console.log("tgrbalance4: ", ethers.utils.formatUnits(await agent.getStakedAmountOfAgent(accounts[4].address), 18));
        console.log("tgrbalance5: ", ethers.utils.formatUnits(await agent.getStakedAmountOfAgent(accounts[5].address), 18));
        console.log("tgrbalance6: ", ethers.utils.formatUnits(await agent.getStakedAmountOfAgent(accounts[6].address), 18));
        console.log("******** htzToken Balance ************");
        console.log("TaskContract: ", ethers.utils.formatUnits(await htzToken.balanceOf(task.address), 18));
        console.log("htzbalance0: ", ethers.utils.formatUnits(await htzToken.balanceOf(accounts[0].address), 18));
        console.log("htzbalance1: ", ethers.utils.formatUnits(await htzToken.balanceOf(accounts[1].address), 18));
        console.log("htzbalance2: ", ethers.utils.formatUnits(await htzToken.balanceOf(accounts[2].address), 18));
        console.log("htzbalance3: ", ethers.utils.formatUnits(await htzToken.balanceOf(accounts[3].address), 18));
        console.log("htzbalance4: ", ethers.utils.formatUnits(await htzToken.balanceOf(accounts[4].address), 18));
        console.log("htzbalance5: ", ethers.utils.formatUnits(await htzToken.balanceOf(accounts[5].address), 18));
        console.log("htzbalance6: ", ethers.utils.formatUnits(await htzToken.balanceOf(accounts[6].address), 18));
        console.log("************************************");
    }

    checkJobStatus = async () => {
        console.log();
        console.log("******* Status of Jobs *********");
        const tx = await task.getJobList();
        for(let i = 0 ; i < tx.length ; i ++ ) {
            let status = await task.getStatusOfJob(i);
            console.log(`Job ${i} status is ${status}`);
        }
        console.log("************************************");
    }


    it("Deploy", async () => {
        // return;
        const latestBlock = await ethers.provider.getBlock("latest");
        timeStamp = (latestBlock).timestamp;
        if(hertzAddress !== '') {
            htzToken = await ethers.getContractAt('Hertz', hertzAddress);
          } else {
            htzToken = await deploy("Hertz", initialMint);  
          }

          if(tgrAddress !== '') {
            tgrToken = await ethers.getContractAt('TgrToken', tgrAddress);
          } else {
            tgrToken = await deploy("TgrToken", initialMint);  
          }
          
        //   task = await deploy("Task");

        //   const multiCall = await deploy("Multicall3");

          if(agentAddress !== '') {
            agent = await ethers.getContractAt('Agent', agentAddress);
          } else {
            agent = await deploy("Agent", task.address, 1000);
          }

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

          tx = await task.setTokens(tgrToken.address, htzToken.address);
          await tx.wait();

          tx = await task.setAgentContract(agent.address);
          await tx.wait();

          tx = await task.setJobTypes(JOBTYPES);
          await tx.wait();
    })

    // it("Check", async ()=> {
    //     await checkJobStatus();
    // })
    
    // return;
    it('Should approve hardhat accounts to send htz token to Task Contract', async () => {
        for (let i = 0; i < accounts.length; i++) {
            await htzToken
                .connect(accounts[i])
                .approve(task.address, ethers.utils.parseUnits('1000000'));
        }
    });

    it("Should approve hardhat accounts to stake trgtokens to Agent Contract", async () => {
        for (let i = 0; i < accounts.length; i++) {
            await tgrToken
                .connect(accounts[i])
                .approve(agent.address, ethers.utils.parseUnits('1000000'));
        }
    })

    it("Transfer some trgtokens to the accounts", async () => {
        // return;
        await tgrToken.transfer(accounts[1].address, ethers.utils.parseUnits('5000'))
        await tgrToken.transfer(accounts[2].address, ethers.utils.parseUnits('500'))
        await tgrToken.transfer(accounts[3].address, ethers.utils.parseUnits('600'))
        await tgrToken.transfer(accounts[4].address, ethers.utils.parseUnits('1000'))
        await tgrToken.transfer(accounts[5].address, ethers.utils.parseUnits('1000'))
        await tgrToken.transfer(accounts[6].address, ethers.utils.parseUnits('1000'))
        await tgrToken.transfer(accounts[7].address, ethers.utils.parseUnits('1000'))
    })

    it('Should save Name and image uri', async () => {
        await agent.connect(accounts[0]).saveNameAndLogo('test', 'test image');
    })

    it('Should get name and image uri', async()=> {
        const result = await agent.connect(accounts[0]).poolStakers[accounts[0].address];
        console.log(result);
    })

    it("Should stake tgrtokens for posting job", async () => {
        // return;
        await agent.connect(accounts[0]).deposit(ethers.utils.parseUnits('50000'))
        await agent.connect(accounts[1]).deposit(ethers.utils.parseUnits('5000'))
        await agent.connect(accounts[2]).deposit(ethers.utils.parseUnits('500'))
        await agent.connect(accounts[3]).deposit(ethers.utils.parseUnits('600'))
        await agent.connect(accounts[4]).deposit(ethers.utils.parseUnits('1000'))
        await agent.connect(accounts[5]).deposit(ethers.utils.parseUnits('1000'))
        await agent.connect(accounts[6]).deposit(ethers.utils.parseUnits('1000'))
        await agent.connect(accounts[7]).deposit(ethers.utils.parseUnits('1000'))
    })

    // it("Send 1000 htzToken to accounts[1] and accounts[2]", async () => {
    //     // return;
    //     await htzToken.transfer(accounts[1].address, ethers.utils.parseUnits('1000'))
    //     await htzToken.transfer(accounts[2].address, ethers.utils.parseUnits('100'))
    // })

    // it("Check level", async () => {
    //     await checkLevel();
    // })

    // it('Accounts[0]: Define Job of level 2 on Task Contract', async () => {
    //     // return;
    //     await task
    //         .connect(accounts[0])
    //         .defineJob(
    //             1,
    //             2,
    //             'Task 0 Title',
    //             'Task 0 Description',
    //             true,
    //             ethers.utils.parseUnits('10'),
    //             timeStamp + 10
    //         );
    // });

    // it('Accounts[1]: Define Job of level 0 on Task Contract', async () => {
    //     // return;
    //     await task
    //         .connect(accounts[1])
    //         .defineJob(
    //             1,
    //             1,
    //             'Task 1 Title',
    //             'Task 1 Description',
    //             true,
    //             ethers.utils.parseUnits('20'),
    //             timeStamp + 10
    //         );
    // });

    // it('Accounts[1]: Define nontgr Job of level 3 on Task Contract', async () => {
    //     // return;
    //     await task
    //         .connect(accounts[1])
    //         .defineJob(
    //             1,
    //             0,
    //             'Task 2 Title',
    //             'Task 2 Description',
    //             false,
    //             ethers.utils.parseUnits('30'),
    //             timeStamp + 10
    //         );
    // });

    // it('Accounts[1]: Define nontgr Job of level 3 on Task Contract', async () => {
    //     // return;
    //     await task
    //         .connect(accounts[2])
    //         .defineJob(
    //             1,
    //             3,
    //             'Task 3 Title',
    //             'Task 3 Description',
    //             false,
    //             ethers.utils.parseUnits('30'),
    //             timeStamp + 10
    //         );
    // });

    // it("Job length should be 4", async () => {
    //     const tx = await task.getJobList();
    //     expect(tx.length).to.equal(4)
    // });

    // return;

    // it('Should revert if user level is invalid', async () => {
    //     expect(task.connect(accounts[7]).verifyJob(1, true)).to.be.revertedWith('Invalid user level');
    // });

    // it('Should revert if user is owner', async () => {
    //     expect(task.connect(accounts[0]).verifyJob(0, true)).to.be.revertedWith('Invalid User');
    // });

    // it('Verification Case 1: 1st Job is approved', async () => {
    //     // return;
    //     await task.connect(accounts[1]).verifyJob(0, true);
    //     await task.connect(accounts[2]).verifyJob(0, false);
    //     await task.connect(accounts[3]).verifyJob(0, true);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.VERIFIED_POST);
    // });

    // it('Verification Case 2: 2nd Job is denied', async () => {
    //     // return;
    //     await task.connect(accounts[0]).verifyJob(1, true);
    //     await task.connect(accounts[2]).verifyJob(1, true);
    //     await task.connect(accounts[3]).verifyJob(1, false);

    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFIED_POST);
    // });

    // it('Disputing the verification result of 1st Job', async () => {
    //     await task.connect(accounts[4]).disputeJob(0);
    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.VERIFYING);
    // })

    // it('Reverifying 1st Job', async () => {
    //     await task.connect(accounts[5]).verifyJob(0, true);
    //     await task.connect(accounts[6]).verifyJob(0, true);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.VERIFIED_POST);
    // })

    // it('Disputing the verification result of 2nd Job', async () => {
    //     await task.connect(accounts[4]).disputeJob(1);
    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFYING);  
    // })

    // it('Reverifying 2nd Job', async () => {
    //     await task.connect(accounts[5]).verifyJob(1, true);
    //     await task.connect(accounts[6]).verifyJob(1, true);

    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFIED_POST);
    // })

    // return;

    // it('Should pass validation stage after over the validation period', async () => {
    //     await time.increase(310);
    //     await task.validateJob(0);
    //     await task.validateJob(1);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.POSTED);
    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.POSTED);
    // })

    // it('Assign Seller to Job and Job is in Progress', async () => {
    //     await task.connect(accounts[0]).assignSellerToJob(0, accounts[3].address);
    //     await task.connect(accounts[1]).assignSellerToJob(1, accounts[4].address);
    //     await task.connect(accounts[1]).assignSellerToJob(2, accounts[5].address);
    //     await task.connect(accounts[2]).assignSellerToJob(3, accounts[6].address);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.INPROGRESSING);
    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.INPROGRESSING)
    //     expect(await task.getStatusOfJob(2)).to.be.equal(JOB_STATUS.INPROGRESSING)
    //     expect(await task.getStatusOfJob(3)).to.be.equal(JOB_STATUS.INPROGRESSING)
    // });

    // it("Job status set as Completed", async () => {
    //     await task.connect(accounts[3]).submitJob(0, "Done")
    //     await task.connect(accounts[4]).submitJob(1, "Done")
    //     await task.connect(accounts[5]).submitJob(2, "Done")
    //     await task.connect(accounts[6]).submitJob(3, "Done")

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.VERIFYING_COMPLETED);
    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFYING_COMPLETED)
    //     expect(await task.getStatusOfJob(2)).to.be.equal(JOB_STATUS.COMPLETED)
    //     expect(await task.getStatusOfJob(3)).to.be.equal(JOB_STATUS.COMPLETED)
    // })

    // it("nontgr Job Should be DISPUTE_COMPLETED status by poster disputing", async () => {
    //     await task.connect(accounts[1]).disputeSubmission(2);

    //     expect(await task.getStatusOfJob(2)).to.be.equal(JOB_STATUS.DISPUTE_COMPLETED);
    // })

    // it("Should verify disputed nontgr Job", async () => {
    //     await task.connect(accounts[2]).verifyJob(2, true)
    //     await task.connect(accounts[3]).verifyJob(2, true)
    //     await task.connect(accounts[4]).verifyJob(2, false)
    // })

    // it("Verification for Completed 1st Job: 1st Job's completeness is approved", async () => {
    //     await task.connect(accounts[1]).verifyJob(0, true);
    //     await task.connect(accounts[2]).verifyJob(0, false);
    //     await task.connect(accounts[4]).verifyJob(0, true);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.VERIFIED_COMPLETED);
    // })
    
    // it("Verification for Completed 2nd Job: 2nd Job's completeness is denied", async () => {
    //     await task.connect(accounts[0]).verifyJob(1, true);
    //     await task.connect(accounts[2]).verifyJob(1, true);
    //     await task.connect(accounts[3]).verifyJob(1, false);

    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFIED_COMPLETED);
    // })

    // it('Disputing the verification result of 1st Job', async () => {
    //     await task.connect(accounts[5]).disputeJob(0);
    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.VERIFYING_COMPLETED);
    // })

    // it('Reverifying 1st Job', async () => {
    //     await task.connect(accounts[6]).verifyJob(0, true);
    //     await task.connect(accounts[7]).verifyJob(0, true);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.VERIFIED_COMPLETED);
    // })

    // it('Disputing the verification result of 2nd Job', async () => {
    //   await task.connect(accounts[5]).disputeJob(1);
    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFYING_COMPLETED);  
    // })

    // it('Reverifying 2nd Job', async () => {
    //     await task.connect(accounts[6]).verifyJob(1, false);
    //     await task.connect(accounts[7]).verifyJob(1, true);

    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFIED_COMPLETED);
    // })

    // it('Validation for Completed 1st Job: 1st Job verification is validated', async () => {
    //     await task.connect(accounts[4]).validateJob(0, true);
    //     await task.connect(accounts[5]).validateJob(0, false);
    //     await task.connect(accounts[6]).validateJob(0, true);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.DONE);
    // })
    
    // it('Validation for Completed 2nd Job: 2nd Job verification is disputed', async () => {
    //     await task.connect(accounts[4]).validateJob(1, false);
    //     await task.connect(accounts[5]).validateJob(1, true);
    //     await task.connect(accounts[6]).validateJob(1, false);

    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFYING_COMPLETED);
    // })

    // it("Reverifying for completed 2nd job", async () => {
    //     await task.connect(accounts[4]).verifyJob(1, true);
    //     await task.connect(accounts[5]).verifyJob(1, true);
    //     await task.connect(accounts[6]).verifyJob(1, true);

    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.VERIFIED_COMPLETED);
    // })

    // it("Revalidating completed 2nd Job", async () => {
    //     await task.connect(accounts[0]).validateJob(1, true);
    //     await time.increase(310);
    //     await task.validateJob(1);

    //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.DONE);
    // })

    // it('Should pass validation stage after over the validation period', async () => {
    //     await time.increase(310);
    //     await task.validateJob(0);
    //     await task.validateJob(1);
    //     await task.validateJob(2);

    //     await time.increase(400);
    //     await task.validateJob(3);

    //   expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.DONE);
    //   expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.WITHDRAWED);
    //   expect(await task.getStatusOfJob(2)).to.be.equal(JOB_STATUS.WITHDRAWED);
    //   expect(await task.getStatusOfJob(3)).to.be.equal(JOB_STATUS.WITHDRAWED);
    // })

    // // it("3 Jobs should be completed", async () => {
    // //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.DONE);
    // //     expect(await task.getStatusOfJob(1)).to.be.equal(JOB_STATUS.DONE);
    // //     expect(await task.getStatusOfJob(2)).to.be.equal(JOB_STATUS.COMPLETED);
    // // })

    // it('Freelancer should claim escrow', async () => {
    //     await task.connect(accounts[3]).claimEscrow(0);

    //     expect(await task.getStatusOfJob(0)).to.be.equal(JOB_STATUS.WITHDRAWED);
    // });

    // it('Checking status', async () => {
    //     await checkJobStatus();
    //     await checkLevel();
    // })

    // return;
    // it("Can't withdraw staked tgr token when time is locked", async () => {
    //     await expect(agent.withdraw(ethers.utils.parseUnits('10000'))).to.be.revertedWith("Agent: Time locked");
    // })

    // it("Can't withdraw staked tgr token when amount is insufficient", async () => {
    //     await time.increase(1000);
    //     await expect(agent.withdraw(ethers.utils.parseUnits('100000'))).to.be.revertedWith("Agent: Insufficient amount");
    //     await expect(agent.withdraw(ethers.utils.parseUnits('50000'))).to.be.revertedWith("Agent: Insufficient amount");
    // })

    // it("Should withdraw 10000 staked tgr token", async () => {
    //     await agent.withdraw(ethers.utils.parseUnits('10000'))
    //     // await checkLevel();
    // })

});
