import { Contract, ethers } from 'ethers'
import { DeployOptions, type DeployFunction } from 'hardhat-deploy/types'
import { getDeploymentAddressAndAbi } from '@layerzerolabs/lz-evm-sdk-v2'

const deploymentName = 'SpellOFT'
const salt = "spell-oft-1734060795"

const configurations = {
    'ethereum-mainnet': {
        contractName: 'AbraOFTAdapterUpgradeable',
        args: (endpointAddress: string) => ['0x090185f2135308BaD17527004364eBcC2D37e5F6', endpointAddress], // SPELL address
        initializeArgs: (signer: string) => [signer],
        feeHandler: '0xe4aec83Cba57E2B0b9ED8bc9801123F44f393037',
        useDeterministicDeployment: true
    },
    'arbitrum-mainnet': {
        contractName: 'AbraOFTUpgradeable',
        args: (endpointAddress: string) => [endpointAddress],
        initializeArgs: (signer: string) => ['SPELL', 'SPELL', signer],
        feeHandler: '0xE66BE95FE4E3889a66925d996AF3E4dC173754a2',
        useDeterministicDeployment: true
    },
    'bera-mainnet': {
        contractName: 'AbraOFTUpgradeable',
        args: (endpointAddress: string) => [endpointAddress],
        initializeArgs: (signer: string) => ['SPELL', 'SPELL', signer],
        feeHandler: ethers.constants.AddressZero,
        useDeterministicDeployment: true
    },
    'nibiru-mainnet': {
        contractName: 'AbraOFTUpgradeable',
        args: (endpointAddress: string) => [endpointAddress],
        initializeArgs: (signer: string) => ['SPELL', 'SPELL', signer],
        feeHandler: "0x279D54aDD72935d845074675De0dbcfdc66800a3",
        useDeterministicDeployment: true
    }
}

const deploy: DeployFunction = async (hre) => {
    const { deploy } = hre.deployments
    const signer = (await hre.ethers.getSigners())[0]
    console.log(`deploying ${deploymentName} on network: ${hre.network.name} with ${signer.address}`)

    const { address, abi } = getDeploymentAddressAndAbi(hre.network.name, 'EndpointV2')
    const endpointV2Deployment = await hre.ethers.getContractAt(abi, address)
    const config = configurations[hre.network.name as keyof typeof configurations]

    const deployOptions = {
        from: signer.address,
        args: config.args(endpointV2Deployment.address),
        log: true,
        waitConfirmations: 10,
        skipIfAlreadyDeployed: true,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            owner: signer.address,
            execute: {
                init: {
                    methodName: 'initialize',
                    args: config.initializeArgs(signer.address),
                },
            },
        },
        contract: config.contractName
    } as DeployOptions;
    
    if (config.useDeterministicDeployment) {
        console.log(`using deterministic deployment: ${salt}`)
        deployOptions.deterministicDeployment = "0x" + Buffer.from(salt).toString('hex');
    } else {
        console.log(`using non-deterministic deployment`)
    }
    
    const deployment = await deploy(deploymentName, deployOptions);

    if (config.feeHandler !== ethers.constants.AddressZero) {
        const oft = await hre.ethers.getContractAt('SenderWithFees', deployment.address)
        await (await oft.setFeeHandler(config.feeHandler)).wait()
    }
}

deploy.tags = [deploymentName]

export default deploy
