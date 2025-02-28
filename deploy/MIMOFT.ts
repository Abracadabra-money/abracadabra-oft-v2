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
        feeHandler: '0xA9Ea2B6F533db3679eEda162e23c1159439347bB'
    },
    'optimism-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0xB153FB3d196A8eB25522705560ac152eeEc57901', // MIM address
            '0x1E188DD74adf8CC95c98714407e88a4a99b759A5', // MIM Elevated Minter/Burner address
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: '0x6EfDD3F8D372740ceb43b3a12f5C56F60BE8f491'
    },
    'moonriver-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0x0caE51e1032e8461f4806e26332c030E34De3aDb', // MIM address
            '0x6e858b0DD9a9Dcdf710B28C236292E30ba079728', // MIM Elevated Minter/Burner address
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ethers.constants.AddressZero
    },
    'avalanche-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0x130966628846BFd36ff31a822705796e8cb8C18D', // MIM address
            '0x9BA780f8a517E2245892a388427973C8b7c3B769', // MIM Elevated Minter/Burner address
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ethers.constants.AddressZero
    },
    'bsc-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0xfE19F0B51438fd612f6FD59C1dbB3eA319f433Ba', // MIM address
            '0x79533F85479e04d2214305638B6586b724beC951', // MIM Elevated Minter/Burner address
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ethers.constants.AddressZero
    },
    'blast-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1', // MIM address
            '0x76DA31D7C9CbEAE102aff34D3398bC450c8374c1', // MIM Minter/Burner address (SAME as MIM address)
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ethers.constants.AddressZero
    },
    'kava-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0x471EE749bA270eb4c1165B5AD95E614947f6fCeb', // MIM address
            '0x471EE749bA270eb4c1165B5AD95E614947f6fCeb', // MIM Minter/Burner address (SAME as MIM address)
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ethers.constants.AddressZero
    },

    ////////////////////////////////////////////////////////////
    // TBD: Deprecated networks ?
    ////////////////////////////////////////////////////////////
    'polygon-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0x49a0400587A7F65072c87c4910449fDcC5c47242', // MIM address
            '0x8E7982492f6D330d0E1AAB9e110d7dfFc69C20fc', // MIM Elevated Minter/Burner address
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ethers.constants.AddressZero
    },
    'linea-mainnet': {
        contractName: 'AbraOFTUpgradeableExisting',
        args: (endpointAddress: string) => [
            '0xDD3B8084AF79B9BaE3D1b668c0De08CCC2C9429A', // MIM address
            '0xDD3B8084AF79B9BaE3D1b668c0De08CCC2C9429A', // MIM Minter/Burner address (SAME as MIM address)
            endpointAddress
        ],
        initializeArgs: (signer: string) => [signer],
        feeHandler: ethers.constants.AddressZero
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
