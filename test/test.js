const { ethers } = require('hardhat');
const { assert, expect } = require("chai");
const { time } = require('@nomicfoundation/hardhat-network-helpers');

describe('Normal Staking', () => {

  let rewardToken, projectToken, stakingContract;
  let owner, alli;

  before( async () => {
    rewardToken = await ethers.deployContract('RewardToken', ['Reward Token', 'rewardToken'])
    projectToken = await ethers.deployContract('ProjectToken', ['Project Token', 'projectToken'])
    stakingContract = await ethers.deployContract('StakingContract', [projectToken.address, rewardToken.address])

    const addrs = await ethers.getSigners()

    owner = addrs[0]
    alli = addrs[1]
  } )

  describe("Get started", async () => {
    it("Approve reward token", async () => {
      const balance = ethers.utils.parseEther('1000')
      await rewardToken.approve(stakingContract.address, balance)
    })

    it("Add balance of reward token", async () => {
      const balance = ethers.utils.parseEther('1000')
      await stakingContract.addRewardToken(balance)
    })
    
    it("Set durations as [100s, 200s, 300s, 400s] for testing", async () => {
      await stakingContract.setDurations([100, 200, 300, 400])
    })

    it("Set rates as [1%, 5%, 10%, 30%] for testing", async () => {
      await stakingContract.setRates([10, 50, 100, 300])
    })

    it("Distribute 100 project token to accounts", async () => {
      const balance = ethers.utils.parseEther('100')
      await projectToken.transfer(alli.address, balance)
    })

    it("Start staking", async () => {
      await stakingContract.unPause()
    })
  })

  describe("Staking Token", async () => {
    it("Approve project token", async () => {
      const balance = ethers.utils.parseEther('100')
      await projectToken.connect(alli).approve(stakingContract.address, balance);
    })

    it("Stake 100 project token to first pool {100s, 1%}", async () => {
      const balance = ethers.utils.parseEther('100')
      await stakingContract.connect(alli).stake(balance, 0)
    })
  })

  describe("Claim reward", async () => {
    it("Balance of reward token what user can get should be 1", async () => {
      expect(await stakingContract.getReward(alli.address, 1)).to.equal(ethers.utils.parseEther('1'))
    })

    it("Reward token balance of user before claiming should be 0", async () => {
      expect(await rewardToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('0'))
    })

    it('Increase time by 100s', async () => {
      await time.increase(100)
    })

    it('Claim reward token', async () => {
      await stakingContract.connect(alli).claimReward(1);
    })

    it("Reward token balance of user after claiming should be 1", async () => {
      expect(await rewardToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('1'))
    })
  })

  describe("Unstake", () => {
    it("Project token balance of user before unstaking should be 0", async () => {
      expect(await projectToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('0'))
    })

    it("Unstaking", async () => {
      await stakingContract.connect(alli).unStake(1);
    })

    it("Project token balance of user after unstaking should be 100", async () => {
      expect(await projectToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('100'))
    })
  })
});

describe('Staking with referral', () => {

  let rewardToken, projectToken, stakingContract;
  let owner, alli;

  before( async () => {
    rewardToken = await ethers.deployContract('RewardToken', ['Reward Token', 'rewardToken'])
    projectToken = await ethers.deployContract('ProjectToken', ['Project Token', 'projectToken'])
    stakingContract = await ethers.deployContract('StakingContract', [projectToken.address, rewardToken.address])

    const addrs = await ethers.getSigners()

    owner = addrs[0]
    alli = addrs[1]
  } )

  describe("Get started", async () => {
    it("Approve reward token", async () => {
      const balance = ethers.utils.parseEther('1000')
      await rewardToken.approve(stakingContract.address, balance)
    })

    it("Add balance of reward token", async () => {
      const balance = ethers.utils.parseEther('1000')
      await stakingContract.addRewardToken(balance)
    })
    
    it("Set durations as [100s, 200s, 300s, 400s] for testing", async () => {
      await stakingContract.setDurations([100, 200, 300, 400])
    })

    it("Set rates as [1%, 5%, 10%, 30%] for testing", async () => {
      await stakingContract.setRates([10, 50, 100, 300])
    })

    it("Distribute 100 project token to accounts", async () => {
      const balance = ethers.utils.parseEther('100')
      await projectToken.transfer(alli.address, balance)
    })

    it("Start staking", async () => {
      await stakingContract.unPause()
    })
  })

  describe("Staking Token", () => {
    it("Approve project token", async () => {
      const balance = ethers.utils.parseEther('100')
      await projectToken.connect(alli).approve(stakingContract.address, balance);
    })

    it("Stake 100 project token to first pool {100s, 1%}", async () => {
      const balance = ethers.utils.parseEther('100')
      await stakingContract.connect(alli).stake(balance, 0)
    })
  })

  describe("Add referral", () => {
    const IncreaseRatePerOneReferral = 1; // 0.1%

    it("Only owner can increase rate", async () => {
      expect(stakingContract.connect(alli).increaseRate(alli.address, 1, IncreaseRatePerOneReferral)).to.be.revertedWith('Ownable: caller is not the owner')
    })

    it("Increase rate about one referral", async () => {
      await stakingContract.increaseRate(alli.address, 1, IncreaseRatePerOneReferral)
    })

  })

  describe("Claim reward", async () => {
    it("Balance of reward token what user can get should be 1.1", async () => {
      expect(await stakingContract.getReward(alli.address, 1)).to.equal(ethers.utils.parseEther('1.1'))
    })

    it("Reward token balance of user before claiming should be 0", async () => {
      expect(await rewardToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('0'))
    })

    it('Increase time by 100s', async () => {
      await time.increase(100)
    })

    it('Claim reward token', async () => {
      await stakingContract.connect(alli).claimReward(1);
    })

    it("Reward token balance of user after claiming should be 1.1", async () => {
      expect(await rewardToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('1.1'))
    })
  })

  describe("Unstake", () => {
    it("Project token balance of user before unstaking should be 0", async () => {
      expect(await projectToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('0'))
    })

    it("Unstaking", async () => {
      await stakingContract.connect(alli).unStake(1);
    })

    it("Project token balance of user after unstaking should be 100", async () => {
      expect(await projectToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('100'))
    })
  })
});

