// Get the environment configuration from .env file
//
// To make use of automatic environment setup:
// - Duplicate .env.example file and name it .env
// - Fill in the environment variables
import "dotenv-defaults/config"

import '@openzeppelin/hardhat-upgrades'
import 'hardhat-deploy'
import '@nomiclabs/hardhat-waffle'
import 'hardhat-deploy-ethers'
import 'hardhat-contract-sizer'
import '@nomiclabs/hardhat-ethers'
import '@layerzerolabs/toolbox-hardhat'
import './tasks'

import { HardhatUserConfig, HttpNetworkAccountsUserConfig } from 'hardhat/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

// Set your preferred authentication method
//
// If you prefer using a mnemonic, set a MNEMONIC environment variable
// to a valid mnemonic
const MNEMONIC = process.env.MNEMONIC

// If you prefer to be authenticated using a private key, set a PRIVATE_KEY environment variable
const PRIVATE_KEY = process.env.PRIVATE_KEY

export const ETH_SAFE_ADDRESS = "0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B";
export const ARB_SAFE_ADDRESS = "0xA71A021EF66B03E45E0d85590432DFCfa1b7174C";
export const BERA_SAFE_ADDRESS = "0xa4EF0376a91872B9c5d53D10410Bdf36e6Cf4e5E";
export const OPT_SAFE_ADDRESS = "0xCbb86ffF0F8094C370cdDb76C7F270C832a8C7C0";
export const NIBI_SAFE_ADDRESS = "0x282dF9f8A9b1F23aEa9050A4fdEb5eEe29c2F540";
export const HYPER_SAFE_ADDRESS = "0xD402DA007d49040D8639A957bB1f9921bAC5816d";

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
        ? [PRIVATE_KEY]
        : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}
const config: HardhatUserConfig = {
    paths: {
        cache: 'cache/hardhat',
    },
    solidity: {
        compilers: [
            {
                version: '0.8.22',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        'ethereum-mainnet': {
            eid: EndpointId.ETHEREUM_V2_MAINNET,
            url: process.env.MAINNET_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.MAINNET_ETHERSCAN_KEY || '',
                },
            },
            safeConfig: {
                safeUrl: 'https://safe-transaction-mainnet.safe.global',
                safeAddress: ETH_SAFE_ADDRESS
            }
        },
        'arbitrum-mainnet': {
            eid: EndpointId.ARBITRUM_V2_MAINNET,
            url: process.env.ARBITRUM_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.ARBITRUM_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://safe-transaction-arbitrum.safe.global',
                safeAddress: ARB_SAFE_ADDRESS
            }
        },
        'optimism-mainnet': {
            eid: EndpointId.OPTIMISM_V2_MAINNET,
            url: process.env.OPTIMISM_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.OPTIMISM_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'TODO',
                safeAddress: OPT_SAFE_ADDRESS
            }
        },
        'bera-mainnet': {
            eid: EndpointId.BERA_V2_MAINNET,
            url: process.env.BERA_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiUrl: 'https://api.berascan.com',
                    apiKey: process.env.BERA_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://transaction.safe.berachain.com',
                safeAddress: BERA_SAFE_ADDRESS,
                contractNetworks: {
                    // @ts-ignore
                    '80094': {
                        multiSendAddress: '0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526',
                        multiSendCallOnlyAddress: '0x9641d764fc13c8B624c04430C7356C1C7C8102e2',
                    },
                },
            },
        },
        "nibiru-mainnet": {
            eid: EndpointId.NIBIRU_V2_MAINNET,
            url: process.env.NIBIRU_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiUrl: 'https://api.routescan.io/v2/network/mainnet/evm/6900/etherscan',
                    apiKey: 'verifyContract',
                }
            },
            safeConfig: {
                safeUrl: 'https://transaction.safe.nibiru.fi',
                safeAddress: NIBI_SAFE_ADDRESS,
                contractNetworks: {
                    // @ts-ignore
                    '6900': {
                        multiSendAddress: '0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526',
                        multiSendCallOnlyAddress: '0x9641d764fc13c8B624c04430C7356C1C7C8102e2',
                    },
                },
            },
        },
        "hyperliquid-mainnet": {
            eid: EndpointId.HYPERLIQUID_V2_MAINNET,
            url: process.env.HYPERLIQUID_RPC_URL || '',
            accounts,
            safeConfig: {
                safeUrl: 'https://safe-transaction-hyperevm.onchainden.com',
                safeAddress: HYPER_SAFE_ADDRESS,
                contractNetworks: {
                    // @ts-ignore
                    '999': {
                        multiSendAddress: '0x998739BFdAAdde7C933B942a68053933098f9EDa',
                        multiSendCallOnlyAddress: '0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B',
                    },
                },
            },
        },
        hardhat: {
            // Need this for testing because TestHelperOz5.sol is exceeding the compiled contract size limit
            allowUnlimitedContractSize: true,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0, // wallet address of index[0], of the mnemonic in .env
        },
    },
    layerZero: {
        // You can tell hardhat toolbox not to include any deployments (hover over the property name to see full docs)
        deploymentSourcePackages: [],
        // You can tell hardhat not to include any artifacts either
        // artifactSourcePackages: [],
    },
}

export default config
