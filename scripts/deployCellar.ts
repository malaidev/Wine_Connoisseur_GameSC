import { ethers } from 'hardhat'
import { vintageWineAddress } from './address'

async function main(): Promise<string> {
  const [deployer] = await ethers.getSigners()
  if (deployer === undefined) throw new Error('Deployer is undefined.')

  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Cellar = await ethers.getContractFactory('Cellar')
  const Cellar_Deployed = await Cellar.deploy(vintageWineAddress)

  return Cellar_Deployed.address
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
