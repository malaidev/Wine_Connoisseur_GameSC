import { ethers, upgrades } from 'hardhat'
import { wineryAddress } from './address'

async function main(): Promise<string> {
  const [deployer] = await ethers.getSigners()
  if (deployer === undefined) throw new Error('Deployer is undefined.')

  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Winery = await ethers.getContractFactory('Winery')
  const WineryDeployed = await upgrades.upgradeProxy(wineryAddress, Winery)
  await WineryDeployed.deployed()

  return WineryDeployed.address
}

main()
  .then((r: string) => {
    console.log('deployed address:', r)
    return r
  })
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
