import { Contract, ethers } from 'ethers'
import { type DeployFunction } from 'hardhat-deploy/types'
import { getDeploymentAddressAndAbi } from '@layerzerolabs/lz-evm-sdk-v2'

const deploymentName = 'MIMOFT'
const salt = "mim-oft-1734968494"

const configurations = {
    'ethereum-mainnet': {
        contractName: 'AbraOFTAdapterUpgradeable',
        args: (endpointAddress: string) => ['0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3', endpointAddress], // MIM address
        initializeArgs: (signer: string) => [signer],
        feeHandler: '0xe4aec83Cba57E2B0b9ED8bc9801123F44f393037'
    },
    'bera-mainnet': {
        contractName: 'AbraOFTUpgradeable',
        args: (endpointAddress: string) => [endpointAddress],
        initializeArgs: (signer: string) => ['Magic Internet Money', 'MIM', signer],
        feeHandler: ethers.constants.AddressZero
    },
    'arbitrum-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A', // MIM address
            '0x26F20d6Dee51ad59AF339BEdF9f721113D01b6b3', // MIM Elevated Minter/Burner address
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: '0xE66BE95FE4E3889a66925d996AF3E4dC173754a2'
    },
    'optimism-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0xB153FB3d196A8eB25522705560ac152eeEc57901', // MIM address
            '0x1E188DD74adf8CC95c98714407e88a4a99b759A5', // MIM Elevated Minter/Burner address
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ''
    }
}

const deploy: DeployFunction = async (hre) => {
    const { deploy } = hre.deployments
    const signer = (await hre.ethers.getSigners())[0]
    console.log(`deploying ${deploymentName} on network: ${hre.network.name} with ${signer.address}`)

    const { address, abi } = getDeploymentAddressAndAbi(hre.network.name, 'EndpointV2')
    const endpointV2Deployment = new Contract(address, abi, signer)

    const config = configurations[hre.network.name as keyof typeof configurations]

    const deployment = await deploy(deploymentName, {
        deterministicDeployment: "0x" + Buffer.from(salt).toString('hex'),
        from: signer.address,
        args: config.args(endpointV2Deployment.address),
        log: true,
        waitConfirmations: 1,
        skipIfAlreadyDeployed: false,
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
    })

    if (config.feeHandler !== ethers.constants.AddressZero) {
        const oft = await hre.ethers.getContractAt('SenderWithFees', deployment.address)
        await (await oft.setFeeHandler(config.feeHandler)).wait()
    }
}

deploy.tags = [deploymentName]

export default deploy
