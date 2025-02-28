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
export const MOONRIVER_SAFE_ADDRESS = "0xfc88aa661C44B4EdE197644ba971764AC59AFa62";
export const POLYGON_SAFE_ADDRESS = "0x41186A5ff8F3b48f0FFc71A4cc958A997710DAeE";
export const AVALANCHE_SAFE_ADDRESS = "0xAE4D3a42E46399827bd094B4426e2f79Cca543CA";
export const BSC_SAFE_ADDRESS = "0x5a1DE6c40EF68A3F00ADe998E9e0D687E4419450";
export const BLAST_SAFE_ADDRESS = "0x0451ADD899D63Ba6A070333550137c3e9691De7d";
export const FANTOM_SAFE_ADDRESS = "0xf68b78CB64C49967719214aa029a29712ddd567f";
export const KAVA_SAFE_ADDRESS = "0x3A2761F421b7E3Fd18C1aD50c461b2DE2F77c367";
export const LINEA_SAFE_ADDRESS = "0x1c063276CF810957cf0665903FAd20d008f4b404";

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
                safeUrl: 'https://safe-transaction-mainnet.safe.global/',
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
                safeUrl: 'https://safe-transaction-optimism.safe.global',
                safeAddress: OPT_SAFE_ADDRESS
            }
        },
        'moonriver-mainnet': {
            eid: EndpointId.MOONRIVER_V2_MAINNET,
            url: process.env.MOONRIVER_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.MOONRIVER_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://gateway.multisig.moonbeam.network/api',
                safeAddress: MOONRIVER_SAFE_ADDRESS
            }
        },
        'polygon-mainnet': {
            eid: EndpointId.POLYGON_V2_MAINNET,
            url: process.env.POLYGON_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.POLYGON_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://safe-transaction-polygon.safe.global',
                safeAddress: POLYGON_SAFE_ADDRESS
            }
        },
        'avalanche-mainnet': {
            eid: EndpointId.AVALANCHE_V2_MAINNET,
            url: process.env.AVALANCHE_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.AVALANCHE_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://safe-transaction-avalanche.safe.global',
                safeAddress: AVALANCHE_SAFE_ADDRESS
            }
        },
        'bsc-mainnet': {
            eid: EndpointId.BSC_V2_MAINNET,
            url: process.env.BSC_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.BSC_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://safe-transaction-bsc.safe.global',
                safeAddress: BSC_SAFE_ADDRESS
            }
        },
        'blast-mainnet': {
            eid: EndpointId.BLAST_V2_MAINNET,
            url: process.env.BLAST_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.BLAST_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://safe-transaction-blast.safe.global',
                safeAddress: BLAST_SAFE_ADDRESS
            }
        },
        'fantom-mainnet': {
            eid: EndpointId.FANTOM_V2_MAINNET,
            url: process.env.FANTOM_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.FANTOM_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://safe-txservice.fantom.network/',
                safeAddress: FANTOM_SAFE_ADDRESS
            }
        },
        'kava-mainnet': {
            eid: EndpointId.KAVA_V2_MAINNET,
            url: process.env.KAVA_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.KAVA_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://gateway.safe.kava.io/api',
                safeAddress: KAVA_SAFE_ADDRESS
            }
        },
        'linea-mainnet': {
            eid: EndpointId.INK_V2_MAINNET,
            url: process.env.LINEA_RPC_URL || '',
            accounts,
            verify: {
                etherscan: {
                    apiKey: process.env.LINEA_ETHERSCAN_KEY || '',
                }
            },
            safeConfig: {
                safeUrl: 'https://safe-transaction-linea.safe.globall',
                safeAddress: LINEA_SAFE_ADDRESS
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
                safeUrl: 'https://transaction.safe.berachain.com/',
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
