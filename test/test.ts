import { expect } from 'chai'
import { deployments, ethers, upgrades } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { oracleAddress, BASE_URI } from '../scripts/address'
import {
  Cellar,
  Grape,
  Upgrade,
  VintageWine,
  Vintner,
  Winery,
  WineryProgression,
} from '../typechain'

describe('Wine Connoisseur game', function () {
  // Account
  let deployer: SignerWithAddress
  let caller: SignerWithAddress

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
    deployer = signers[0]
    caller = signers[1]
    // erc20Owner = signers[2]
    // erc721Owner = signers[3]

    // Deploy vintage Wine Contract
    let receipt = await deployments.deploy('VintageWine', {
      from: deployer.address,
      args: [],
      log: true,
    })
    vintageWine = await ethers.getContractAt('VintageWine', receipt.address)
    // Deploy Grape Contract
    receipt = await deployments.deploy('Grape', {
      from: deployer.address,
      args: [],
      log: true,
    })
    grape = await ethers.getContractAt('Grape', receipt.address)
    // Deploy Cellar Contract
    receipt = await deployments.deploy('Cellar', {
      from: deployer.address,
      args: [vintageWine.address],
      log: true,
    })
    cellar = await ethers.getContractAt('Cellar', receipt.address)
    // Deploy Upgrade Contract
    receipt = await deployments.deploy('Upgrade', {
      from: deployer.address,
      args: [vintageWine.address, grape.address, BASE_URI],
      log: true,
    })
    upgrade = await ethers.getContractAt('Upgrade', receipt.address)

    // Deploy Vintner Contract
    receipt = await deployments.deploy('Vintner', {
      from: deployer.address,
      args: [vintageWine.address, oracleAddress, BASE_URI],
      log: true,
    })
    vintner = await ethers.getContractAt('Vintner', receipt.address)
    // Deploy Winery Progression Contract
    receipt = await deployments.deploy('WineryProgression', {
      from: deployer.address,
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
    console.log('winery', winery.address)
  })
  describe('deploy', async () => {
    it('should be deployed', async () => {})
  })
  // describe('Vintner', function () {
  //   it('Deploy Vintner ERC721 token contract', async function () {
  //     const setGreetingTx = await greeter.setGreeting('Hola, mundo!')

  //     // wait until the transaction is mined
  //     await setGreetingTx.wait()

  //     expect(await greeter.greet()).to.equal('Hola, mundo!')
  //   })
  // })
})
