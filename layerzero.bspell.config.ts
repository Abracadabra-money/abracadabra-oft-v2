import { ExecutorOptionType } from "@layerzerolabs/lz-v2-utilities";
import { OAppEdgeConfig, OAppEnforcedOption, OmniEdgeHardhat, OmniPointHardhat } from "@layerzerolabs/toolbox-hardhat";
import { EndpointId } from "@layerzerolabs/lz-definitions";
import { generateConnectionsConfig } from "@layerzerolabs/metadata-tools";
import { ETH_SAFE_ADDRESS, ARB_SAFE_ADDRESS, BERA_SAFE_ADDRESS } from "./hardhat.config";

const ethereumContract: OmniPointHardhat = {
    eid: EndpointId.ETHEREUM_V2_MAINNET,
    contractName: 'BoundSpellOFT',
}

const arbitrumContract: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_MAINNET,
    contractName: 'BoundSpellOFT',
}

const beraContract: OmniPointHardhat = {
    eid: EndpointId.BERA_V2_MAINNET,
    contractName: 'BoundSpellOFT',
}

const EVM_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 80000,
        value: 0,
    },
    {
        msgType: 2,
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 80000,
        value: 0,
    },
    {
        msgType: 2,
        optionType: ExecutorOptionType.COMPOSE,
        index: 0,
        gas: 80000,
        value: 0,
    },
];

// https://layerzeroscan.com/tools/defaults
export default async function () {
    // [srcContract, dstContract, [requiredDVNs, [optionalDVNs, threshold]], [srcToDstConfirmations, dstToSrcConfirmations]], [enforcedOptionsSrcToDst, enforcedOptionsDstToSrc]
    const connections = await generateConnectionsConfig([
        // Mainnet <> Arbitrum
        [ethereumContract, arbitrumContract, [['LayerZero Labs', 'MIM'], []], [15, 20], [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS]],
        // Mainnet <> Bera
        [ethereumContract, beraContract, [['LayerZero Labs', 'MIM'], []], [15, 20], [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS]],
        // Arbitrum <> Bera
        [arbitrumContract, beraContract, [['LayerZero Labs', 'MIM'], []], [20, 20], [EVM_ENFORCED_OPTIONS, EVM_ENFORCED_OPTIONS]],
    ]) as OmniEdgeHardhat<OAppEdgeConfig>[];

    // Prints generated connections
    //console.log(JSON.stringify(connections, (_, value) => typeof value === 'bigint' ? value.toString() : value, 2));

    return {
        contracts: [
            {
                contract: ethereumContract,
                config: {
                    owner: ETH_SAFE_ADDRESS,
                    delegate: ETH_SAFE_ADDRESS,
                },
            },
            {
                contract: arbitrumContract,
                config: {
                    owner: ARB_SAFE_ADDRESS,
                    delegate: ARB_SAFE_ADDRESS,
                },
            },
            {
                contract: beraContract,
                config: {
                    owner: BERA_SAFE_ADDRESS,
                    delegate: BERA_SAFE_ADDRESS,
                },
            }
        ],
        connections
    }
}