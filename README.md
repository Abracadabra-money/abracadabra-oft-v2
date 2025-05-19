# Requirements

- Bun
- Foundry (for testing)

# Setup

```
bun install
```

# Compile

```
bunx hardhat compile
```

# Test

```
forge test
```

# How to deploy MIM OFT

## 1. Deploy FeeHandler

Edit `deploy/FeeHandler.ts` and update `configurations` with the right values for the network you are deploying to.

```
bunx hardhat deploy --network <network-name> --tags FeeHandler
```

## 2. Deploy MIMOFT

> be sure to update the owner of the MIMOFT to the multisig address

```
bunx hardhat lz:deploy --tags MIMOFT --networks <network-name>
```

> Rename the `DefaultProxyAdmin` file to `MIMOFT_ProxyAdmin`

## 3. Verify

```
bunx hardhat etherscan-verify --network <network-name> --contract-name MIMOFT_Implementation
bunx hardhat etherscan-verify --network <network-name> --contract-name MIMOFT_ProxyAdmin
bunx hardhat etherscan-verify --network <network-name> --contract-name MIMOFT_FeeHandler
```

## 4. Change Endpoint Delegate To Owner
```
cast --rpc-url <url> send <layer zero endpoint> "setDelegate(address)" <owner address>
```

## 5. Change OFT Ownership

```
bunx hardhat lz:ownable:transfer-ownership --oapp-config layerzero.mim.config.ts
```

## 6. Change Proxy Admin Ownership
```
cast --rpc-url <url> send <MIMOFT_ProxyAdmin address> "transferOwnership(address)" <safe address>
```

## 7. Double check ownership

Make sure the owner for all the contracts is the safe address.

```
cast --rpc-url <url> call <layer zero endpoint> "delegates(address)(address)" <oft address>
cast --rpc-url <url> call <oft proxy address> "owner()(address)"
cast --rpc-url <url> call <proxy admin address> "owner()(address)"
```

## 8. Review

Ask the team to review the deployment.

## 9. LayerZero Wiring

```
bunx hardhat lz:oapp:wire --oapp-config layerzero.mim.config.ts [--safe (when owner is a safe)]
```

# Verify on Hyperliquid
```
bunx hardhat --network hyperliquid-mainnet sourcify --endpoint "https://sourcify.parsec.finance"
```

# EndpointV2 addresses

https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts

# Bridging example

## MIM

```
 bunx hardhat bridge \
  --token MIM \
  --network ethereum-mainnet \
  --dst-chain arbitrum-mainnet \
  --to 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
  --amount 1
```

## SPELL

```
bunx hardhat bridge \
  --token SPELL \
  --network ethereum-mainnet \
  --dst-chain arbitrum-mainnet \
  --to 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
  --amount 1
```
