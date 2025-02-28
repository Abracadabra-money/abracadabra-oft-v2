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
    ],
    'moonriver-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x3f8BFbDc1e79777511c00Ad8591cef888C2113C1", // MOVR/USD feed
        "0x2a8670Ea8b824E279b2429426EbD58142FB8fC29", // Treasury Yields
        0, // QuoteType.Oracle
        "0xfc88aa661C44B4EdE197644ba971764AC59AFa62" // Ops
    ],
    'polygon-mainnet': [
        0, // no fixed native fee, using an oracle
        "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0", // POL/USD feed
        "0x60C801e2dfd6298E6080214b3d680C8f8d698F48", // Treasury Yields
        0, // QuoteType.Oracle
        "0x41186A5ff8F3b48f0FFc71A4cc958A997710DAeE" // Ops
    ],
    'avalanche-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x0A77230d17318075983913bC2145DB16C7366156", // AVAX/USD feed
        "0x60C801e2dfd6298E6080214b3d680C8f8d698F48", // Treasury Yields
        0, // QuoteType.Oracle
        "0xAE4D3a42E46399827bd094B4426e2f79Cca543CA" // Ops
    ],
    'bsc-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE", // BNB/USD feed
        "0x60C801e2dfd6298E6080214b3d680C8f8d698F48", // Treasury Yields
        0, // QuoteType.Oracle
        "0x5a1DE6c40EF68A3F00ADe998E9e0D687E4419450" // Ops
    ],
    'blast-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x0af23B08bcd8AD35D1e8e8f2D2B779024Bd8D24A", // ETH/USD feed
        "0x4f31a6BB0091D87569c282531f5d0b52C36a2bc6", // Treasury Yields
        0, // QuoteType.Oracle
        "0x0451ADD899D63Ba6A070333550137c3e9691De7d" // Ops
    ],
    'kava-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x0000000000000000000000000000000000000000", // Price feed
        "0x0000000000000000000000000000000000000000", // Treasury Yields
        0, // QuoteType.Oracle
        "0x3A2761F421b7E3Fd18C1aD50c461b2DE2F77c367" // Ops
    ],
    'linea-mainnet': [
        0, // no fixed native fee, using an oracle
        "0x0000000000000000000000000000000000000000", // Price feed
        "0x0000000000000000000000000000000000000000", // Treasury Yields
        0, // QuoteType.Oracle
        "0x1c063276CF810957cf0665903FAd20d008f4b404" // Ops
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
