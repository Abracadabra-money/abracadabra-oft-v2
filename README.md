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

# Deploy
```
bunx hardhat deploy --network <network-name> --tags <tag>
```

# Deploy for LayerZero
```
bunx hardhat lz:deploy --tags <deployement-name> --networks <network-name>
```
> beware that a default proxy admin deployment file `DefaultProxyAdmin` is deployed and is the proxy admin that should be used to upgrade the proxy. It should be renamed to a more meaningful name after the deployment. For example `BoundSpellOFT_ProxyAdmin` instead of `DefaultProxyAdmin`. The main reason is that a new OFT deployement will be overwrite this file.

# Verify
```
bunx hardhat etherscan-verify --network <network-name> --contract-name <contract-name>
```

# LayerZero Wiring
```
bunx hardhat lz:oapp:wire --oapp-config layerzero.config.ts [--safe (when owner is a safe)]
```

# Change OFT Ownership
```
bunx hardhat lz:ownable:transfer-ownership --oapp-config layerzero.config.ts
```

# Change Proxy Admin Ownership
```
cast --rpc-url <url> send <proxy admin address> "transferOwnership(address)" <new owner>
```

# Double check ownership
```
cast --rpc-url <url> call <layer zero endpoint> "delegates(address)(address)" <oft address>
cast --rpc-url <url> call <oft proxy address> "owner()(address)"
cast --rpc-url <url> call <proxy admin address> "owner()(address)"
```

# EndpointV2 addresses
https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts

# Bridging example
```
 bunx hardhat bridge \
  --token SPELL \
  --network ethereum-mainnet \
  --dst-chain arbitrum-mainnet \
  --to 0xfB3485c2e209A5cfBDC1447674256578f1A80eE3 \
  --amount 1
```