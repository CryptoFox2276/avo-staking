const { ethers } = require('hardhat');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
describe('Token contract', () => {
    let accounts = [];
    let htzToken, tgrToken, agent, task, originalOwner;

    it('Should get account from hardhat node', async () => {
        const [owner, Bob, Sandy, Tom, Willy, Helen, Nike, Alice, Dante] =
            await ethers.getSigners();
        accounts.push(Bob, Sandy, Tom, Willy, Helen, Nike, Alice, Dante);
        originalOwner = owner;
    });

    it('Should deploy Hertz Token and mint', async () => {
        const HtzTokenFactory = await ethers.getContractFactory('Hertz');

        const HtzToken = await HtzTokenFactory.deploy(
            ethers.utils.parseEther('8000000')
        );
        console.log('Hertz Token deployed to: ', HtzToken.addresRs);
        htzToken = HtzToken;
    });

    it('Should send 300000000 htz to hardhat accounts', async () => {
        for (let i = 0; i < accounts.length; i++) {
            await htzToken.transfer(
                accounts[i].address,
                ethers.utils.parseEther('30000')
            );
        }
    });

    it('Should deploy TGR Token and mint', async () => {
        const TgrTokenFactory = await ethers.getContractFactory('Tgr');
        const TgrToken = await TgrTokenFactory.deploy(
            ethers.utils.parseUnits('10000000', 18)
        );
        tgrToken = TgrToken;
    });

    it('Should transfer TGR token to hardhat accounts', async () => {
        for (let i = 0; i < accounts.length; i++) {
            await tgrToken.transfer(
                accounts[i].address,
                ethers.utils.parseUnits('6700')
            );
        }
        console.log(await tgrToken.balanceOf(accounts[0].address));
    });

    it('Should deploy Agent Contract', async () => {
        const AgentsFactory = await ethers.getContractFactory('Agent');
        const agentsContract = await AgentsFactory.deploy();
        agent = agentsContract;
    });

    it('Should set levels in accordance with TGR Token of the agents', async () => {
        await agent.setLevels(0, 0);
        await agent.setLevels(1, ethers.utils.parseUnits('10'));
        await agent.setLevels(2, ethers.utils.parseUnits('100'));
        await agent.setLevels(3, ethers.utils.parseUnits('500'));
        await agent.setLevels(4, ethers.utils.parseUnits('5000'));
        await agent.setLevels(5, ethers.utils.parseUnits('10000'));
    });

    it('Set address of Tgr token for Agent Contract', async () => {
        await agent.setToken(tgrToken.address);
    });

    it('Deploy Task Contract', async () => {
        const TaskFactory = await ethers.getContractFactory('Task');
        const taskContract = await TaskFactory.deploy();
        task = taskContract;
    });

    it('Set addresses of Tgr and Htz token for Task Contract and set Agent Contract', async () => {
        await task.setTokens(tgrToken.address, htzToken.address);
        await task.setAgentContract(agent.address);
    });

    it('Should approve hardhat accounts to send htz token to Task Contract', async () => {
        for (let i = 0; i < accounts.length; i++) {
            await htzToken
                .connect(accounts[i])
                .approve(task.address, ethers.utils.parseUnits('1000000'));
        }
    });

    it('Define First Job on Task Contract', async () => {
        await task
            .connect(accounts[0])
            .defineJob(
                'Task 0 Title',
                'Task 0 Description',
                true,
                ethers.utils.parseUnits('4000')
            );
    });

    it('Add validators and deniers for job approval', async () => {
        await task.connect(accounts[1]).addValidatorsForApproval(0);
        await task.connect(accounts[2]).addDeniersForApproval(0);
        await task.connect(accounts[3]).addDeniersForApproval(0);
        await task.connect(accounts[4]).addValidatorsForApproval(0);
        await task.connect(accounts[5]).addDeniersForApproval(0);
        await task.connect(accounts[6]).addValidatorsForApproval(0);
    });

    it('Should approve hardhat accounts to send tgr token to Task Contract', async () => {
        for (let i = 0; i < accounts.length; i++) {
            await tgrToken
                .connect(accounts[i])
                .approve(task.address, ethers.utils.parseEther('100000'));
        }
    });

    it('Case: Job Approval is validated', async () => {
        await time.increase(15);
        await task.treatApprovalByOwnerAndSlash(0);
    });

    it('Assign Seller to Job', async () => {
        await task
            .connect(accounts[0])
            .assignSellerToJob(0, accounts[7].address);
    });

    // Remove Job by Buyer when job is under selection
    // it('Remove Job By Buyer', async () => {
    //     await task.removeJobByBuyer(0);
    // });

    it('Claim job done by seller', async () => {
        await task.connect(accounts[7]).claimEscrow(0);
    });

    it('Add validators and deniers for job completion', async () => {
        await task.connect(accounts[1]).addValidatorsForEscrow(0);
        await task.connect(accounts[2]).addDeniersForEscrow(0);
        await task.connect(accounts[3]).addDeniersForEscrow(0);
        await task.connect(accounts[4]).addValidatorsForEscrow(0);
        await task.connect(accounts[5]).addDeniersForEscrow(0);
        await task.connect(accounts[6]).addValidatorsForEscrow(0);
    });

    it('Case: Job Completion is validated', async () => {
        await time.increase(10);
        await task.treatEscrowOnCompletionAndSlash(0);
    });
});
