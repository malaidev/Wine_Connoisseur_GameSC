import {ethers} from 'hardhat'

async function main(): Promise<string> {
    const [deployer] = await ethers.getSigners()
    if (deployer === undefined) throw new Error('Deployer is undefined.')
    
    console.log('Account balance:', (await deployer.getBalance()).toString())

    const Winery = await ethers.getContractFactory('Winery')
    const Winery_Deployed = await Winery.deploy()

    return Winery_Deployed.address;
}

main()
    .then((r: string) => {
        console.log("deployed address:", r);
        return r;
    })
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
