import { ethers } from 'hardhat'
import { grapeTokenAddress, vintageWineAddress, BASE_URI } from './address'

async function main(): Promise<string> {
  const [deployer] = await ethers.getSigners()
  if (deployer === undefined) throw new Error('Deployer is undefined.')

  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Upgrade = await ethers.getContractFactory('Upgrade')
  const Upgrade_Deployed = await Upgrade.deploy(
    vintageWineAddress,
    grapeTokenAddress,
    BASE_URI,
  )

  return Upgrade_Deployed.address
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
