import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import inquirer from 'inquirer';
import { formatEther } from "ethers/lib/utils";
import { Options } from '@layerzerolabs/lz-v2-utilities';
import { addressToBytes32 } from '@layerzerolabs/lz-v2-utilities';

/**
  Usage:

  bunx hardhat bridge \
  --token SPELL \
  --network ethereum-mainnet \
  --dst-chain arbitrum-mainnet \
  --to 0xRecipientAddress \
  --amount 1.5
*/

// Token configurations
const TOKEN_CONFIGS = {
  SPELL: {
    symbol: 'SPELL',
    decimals: 18,
    networks: {
      'ethereum-mainnet': {
        type: 'adapter',
        contractName: 'AbraOFTAdapterUpgradeable',
        underlying: '0x090185f2135308BaD17527004364eBcC2D37e5F6',
        deploymentName: 'SpellOFT',
      },
      'arbitrum-mainnet': {
        type: 'oft',
        contractName: 'AbraOFTUpgradeable',
        deploymentName: 'SpellOFT',
      },
      'bera-mainnet': {
        type: 'oft',
        contractName: 'AbraOFTUpgradeable',
        deploymentName: 'SpellOFT',
      }
    }
  },
  BSPELL: {
    symbol: 'bSPELL',
    decimals: 18,
    networks: {
      'arbitrum-mainnet': {
        type: 'adapter',
        contractName: 'AbraOFTAdapterUpgradeable',
        underlying: '0x19595E8364644F038bDda1d099820654900c3042',
        deploymentName: 'BoundSpellOFT',
      },
      'ethereum-mainnet': {
        type: 'oft',
        contractName: 'AbraOFTUpgradeable',
        deploymentName: 'BoundSpellOFT',
      },
      'bera-mainnet': {
        type: 'oft',
        contractName: 'AbraOFTUpgradeable',
        deploymentName: 'BoundSpellOFT',
      }
    }
  },
  MIM: {
    symbol: 'MIM',
    decimals: 18,
    networks: {
      'ethereum-mainnet': {
        type: 'adapter',
        contractName: 'AbraOFTAdapterUpgradeable',
        underlying: '0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3',
        deploymentName: 'MIMOFT',
      },
      'bera-mainnet': {
        type: 'oft',
        contractName: 'AbraOFTUpgradeable',
        deploymentName: 'MIMOFT',
      },
      'nibiru-mainnet': {
        type: 'oft',
        contractName: 'AbraOFTUpgradeable',
        deploymentName: 'MIMOFT',
      }
    }
  }
};

task("bridge", "Bridge tokens from one chain to another")
  .addParam("token", "The token symbol to bridge (e.g., SPELL, bSPELL)")
  .addParam("dstChain", "The destination chain name (e.g., 'arbitrum-mainnet')")
  .addParam("to", "The recipient address")
  .addParam("amount", "Amount of tokens to send (in human readable format)")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { token: tokenSymbol, dstChain, to, amount } = taskArgs;

    // Get destination chain endpoint ID from config
    const dstEid = hre.config.networks[dstChain]?.eid;
    if (!dstEid) {
      throw new Error(`Destination chain ${dstChain} not configured or missing endpoint ID`);
    }

    const tokenConfig = TOKEN_CONFIGS[tokenSymbol as keyof typeof TOKEN_CONFIGS];
    if (!tokenConfig) throw new Error(`Unknown token symbol: ${tokenSymbol}`);

    const networkConfig = tokenConfig.networks[hre.network.name as keyof typeof tokenConfig.networks];
    if (!networkConfig) throw new Error(`Token ${tokenSymbol} not configured for network ${hre.network.name}`);

    const [sender] = await hre.ethers.getSigners();
    const oftContract = await hre.ethers.getContract(networkConfig.deploymentName);
    const underlyingToken = await hre.ethers.getContractAt("IERC20", oftContract.address);
    const decimals = tokenConfig.decimals;
    const amountInWei = hre.ethers.utils.parseUnits(amount, decimals);

    //console.log(`decimals: ${decimals}`);
    //console.log(`amount (wei): ${amountInWei}`);

    // Handle approvals for adapter
    if (networkConfig.type === 'adapter') {
      const adapterConfig = networkConfig as { type: 'adapter', underlying: string };
      const underlyingToken = await hre.ethers.getContractAt("IERC20", adapterConfig.underlying);
      const allowance = await underlyingToken.allowance(sender.address, oftContract.address);
      //console.log(`allowance: ${allowance}`);

      if (allowance.lt(amountInWei)) {
        console.log(`Approving ${tokenSymbol} tokens to OFT adapter...`);
        const approveTx = await underlyingToken.approve(oftContract.address, amountInWei);
        await approveTx.wait();
        console.log("Approval successful!");
      }
    }

    // Prepare send parameters with optimized gas settings
    const options = Options.newOptions().addExecutorLzReceiveOption(65000, 0).toBytes();
    const sendParam = {
      dstEid,
      to: addressToBytes32(to),
      amountLD: amountInWei,
      minAmountLD: amountInWei,
      extraOptions: options,
      composeMsg: "0x",
      oftCmd: "0x"
    };

    // Get quote for the bridge transaction
    const quote = await oftContract.quoteSend(sendParam, false);
    
    // Add 5% to the fee estimate
    const feeWithBuffer = quote.nativeFee.mul(105).div(100);

    // Show confirmation prompt with enhanced details
    const answers = await inquirer.prompt([{
      type: 'confirm',
      name: 'proceed',
      message: `
Bridge Details:
- From: ${hre.network.name} (EID: ${hre.config.networks[hre.network.name]?.eid})
- To: ${dstChain} (EID: ${dstEid})
- Token: ${tokenSymbol}
- Amount: ${amount} ${tokenSymbol}
- Recipient: ${to}
- Bridge Fee: ${formatEther(feeWithBuffer)} ${hre.network.name.includes('ethereum') ? 'ETH' : 'native token'} (includes 5% buffer)
- OFT Contract: ${oftContract.address}

Do you want to proceed?`,
      default: false
    }]);

    if (!answers.proceed) {
      console.log("Bridge operation cancelled");
      return;
    }

    try {
      const tx = await oftContract.send(
        sendParam,
        { nativeFee: feeWithBuffer, lzTokenFee: 0 },
        sender.address,
        { value: feeWithBuffer }
      );
      await tx.wait();

      console.log(`Bridge transaction successful!`);
      console.log(`Transaction: https://layerzeroscan.com/tx/${tx.hash}`);
      console.log(`Native fee paid: ${formatEther(feeWithBuffer)}`);
    } catch (error) {
      console.error("Error bridging tokens:", error);
      throw error;
    }
  });