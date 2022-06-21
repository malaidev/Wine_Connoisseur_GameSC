import { ethers, upgrades } from 'hardhat'
import {
  vintnerAddress,
  upgradeAddress,
  vintageWineAddress,
  grapeTokenAddress,
  cellarAddress,
  wineryProgressionAddress,
} from './address'

async function main(): Promise<string> {
  const [deployer] = await ethers.getSigners()
  if (deployer === undefined) throw new Error('Deployer is undefined.')

  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Winery = await ethers.getContractFactory('Winery')
  const WineryDeployed = await upgrades.deployProxy(
    Winery,
    // initializer: 'initialize',
    [
      vintnerAddress,
      upgradeAddress,
      vintageWineAddress,
      grapeTokenAddress,
      cellarAddress,
      wineryProgressionAddress,
    ],
  )
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

// //available functions
// async function main() {
//   const [deployer] = await ethers.getSigners()
//   if (deployer === undefined) throw new Error('Deployer is undefined.')
//   console.log('Deploying contracts with the account:', deployer.address)

//   console.log('Account balance:', (await deployer.getBalance()).toString())
//  const Token = await ethers.getContractFactory("LIFEGAMES");

//  console.log("Deploying upgradeable contract of Token...");

//  const TokenDeployed = await upgrades.deployProxy(Token, {
//   initializer: "initialize",
//  });
//  await TokenDeployed.deployed();

//  console.log("Contract deployed to:", TokenDeployed.address);
// }
