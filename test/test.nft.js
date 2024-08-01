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

describe('Task contract', () => {

  const baseURI = "https://gateway.pinata.cloud/ipfs/Qmf6R4vyUFQ1qQGwQMg9wL5tHUXP83wf7ipxJXzf7t2ZJf/"

  let owner, admin, addrs;
  let currentNFTID;

  let NFTContract;
  let TheXdaoMarket;
  let TheXdaoAuction;
  let governanceToken;

  beforeEach(async () => {
    [owner, admin, ...addrs] = await ethers.getSigners();
  });

  governanceTokenBalanceOfAddress = async ()=>{
    console.log('++++++++++++++++++');
    console.log('governanceToken of owner: ', ethers.utils.formatUnits(await governanceToken.balanceOf(owner.address), 18));
    console.log('governanceToken of admin: ', ethers.utils.formatUnits(await governanceToken.balanceOf(admin.address), 18));
    console.log('governanceToken of addr[0]: ', ethers.utils.formatUnits(await governanceToken.balanceOf(addrs[0].address), 18));
    console.log('governanceToken of addr[1]: ', ethers.utils.formatUnits(await governanceToken.balanceOf(addrs[1].address), 18));
    console.log('governanceToken of addr[2]: ', ethers.utils.formatUnits(await governanceToken.balanceOf(addrs[2].address), 18));
    console.log('governanceToken of addr[3]: ', ethers.utils.formatUnits(await governanceToken.balanceOf(addrs[3].address), 18));
    console.log('++++++++++++++++++');
  }

  it("Deploying the contracts", async () => {
    // const TheXdaoNFTFactory = await ethers.getContractFactory('TheXdaoNFT');
    // TheXdaoNFT = await TheXdaoNFTFactory.deploy();
    // console.log('TheXdaoNFT is deployed to: ', TheXdaoNFT.address);

    const TheXdaoMarketFactory = await ethers.getContractFactory('TheXdaoMarket');
    TheXdaoMarket = await TheXdaoMarketFactory.deploy();
    console.log('TheXdaoMarket is deployed to: ', TheXdaoMarket.address);

    // const TheXdaoAuctionFactory = await ethers.getContractFactory('TheXdaoAuction');
    // TheXdaoAuction = await TheXdaoAuctionFactory.deploy();
    // console.log('TheXdaoAuction is deployed to: ', TheXdaoAuction.address);

    const GovernanceTokenFactory = await ethers.getContractFactory('GovernanceToken')
    governanceToken = await GovernanceTokenFactory.deploy();
    console.log('GovernanceToken is deployed to: ', governanceToken.address);
  })

  it("Transferring the 1000 gov tokens to addrs", async () => {
    await governanceToken.connect(owner).transfer(addrs[0].address, ethers.utils.parseUnits('1000', 18))
    await governanceToken.connect(owner).transfer(addrs[3].address, ethers.utils.parseUnits('1000', 18))
    // await governanceToken.connect(owner).transfer(addrs[2].address, ethers.utils.parseUnits('1000', 18))
  })

  it("Initialize the XdaoMarket", async () => {
    await TheXdaoMarket.initialize(governanceToken.address, admin.address)
  })

  it("Create a new collection by addrs[0]", async () => {
    await TheXdaoMarket.connect(addrs[0]).createCollection("Second TheXdao", "https://ipfs.io/ipfs/Qmb2xi5DHBbTj9QXKcvEdU8RphvLKL9ggUyH9kdAh7dbgG", true)
  })

  it("Collections length is 2", async () => {
    const collections = await TheXdaoMarket.connect(addrs[0]).getCollections();
    console.log(collections)

    expect(collections.length).to.equal(2)
  })

  it("Add first NFT item of first collection by addrs[1]", async () => {
    const collections = await TheXdaoMarket.connect(addrs[1]).getCollections();

    NFTContract = await ethers.getContractAt('TheXdaoNFT', collections[0])

    const txResponse = await NFTContract.connect(addrs[1]).addItem(baseURI, 100)

    const txReceipt = await txResponse.wait()
    const [txEvent] = await txReceipt.events
    currentNFTID= txEvent.args.tokenId
    console.log(currentNFTID)

    // const owner = await NFTContract.ownerOf(tokenId)
    // console.log(owner)
  })

  it("Transfer the first NFT to addrs[2]", async () => {
    await NFTContract.connect(addrs[1]).approve(addrs[2].address, currentNFTID)
    await NFTContract.connect(addrs[1]).transferFrom(addrs[1].address, addrs[2].address, currentNFTID)
  })

  it("list the first NFT of collection by NFT owner", async () => {
    await NFTContract.connect(addrs[2]).approve(TheXdaoMarket.address, currentNFTID)
    const collections = await TheXdaoMarket.connect(addrs[2]).getCollections();
    await TheXdaoMarket.connect(addrs[2]).list(collections[0], currentNFTID, ethers.utils.parseEther("10"))
  })

  it("Checking governance token balance", async () => {
    await governanceTokenBalanceOfAddress()
  })

  it("Buy the one NFT of collection by addrs[3]", async () => {
    governanceToken.connect(addrs[3]).approve(TheXdaoMarket.address, ethers.utils.parseEther("100"))
    const currentPairId = await TheXdaoMarket.connect(addrs[3]).currentPairId();
    await TheXdaoMarket.connect(addrs[3]).buy(currentPairId)
  })

  it("Checking governance token balance", async () => {
    await governanceTokenBalanceOfAddress()
  })

  it("Delist the first NFT from collection by pair owner or market owner", async () =>{})

});
