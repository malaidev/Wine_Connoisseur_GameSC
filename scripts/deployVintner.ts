import { ethers } from 'hardhat'
import { vintageWineAddress, oracleAddress, BASE_URI } from './address'

async function main(): Promise<string> {
  const [deployer] = await ethers.getSigners()
  if (deployer === undefined) throw new Error('Deployer is undefined.')

  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Vintner = await ethers.getContractFactory('Vintner')
  const Vintner_Deployed = await Vintner.deploy(
    vintageWineAddress,
    oracleAddress,
    BASE_URI,
  )

  return Vintner_Deployed.address
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
