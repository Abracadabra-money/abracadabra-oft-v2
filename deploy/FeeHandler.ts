import { type DeployFunction } from 'hardhat-deploy/types'

const deploymentName = 'FeeHandler'
const contractName = 'FeeHandler'

const configurations = {
    'ethereum-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419", // ETH/USD feed
        "0x60C801e2dfd6298E6080214b3d680C8f8d698F48", // Treasury Yields
        0, // QuoteType.Oracle
        "0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B" // Ops 
    ],
    'arbitrum-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612", // ETH/USD feed
        "0x60C801e2dfd6298E6080214b3d680C8f8d698F48", // Treasury Yields
        0, // QuoteType.Oracle
        "0xA71A021EF66B03E45E0d85590432DFCfa1b7174C" // Ops 
    ],
    'bera-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x29d2fEC890B037B2d34f061F9a50f76F85ddBcAE", // BERA/USD feed
        "0x6AebC72aa1dfc63F4Ef473e4050cFa4895b1E07E", // Treasury Yields
        0, // QuoteType.Oracle
        "0xa4EF0376a91872B9c5d53D10410Bdf36e6Cf4e5E" // Ops 
    ],
    'optimism-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x13e3Ee699D1909E989722E753853AE30b17e08c5", // ETH/USD feed
        "0x60C801e2dfd6298E6080214b3d680C8f8d698F48", // Treasury Yields
        0, // QuoteType.Oracle
        "0xCbb86ffF0F8094C370cdDb76C7F270C832a8C7C0" // Ops 
    ]
}

const deploy: DeployFunction = async (hre) => {
    const { deploy } = hre.deployments
    const signer = (await hre.ethers.getSigners())[0]
    console.log(`deploying ${deploymentName} on network: ${hre.network.name} with ${signer.address}`)

    await deploy(deploymentName, {
        from: signer.address,
        args: configurations[hre.network.name as keyof typeof configurations],
        log: true,
        waitConfirmations: 1,
        skipIfAlreadyDeployed: false,
        contract: contractName
    })
}

deploy.tags = [deploymentName]

export default deploy
