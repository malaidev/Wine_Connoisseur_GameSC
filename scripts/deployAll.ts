import { ethers, upgrades } from 'hardhat'
import {
  grapeTokenAddress,
  couponPublic,
  oracleAddress,
  BASE_URI,
  BASE_URI_UPGRADE,
} from './address'

async function main(): Promise<{}> {
  const [deployer] = await ethers.getSigners()
  if (deployer === undefined) throw new Error('Deployer is undefined.')

  console.log('Account balance:', (await deployer.getBalance()).toString())

  let vintageWineAddress,
    vintnerAddress,
    upgradeAddress,
    cellarAddress,
    wineryProgressionAddress,
    wineryAddress

  //   const Grape = await ethers.getContractFactory('Grape')
  //   const Grape_Deployed = await Grape.deploy()
  //   grapeAddress = Grape_Deployed.address

  const VintageWine = await ethers.getContractFactory('VintageWine')
  const VintageWine_Deployed = await VintageWine.deploy()
  vintageWineAddress = VintageWine_Deployed.address
  console.log('vintageWineAddress', vintageWineAddress)

  const Vintner = await ethers.getContractFactory('Vintner')
  const Vintner_Deployed = await Vintner.deploy(
    grapeTokenAddress,
    couponPublic,
    oracleAddress,
    BASE_URI,
  )
  vintnerAddress = Vintner_Deployed.address
  console.log('vintnerAddress', vintnerAddress)

  const Upgrade = await ethers.getContractFactory('Upgrade')
  const Upgrade_Deployed = await Upgrade.deploy(
    vintageWineAddress,
    grapeTokenAddress,
    BASE_URI_UPGRADE,
  )
  upgradeAddress = Upgrade_Deployed.address
  console.log('upgradeAddress', upgradeAddress)

  const Cellar = await ethers.getContractFactory('Cellar')
  const Cellar_Deployed = await Cellar.deploy(vintageWineAddress)
  cellarAddress = Cellar_Deployed.address
  console.log('cellarAddress', cellarAddress)

  const WineryProgression = await ethers.getContractFactory('WineryProgression')
  const WineryProgression_Deployed = await WineryProgression.deploy(
    grapeTokenAddress,
  )
  wineryProgressionAddress = WineryProgression_Deployed.address
  console.log('wineryProgressionAddress', wineryProgressionAddress)

  return {
    grapeTokenAddress,
    vintageWineAddress,
    vintnerAddress,
    upgradeAddress,
    cellarAddress,
    wineryProgressionAddress,
  }
}

main()
  .then((r: any) => {
    // console.log('deployed address:', r)
    return r
  })
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
