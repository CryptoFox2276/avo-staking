const { ethers, run, waffle } = require('hardhat');
const main = async () => {
    const initialMint = ethers.utils.parseEther('10000000000000');
    const [deployer] = await ethers.getSigners();
    console.log(
        'Deploying the contracts with the account:',
        await deployer.getAddress()
    );

    const provider = waffle.provider;

    let nonce = await provider.getTransactionCount(deployer.address);

    console.log('Account balance:', (await deployer.getBalance()).toString());

    const HertzToken = await ethers.getContractFactory('Hertz');
    const hertzToken = await HertzToken.deploy(initialMint, { nonce: nonce++ });
    await hertzToken.deployed();

    console.log('HerzToken address:', hertzToken.address);

    const TgrToken = await ethers.getContractFactory('TgrToken');
    const tgrToken = await TgrToken.deploy(initialMint, { nonce: nonce++ });
    await tgrToken.deployed();

    console.log('TgrToken address:', tgrToken.address);

    const Agent = await ethers.getContractFactory('Agent');
    const agent = await Agent.deploy({ nonce: nonce++ }, 0);
    await agent.deployed();

    let tx = await agent.setToken(tgrToken.address, { nonce: nonce++ });
    await tx.wait();

    tx = await agent.setLevels(0, 0, { nonce: nonce++ });
    await tx.wait();
    tx = await agent.setLevels(1, ethers.utils.parseUnits('10'), {
        nonce: nonce++,
    });
    await tx.wait();
    tx = await agent.setLevels(2, ethers.utils.parseUnits('100'), {
        nonce: nonce++,
    });
    await tx.wait();
    tx = await agent.setLevels(3, ethers.utils.parseUnits('500'), {
        nonce: nonce++,
    });
    await tx.wait();
    tx = await agent.setLevels(4, ethers.utils.parseUnits('5000'), {
        nonce: nonce++,
    });
    await tx.wait();
    tx = await agent.setLevels(5, ethers.utils.parseUnits('10000'), {
        nonce: nonce++,
    });
    await tx.wait();

    console.log('agent address:', agent.address);

    const Task = await ethers.getContractFactory('Task');
    const task = await Task.deploy({ nonce: nonce++ });
    await task.deployed();

    tx = await task.setTokens(tgrToken.address, hertzToken.address, {
        nonce: nonce++,
    });
    await tx.wait();

    tx = await task.setAgentContract(agent.address, { nonce: nonce++ });
    await tx.wait();

    console.log('task address:', task.address);

    await run(`verify:verify`, {
        address: hertzToken.address,
        contract: 'contracts/Hertz.sol:Hertz',
        constructorArguments: [initialMint],
    });

    await run(`verify:verify`, {
        address: hertzToken.address,
        contract: 'contracts/Tgr.sol:Tgr',
        constructorArguments: [initialMint],
    });

    await run(`verify:verify`, {
        address: agent.address,
    });

    await run(`verify:verify`, {
        address: task.address,
    });
};

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
