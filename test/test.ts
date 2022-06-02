import { expect } from 'chai'
import { deployments, ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BASE_URI } from '../scripts/address'
import { BigNumber } from 'ethers'
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
      args: [vintageWine.address, oracle.address, BASE_URI],
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
      // Mint Vintage for promote
      await vintageWine.mintPromotionalVintageWine(owner.address)
      // Provide Avax-VintageWine pool
      await vintageWine.mintAvaxLPVintageWine()
      // provide Grape-VintageWine pool
      await vintageWine.mintGrapeLPVintageWine()
    })
    it('Should assign the total supply of Grape tokens to the owner', async function () {
      const ownerGrapeBalance = await grape.balanceOf(owner.address)
      expect(await grape.totalSupply()).to.equal(ownerGrapeBalance)
      const ownerVintageWineBalance = await vintageWine.balanceOf(owner.address)
      const promoteAmount = await vintageWine.NUM_PROMOTIONAL_VINTAGEWINE()
      const AvaxLPAmount = await vintageWine.NUM_VINTAGEWINE_AVAX_LP()
      const GrapeLPAmount = await vintageWine.NUM_VINTAGEWINE_GRAPE_LP()
      expect(promoteAmount.add(AvaxLPAmount).add(GrapeLPAmount)).to.equal(
        ownerVintageWineBalance.div(BigNumber.from(10).pow(18)),
      )
    })
  })
  describe('Initialize contracts', function () {
    it('Initialize Vintage Wine contract', async function () {
      await vintageWine.setCellarAddress(cellar.address)
      await vintageWine.setWineryAddress(winery.address)
      await vintageWine.setVintnerAddress(vintner.address)
      await vintageWine.setUpgradeAddress(upgrade.address)
      expect(await vintageWine.vintnerAddress()).to.equal(vintner.address)
    })
  })
  describe('Vintner', function () {
    it('Set Start time', async function () {
      // Set start time before mint
      await vintner.setStartTimeAVAX(Math.floor(Date.now() / 1000) + 15)
      await vintner.setStartTimeVINTAGEWINE(Math.floor(Date.now() / 1000) + 15)
      await winery.setStartTime(Math.floor(Date.now() / 1000) + 15)
    })
    it('Mint Vintner ERC721 tokens', async function () {
      // Send vintageWine token to caller
      await vintageWine.transfer(
        caller.address,
        BigNumber.from(200000).mul(BigNumber.from(10).pow(18)),
      )
      // Check the caller balance
      const callerBalance = await vintageWine.balanceOf(caller.address)
      expect(callerBalance).to.equal(
        BigNumber.from(200000).mul(BigNumber.from(10).pow(18)),
      )
      expect(await vintner.vintageWine()).to.equal(vintageWine.address)

      // Mint vinter promotional - 1 ~ 50 would promote for owner ( only owner )
      await vintner.mintPromotional(3, 1, owner.address) // Mint normal vintner  - token amount, vintner type, target address
      await vintner.mintPromotional(2, 2, owner.address) // Mint master vintner
      expect(await vintner.vintnersMintedPromotional()).to.equal(5)

      // Mint vinter using Avax
      await vintner.connect(caller).mintVintnerWithAVAX(2, {
        value: ethers.utils.parseEther('3'),
      }) // 1.5 avax
      expect(await vintner.vintnersMintedWithAVAX()).to.equal(2)

      // Mint vinter using vintageWine
      await vintner.connect(caller).mintVintnerWithVINTAGEWINE(3) // each token for 20,000 vintageWine
      expect(await vintner.vintnersMintedWithVINTAGEWINE()).to.equal(3)
    })
  })
  describe('Winery', function () {
    it('Initialize contract', async function () {
      // We need to do this in real production
      // await winery.initialize(
      //   vintner.address,
      //   upgrade.address,
      //   vintageWine.address,
      //   grape.address,
      //   cellar.address,
      //   wineryProgression.address,
      // )

      // Check contract address is right
      expect(await winery.wineryProgression()).to.equal(
        wineryProgression.address,
      )
      expect(await winery.grape()).to.equal(grape.address)
      expect(await winery.vintner()).to.equal(vintner.address)
    })
    it('Stake Vinter ERC721 to Winery', async function () {
      // 1 ~ 50 is promotion for owner
      expect(await vintner.ownerOf(1)).to.equal(owner.address)
      expect(await vintner.ownerOf(5)).to.equal(owner.address)
      // 51 ~ for normal user
      expect(await vintner.ownerOf(51)).to.equal(caller.address)
      expect(await vintner.ownerOf(55)).to.equal(caller.address)

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
      await vintner.connect(oracle).setVintnerType(51, 1) // token ID, vintner type
      await vintner.connect(oracle).setVintnerType(52, 1)
      await vintner.connect(oracle).setVintnerType(53, 1)
      await vintner.connect(oracle).setVintnerType(54, 1)
      await vintner.connect(oracle).setVintnerType(55, 2)
      // Should approve Vinery token to Winery address
      await vintner.connect(caller).approve(winery.address, 51)
      await expect(winery.connect(caller).stakeMany([51, 52, 53, 54, 55], []))
        .to.be.reverted
      await vintner.connect(caller).setApprovalForAll(winery.address, true)
      await winery.connect(caller).stakeMany([51, 52, 53, 54, 55], [])
    })
  })
})
