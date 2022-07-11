import { expect } from 'chai'
import { deployments, ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { couponPublic, couponPrivate, BASE_URI } from '../scripts/address'
import { BigNumber } from 'ethers'
import { keccak256, toBuffer, ecsign, bufferToHex } from 'ethereumjs-util'
import {
  Cellar,
  Grape,
  Upgrade,
  VintageWine,
  Vintner,
  Winery,
  WineryProgression,
} from '../typechain'
import { execPath } from 'process'

describe('Wine Connoisseur game', function () {
  // Account
  let owner: SignerWithAddress
  let caller: SignerWithAddress
  let oracle: SignerWithAddress

  // Contract
  let vintageWine: VintageWine
  let grape: Grape
  let cellar: Cellar
  let upgrade: Upgrade
  let vintner: Vintner
  let winery: Winery
  let wineryProgression: WineryProgression

  before(async () => {
    const signers = await ethers.getSigners()
    owner = signers[0]
    oracle = signers[1]
    caller = signers[2]

    // erc20Owner = signers[2]
    // erc721Owner = signers[3]

    // Deploy vintage Wine Contract
    let receipt = await deployments.deploy('VintageWine', {
      from: owner.address,
      args: [],
      log: true,
    })
    vintageWine = await ethers.getContractAt('VintageWine', receipt.address)
    // Deploy Grape Contract
    receipt = await deployments.deploy('Grape', {
      from: owner.address,
      args: [],
      log: true,
    })
    grape = await ethers.getContractAt('Grape', receipt.address)

    // Deploy Cellar Contract
    receipt = await deployments.deploy('Cellar', {
      from: owner.address,
      args: [vintageWine.address],
      log: true,
    })
    cellar = await ethers.getContractAt('Cellar', receipt.address)
    // Deploy Upgrade Contract
    receipt = await deployments.deploy('Upgrade', {
      from: owner.address,
      args: [vintageWine.address, grape.address, BASE_URI],
      log: true,
    })
    upgrade = await ethers.getContractAt('Upgrade', receipt.address)

    // Deploy Vintner Contract
    receipt = await deployments.deploy('Vintner', {
      from: owner.address,
      args: [grape.address, couponPublic, oracle.address, BASE_URI],
      log: true,
    })
    vintner = await ethers.getContractAt('Vintner', receipt.address)
    // Deploy Winery Progression Contract
    receipt = await deployments.deploy('WineryProgression', {
      from: owner.address,
      args: [grape.address],
      log: true,
    })
    wineryProgression = await ethers.getContractAt(
      'WineryProgression',
      receipt.address,
    )

    // Deploy Winery Contract
    const Winery = await ethers.getContractFactory('Winery')
    const WineryDeployed = await upgrades.deployProxy(Winery, [
      vintner.address,
      upgrade.address,
      vintageWine.address,
      grape.address,
      cellar.address,
      wineryProgression.address,
    ])
    await WineryDeployed.deployed()

    winery = await ethers.getContractAt('Winery', WineryDeployed.address)
  })
  describe('Deploy contract', async () => {
    it('should be deployed', async () => {})
  })
  describe('Mint token', async () => {
    it('Mint Vintage token', async function () {
      // Mint Grape token
      await grape.mint(
        owner.address,
        BigNumber.from(1000000).mul(BigNumber.from(10).pow(18)),
      )
      await grape.transferOperator(owner.address)
      // Mint Vintage for promote
      await vintageWine.mintVintageWine(
        owner.address,
        BigNumber.from(50000000).mul(BigNumber.from(10).pow(18)),
      )
      // Provide Avax-VintageWine pool
      // await vintageWine.mintAvaxLPVintageWine()
      // provide Grape-VintageWine pool
      // await vintageWine.mintUSDCLPVintageWine();
    })
    it('Should assign the total supply of Grape tokens to the owner', async function () {
      const ownerGrapeBalance = await grape.balanceOf(owner.address)
      expect(await grape.totalSupply()).to.equal(ownerGrapeBalance)
    })
  })
  describe('Initialize contracts', function () {
    it('Set Start time', async function () {
      await vintner.setStartTime(Math.floor(Date.now() / 1000) )
      await vintner.setStartTimeWhitelist(Math.floor(Date.now() / 1000) )
      await upgrade.setStartTime(Math.floor(Date.now() / 1000) )
      await cellar.setStakeStartTime(Math.floor(Date.now() / 1000) )
      await wineryProgression.setLevelStartTime(
        Math.floor(Date.now() / 1000) ,
      )

      await winery.setStartTime(Math.floor(Date.now() / 1000) )
    })
    it('Set initial values', async function () {
      await vintageWine.setCellarAddress(cellar.address)
      await vintageWine.setWineryAddress(winery.address)
      await vintageWine.setUpgradeAddress(upgrade.address)
      await vintner.setWineryAddress(winery.address)
      await upgrade.setWineryAddress(winery.address)
      // We need to do this in real production !!!
      // await winery.initialize(
      //   vintner.address,
      //   upgrade.address,
      //   vintageWine.address,
      //   grape.address,
      //   cellar.address,
      //   wineryProgression.address,
      // )
    })
  })
  describe('Vintner 721 token', function () {
    it('Mint Vintner ERC721 tokens', async function () {
      // Send vintageWine token to caller
      await grape.transfer(
        caller.address,
        BigNumber.from(2000).mul(BigNumber.from(10).pow(18)),
      )
      // Check the caller balance
      const callerBalance = await grape.balanceOf(caller.address)
      expect(callerBalance).to.equal(
        BigNumber.from(2000).mul(BigNumber.from(10).pow(18)),
      )

      // Mint vinter promotional - 1 ~ 50 would promote for owner ( only owner )
      await vintner.mintPromotional(3, 1, owner.address) // Mint normal vintner  - token amount, vintner type, target address
      await vintner.mintPromotional(2, 2, owner.address) // Mint master vintner
      expect(await vintner.vintnersMintedPromotional()).to.equal(5)

      // Mint vinter using Avax
      await vintner.connect(caller).mintVintnerWithAVAX(5, {
        value: ethers.utils.parseEther('15'),
      }) // 1.5 avax
      await grape
        .connect(caller)
        .approve(
          vintner.address,
          BigNumber.from(1000).mul(BigNumber.from(10).pow(18)),
        )
      await vintner.connect(caller).mintVintnerWithGrape(5) // 1.5 avax

      expect(await vintner.vintnerPublicMinted()).to.equal(10)
    })
    it('Mint Vintner for Whitelist', async function () {
      // Create Coupon for sign
      function serializeCoupon(coupon: any) {
        return {
          r: bufferToHex(coupon.r),
          s: bufferToHex(coupon.s),
          v: coupon.v,
        }
      }
      /**
       * * signerPvtKeyString
       * Private key generated from ethers.Wallet.createRandom() - stored as a non-public environment variable
       * @notice The address used in your Smart Contract to verify the coupon must be the public address associated with this key
       */

      const signerPvtKey = Buffer.from(couponPrivate, 'hex')

      console.log('signerPvtKey', signerPvtKey)

      const hashBuffer = keccak256(
        toBuffer(
          ethers.utils.defaultAbiCoder.encode(
            ['uint256', 'address'],
            [5, caller.address],
          ),
        ),
      )

      const coupon = ecsign(hashBuffer, signerPvtKey)
      const serialize = serializeCoupon(coupon)

      // Mint vinter for whitelist
      await vintner.connect(caller).mintWhitelist(2, 5, serialize) // quality , allottedMint , couponRSV ( for sign )
      expect(await vintner.whitelistClaimed(caller.address)).to.equal(2)
    })
    // it('Get Info for Owner', async function () {
    //   /**
    //    * @param
    //    * _owner
    //    * _offset
    //    * _maxSize
    //    */
    //   const result1 = await vintner.batchedVintnersOfOwner(owner.address, 0, 10)
    //   const result2 = await vintner.batchedVintnersOfOwner(caller.address, 3, 3)
    // })
  })
  describe('Tools 721 token', function () {
    it('Add level', async function () {
      // 3 types of level was made in constructor
      /***
       * @Params
       * maxSupply
       * priceVintageWine
       * priceGrape
       * yield
       */
      upgrade.addLevel(
        1800,
        BigNumber.from(25000).mul(BigNumber.from(10).pow(18)),
        BigNumber.from(130).mul(BigNumber.from(10).pow(18)),
        7,
      )
    })
    it('Change Level', async function () {
      it('Add level', async function () {
        // 3 types of level was made in constructor
        /***
         * @Params
         * maxSupply
         * priceVintageWine
         * priceGrape
         * yield
         */
        upgrade.changeLevel(
          3,
          1500,
          BigNumber.from(26000).mul(BigNumber.from(10).pow(18)),
          BigNumber.from(150).mul(BigNumber.from(10).pow(18)),
          7,
        )
      })
    })
    it('Mint Tools ERC721 tokens', async function () {
      // Transfer grape and vintageWine to allow caller buy the tools nft
      await grape.transfer(
        caller.address,
        BigNumber.from(200000).mul(BigNumber.from(10).pow(18)),
      )
      await vintageWine.transfer(
        caller.address,
        BigNumber.from(200000).mul(BigNumber.from(10).pow(18)),
      )
      // Need to approve Grape token and Vintage Wine token to buy Tools token according Level
      const mintAmount = 2
      await grape.approve(
        upgrade.address,
        BigNumber.from((50 + 80 + 110) * mintAmount).mul(
          BigNumber.from(10).pow(18),
        ),
      ) // level 0 - 2, level 1 - 2, level 2 - 2
      // await vintageWine.approve(
      //   upgrade.address,
      //   BigNumber.from((3000 + 10000 + 25000) * mintAmount).mul(
      //     BigNumber.from(10).pow(18),
      //   ),
      // )
      await grape
        .connect(caller)
        .approve(
          upgrade.address,
          BigNumber.from((50 + 80 + 110) * mintAmount).mul(
            BigNumber.from(10).pow(18),
          ),
        )
      // await vintageWine
      //   .connect(caller)
      //   .approve(
      //     upgrade.address,
      //     BigNumber.from((3000 + 10000 + 25000) * mintAmount).mul(
      //       BigNumber.from(10).pow(18),
      //     ),
      //   )
      // 98 % of grape and vintageWine token will be burned when mint , 2% will be in Upgrade(Tools) contract

      // Level would be 0 ~ 2 , means there are 3 types of tools
      // level 0 supply: 0, maxSupply: 2500, priceVintageWine: 3000 * 1e18, priceGrape: 50 * 1e18, yield: 1
      // level 1 supply: 0, maxSupply: 2200, priceVintageWine: 10000 * 1e18, priceGrape: 80 * 1e18, yield: 3
      // level 2 supply: 0, maxSupply: 2000, priceVintageWine: 20000 * 1e18, priceGrape: 110 * 1e18, yield: 5

      await upgrade.mintUpgrade(0, mintAmount) // level, amount
      await upgrade.mintUpgrade(1, mintAmount)
      await upgrade.mintUpgrade(2, mintAmount)
      await upgrade.connect(caller).mintUpgrade(0, mintAmount)
      await upgrade.connect(caller).mintUpgrade(1, mintAmount)
      await upgrade.connect(caller).mintUpgrade(2, mintAmount)
    })
    // it('Get Info for Owner', async function () {
    //   /**
    //    * @param
    //    * _owner
    //    * _offset
    //    * _maxSize
    //    */
    //   const result1 = await upgrade.batchedUpgradesOfOwner(owner.address, 0, 10)
    //   const result2 = await upgrade.batchedUpgradesOfOwner(caller.address, 3, 3)
    // })
  })
  describe('Winery', function () {
    it('Stake Vinter ERC721 to Winery', async function () {
      // 1 ~ 50 is promotion for owner
      expect(await vintner.ownerOf(1)).to.equal(owner.address)
      expect(await vintner.ownerOf(5)).to.equal(owner.address)
      // 51 ~ for normal user
      expect(await vintner.ownerOf(51)).to.equal(caller.address)
      expect(await vintner.ownerOf(55)).to.equal(caller.address)

      // Would be reverted because caller is not owner of 1,2,3 Vintner
      await expect(winery.connect(caller).stakeMany([1, 2, 3], [])).to.be
        .reverted

      await vintner.setApprovalForAll(winery.address, true)
      await winery.stakeMany([1, 2, 3, 4, 5], [])

      // Set Vintner type before stake
      /**
       * @dev as an anti cheat mechanism, an external automation will generate the NFT metadata and set the vintner types via rng
       * - Using an external source of randomness ensures our mint cannot be cheated
       * - The external automation is open source and can be found on vintageWine game's github
       * - Once the mint is finished, it is provable that this randomness was not tampered with by providing the seed
       * - Vintner type can be set only once
       */
      await vintner.connect(oracle).setVintnerType(51, 1) // token ID, vintner type - 1 for normal ,2 for master
      await vintner.connect(oracle).setVintnerType(52, 1)
      await vintner.connect(oracle).setVintnerType(53, 1)
      await vintner.connect(oracle).setVintnerType(54, 1)
      await vintner.connect(oracle).setVintnerType(55, 2)
      // Should approve Vinery token to Winery address
      // await vintner.connect(caller).approve(winery.address, 51)
      // await expect(winery.connect(caller).stakeMany([51, 52, 53, 54, 55], []))
      //   .to.be.reverted
      // await vintner.connect(caller).setApprovalForAll(winery.address, true)
      await winery.connect(caller).stakeMany([51, 52, 53, 54, 55], [])
    })
    it('Stake Tools ERC721 to Winery for owner', async function () {
      // 1 ~ 6 for owner - each level have 2
      expect(await upgrade.ownerOf(1)).to.equal(owner.address)
      expect(await upgrade.ownerOf(6)).to.equal(owner.address)
      // 7 ~ 12 for caller
      expect(await upgrade.ownerOf(7)).to.equal(caller.address)
      expect(await upgrade.ownerOf(12)).to.equal(caller.address)

      await upgrade.setApprovalForAll(winery.address, true)

      // Tool amount would be less thaan Vintner amount
      await expect(winery.stakeMany([], [1, 2, 3, 4, 5, 6])).to.be.revertedWith(
        'Needs at least vintner for each tool',
      )
      // Deposit grape to upgrade the skill point to be able to deposit level3 Tool
      await expect(winery.stakeMany([], [1, 2, 3, 4, 5])).to.be.revertedWith(
        "You can't equip that tool",
      )
      await grape.approve(
        wineryProgression.address,
        BigNumber.from(1001).mul(BigNumber.from(10).pow(18)),
      )
      await wineryProgression.depositGrape(
        BigNumber.from(1001).mul(BigNumber.from(10).pow(18)),
      )
      const UPGRADES_ID = 4

      await wineryProgression.spendSkillPoints(UPGRADES_ID, 1)
      await wineryProgression.spendSkillPoints(UPGRADES_ID, 2)
      await winery.stakeMany([], [1, 2, 3, 4, 5])

      // await winery.connect(caller.address).stakeMany([], [6, 7, 8, 9, 10])
    })
    it('Stake Tools ERC721 to Winery for normal user', async function () {
      await upgrade.connect(caller).setApprovalForAll(winery.address, true)

      // Tool amount would be less thaan Vintner amount
      await expect(
        winery.connect(caller).stakeMany([], [7, 8, 9, 10, 11, 12]),
      ).to.be.revertedWith('Needs at least vintner for each tool')
      // Deposit grape to upgrade the skill point to be able to deposit level3 Tool
      await expect(
        winery.connect(caller).stakeMany([], [7, 8, 9, 10, 11]),
      ).to.be.revertedWith("You can't equip that tool")
      await grape
        .connect(caller)
        .approve(
          wineryProgression.address,
          BigNumber.from(1001).mul(BigNumber.from(10).pow(18)),
        )
      await wineryProgression
        .connect(caller)
        .depositGrape(BigNumber.from(1001).mul(BigNumber.from(10).pow(18)))
      const UPGRADES_ID = 4

      await wineryProgression.connect(caller).spendSkillPoints(UPGRADES_ID, 1)
      await wineryProgression.connect(caller).spendSkillPoints(UPGRADES_ID, 2)
      await winery.connect(caller).stakeMany([], [7, 8, 9, 10, 11])

      // await winery.connect(caller.address).stakeMany([], [6, 7, 8, 9, 10])
    })
    it('Calculate fatigue', async function () {
      const fatiguePerMinute = await winery.fatiguePerMinute(owner.address)
      const fatigueSkillModifier =
        await wineryProgression.getFatigueSkillModifier(owner.address)
      const fatigueTuner = await winery.fatigueTuner()
      const fatiguePerMinutewithModi =
        await winery.getFatiguePerMinuteWithModifier(owner.address)
      const getVintageWineAccrued = await winery.getVintageWineAccrued(
        owner.address,
      )

      console.log('fatiguePerMinute', fatiguePerMinute)
      console.log('fatigueSkillModifier', fatigueSkillModifier)
      console.log('fatigueTuner', fatigueTuner)
      console.log('fatiguePerMinutewithModi', fatiguePerMinutewithModi)
      console.log('getVintageWineAccrued', getVintageWineAccrued)
    })
    it('Get Staked Vintner and Tool for user', async function () {
      /**
       * @param
       * _owner
       * _offset
       * _maxSize
       */
      const result1 = await winery.batchedStakesOfOwner(owner.address, 0, 10)
      const result2 = await winery.batchedToolsOfOwner(caller.address, 0, 10)
    })
    it('Claim vintageWine', async function () {
      // VintageWine token will be sent to owner and cellar
      await winery.claimVintageWine()
      await winery.connect(caller).claimVintageWine()
    })
    it('Unstake Vintners', async function () {
      // To unstake token , 2000 vintagewine would be tax, so it would be reverted unless Vintner make 2000 vintageWine tokens
      await expect(
        winery.unstakeVintnersAndUpgrades([1, 2, 3], []),
      ).to.be.revertedWith('Needs at least vintner for each tool')
      await expect(
        winery.unstakeVintnersAndUpgrades([1, 2, 3], [1, 2, 3]),
      ).to.be.revertedWith('Not enough VintageWine to pay the unstake penalty.')
      // await expect(
      //   winery.connect(caller).unstakeVintnersAndUpgrades([51, 52, 53], []),
      // )
    })
    it('Withdraw Vintner', async function () {
      await expect(winery.withdrawVintners([1, 2, 3])).to.be.revertedWith(
        'Vintner is not resting',
      )
    })
  })
  describe('Cellar', function () {
    it('Stake VintageWine to Cellar', async function () {
      cellar.stake(BigNumber.from(200000).mul(BigNumber.from(10).pow(18)))
    })
    it('Withdraw VintageWintoken', async function () {
      /**
       * There are two method to withdraw - QuickUnStake, DelayedUnstake
       * Quick Unstake - 50% of token will be burned , 50% will be sent immediately
       * Delayed Unstake - 10% of token will be burned, can withdrawl after 2 days
       */
      // Quick Unstake
      const share = 200000
      // Cannot unstake if bigger than staked amount
      await expect(
        cellar.quickUnstake(
          BigNumber.from(share + 1).mul(BigNumber.from(10).pow(18)),
        ),
      ).to.be.reverted
      await cellar.quickUnstake(
        BigNumber.from(share).mul(BigNumber.from(10).pow(18)),
      )
      // Delayed Unstake
      cellar.stake(BigNumber.from(share).mul(BigNumber.from(10).pow(18)))
      await cellar.prepareDelayedUnstake(
        BigNumber.from(share).mul(BigNumber.from(10).pow(18)),
      )
      // After 2 days , can be claimed
      await expect(
        cellar.claimDelayedUnstake(
          BigNumber.from(share).mul(BigNumber.from(10).pow(18)),
        ),
      ).to.be.revertedWith('VINTAGEWINE not yet unlocked')
    })
  })
})