describe("Multi staking", () => {
  let rewardToken, projectToken, stakingContract;
  let owner, alli;

  before( async () => {
    rewardToken = await ethers.deployContract('RewardToken', ['Reward Token', 'rewardToken'])
    projectToken = await ethers.deployContract('ProjectToken', ['Project Token', 'projectToken'])
    stakingContract = await ethers.deployContract('StakingContract', [projectToken.address, rewardToken.address])

    const addrs = await ethers.getSigners()

    owner = addrs[0]
    alli = addrs[1]
  } )

  describe("Get started", async () => {
    it("Approve reward token", async () => {
      const balance = ethers.utils.parseEther('1000')
      await rewardToken.approve(stakingContract.address, balance)
    })

    it("Add balance of reward token", async () => {
      const balance = ethers.utils.parseEther('1000')
      await stakingContract.addRewardToken(balance)
    })
    
    it("Set durations as [100s, 200s, 300s, 400s] for testing", async () => {
      await stakingContract.setDurations([100, 200, 300, 400])
    })

    it("Set rates as [1%, 5%, 10%, 30%] for testing", async () => {
      await stakingContract.setRates([10, 50, 100, 300])
    })

    it("Distribute 100 project token to accounts", async () => {
      const balance = ethers.utils.parseEther('100')
      await projectToken.transfer(alli.address, balance)
    })

    it("Start staking", async () => {
      await stakingContract.unPause()
    })
  })

  describe("Staking Token", async () => {
    it("Approve project token", async () => {
      const balance = ethers.utils.parseEther('100')
      await projectToken.connect(alli).approve(stakingContract.address, balance);
    })

    it("Stake 50 project token to first pool[duration:100s, rate:1%]", async () => {
      const balance = ethers.utils.parseEther('50')
      await stakingContract.connect(alli).stake(balance, 0)
    })

    it("Stake 50 project token to second pool[duration:200s, rate:5%]", async () => {
      const balance = ethers.utils.parseEther('50')
      await stakingContract.connect(alli).stake(balance, 1)
    })
  })

  describe("Claim reward", async () => {
    it("Balance of reward token what user can get should be 3", async () => {
      expect(await stakingContract.getAllReward(alli.address)).to.equal(ethers.utils.parseEther('3'))
    })

    it("Reward token balance of user before claiming should be 0", async () => {
      expect(await rewardToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('0'))
    })

    it('Increase time by 200s', async () => {
      await time.increase(200)
    })

    it('Claim reward token', async () => {
      await stakingContract.connect(alli).claimAllReward();
    })

    it("Reward token balance of user after claiming should be 3", async () => {
      expect(await rewardToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('3'))
    })
  })

  describe("Unstake", () => {
    it("Project token balance of user before unstaking should be 0", async () => {
      expect(await projectToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('0'))
    })

    it("Unstaking", async () => {
      await stakingContract.connect(alli).unStake(1);
      await stakingContract.connect(alli).unStake(2);
    })

    it("Project token balance of user after unstaking should be 100", async () => {
      expect(await projectToken.balanceOf(alli.address)).to.equal(ethers.utils.parseEther('100'))
    })
  })
})
