// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { IOFT, SendParam, OFTReceipt, OFTLimit, OFTFeeDetail } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { Test } from "forge-std/Test.sol";
import { IOAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import { ExecutorConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import "forge-std/Test.sol";
import { AddressCast } from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import { ExecutorConfig } from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import { AbraOFTUpgradeableExisting } from "contracts/AbraOFTUpgradeableExisting.sol";
import { TransparentUpgradeableProxy } from "hardhat-deploy/solc_0.8/openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { Origin } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

library TestHelper {
    function deployContractAndProxy(
        address _proxyAdmin,
        bytes memory _oappBytecode,
        bytes memory _constructorArgs,
        bytes memory _initializeArgs
    ) internal returns (address addr) {
        bytes memory bytecode = bytes.concat(abi.encodePacked(_oappBytecode), _constructorArgs);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        return address(new TransparentUpgradeableProxy(addr, _proxyAdmin, _initializeArgs));
    }
}

struct UlnConfig {
    uint64 confirmations;
    // we store the length of required DVNs and optional DVNs instead of using DVN.length directly to save gas
    uint8 requiredDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
    uint8 optionalDVNCount; // 0 indicate DEFAULT, NIL_DVN_COUNT indicate NONE (to override the value of default)
    uint8 optionalDVNThreshold; // (0, optionalDVNCount]
    address[] requiredDVNs; // no duplicates. sorted an an ascending order. allowed overlap with optionalDVNs
    address[] optionalDVNs; // no duplicates. sorted an an ascending order. allowed overlap with requiredDVNs
}

interface IDVN {
    function getSigners() external view returns (address[] memory);
}

interface IReceiveLib {
    function executorConfigs(address _oapp, uint32 _eid) external returns (ExecutorConfig memory);
}

interface ITransparentUpgradeableProxy {
    function admin() external view returns (address);

    function implementation() external view returns (address);

    function changeAdmin(address) external;

    function upgradeTo(address) external;

    function upgradeToAndCall(address, bytes memory) external payable;
}

interface ILayerZeroEndpointDelegateable {
    function delegates(address) external returns (address);
}

interface IERC20Blockable is IERC20Metadata {
    function isBlocked(address user) external returns (bool);

    function addToBlockedList(address _user) external;

    function removeFromBlockedList(address _user) external;
}

interface TetherMintable {
    function issue(uint256 _amount) external;
}

interface USDTLegacyTransferrable {
    function transfer(address _to, uint256 _value) external;

    function addBlackList(address _evilUser) external;

    function isBlackListed(address _user) external returns (bool);
}

interface IOFTComplete is IOFT {
    function decimalConversionRate() external view returns (uint256);

    function initialize(string memory, string memory, address _delegate) external;

    function msgInspector() external returns (address);

    function balanceOf(address) external returns (uint256);

    function peers(uint32) external returns (bytes32);

    function decimals() external returns (uint8);
}

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}

contract AbraForkTestBase is Test {
    uint256 constant ETH_CHAIN_ID = 1;
    uint256 constant INK_CHAIN_ID = 57073;
    uint256 constant BERA_CHAIN_ID = 80094;
    uint256 constant ARB_CHAIN_ID = 42161;

    uint32 constant ARB_EID = 30110;

    address constant ENDPOINT_BERA = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;

    address constant MIM_OFT_BERA = 0x5B82028cfc477C4E7ddA7FF33d59A23FA7Be002a;
    address constant SPELLV2_OFT_BERA = 0x22581e7E93d66977849D094006fC2cF3aB9C8FfA;
    address constant BSPELL_OFT_BERA = 0xC13e0EF9ED2526d7BD03d81DF72284F489962E45;

    address constant MIM_OFT_ETH = 0xE5169F892000fC3BEd5660f62C67FAEE7F97718B;
    address constant SPELLV2_OFT_ETH = 0x48c95D958fd0Ef6ecF7fEb8d592c4D5a70f1AfBE;
    address constant BSPELL_OFT_ETH = 0x3577D33FE93BEFDfAB0Fce855784549D6b7eAe43;

    address constant SPELLV2_OFT_ARB = 0x34FbFB3e95011956aBAD82796f466bA88895f214;
    address constant BSPELL_OFT_ARB = 0x025B71Fa801f51CfB9299886De188853b4161C21;

    address constant ENDPOINT_ARB = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant SEND_LIB_ARB = 0x975bcD720be66659e3EB3C0e4F1866a3020E493A; // SendUln302
    address constant RECEIVE_LIB_ARB = 0x7B9E184e07a6EE1aC23eAe0fe8D6Be2f663f05e6; // ReceiveUln302
    uint64 constant ARB_CONFIRMATIONS = 20;
    address constant SAFE_ARB = 0xA71A021EF66B03E45E0d85590432DFCfa1b7174C;

    address constant SAFE_BERA = 0xa4EF0376a91872B9c5d53D10410Bdf36e6Cf4e5E;
    address constant SEND_LIB_BERA = 0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7; // SendUln302
    address constant RECEIVE_LIB_BERA = 0xe1844c5D63a9543023008D332Bd3d2e6f1FE1043; // ReceiveUln302
    uint32 constant BERA_EID = 30362;
    address constant EXECUTOR_BERA = 0x4208D6E27538189bB48E603D6123A94b8Abe0A0b;
    address constant MIM_DVN_BERA = 0x73DDc92E39aEdA95FEb8D3E0008016d9F1268c76;
    address constant LZ_DVN_BERA = 0x282b3386571f7f794450d5789911a9804FA346b4;
    address constant NETHERMIND_DVN_BERA = 0xDd7B5E1dB4AaFd5C8EC3b764eFB8ed265Aa5445B;
    uint64 constant BERA_CONFIRMATIONS = 20;

    address constant ENDPOINT_ETH = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant OFT_ETH = 0x6C96dE32CEa08842dcc4058c14d3aaAD7Fa41dee;
    address constant USDT0_ETH = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDT_MINTER = 0xC6CDE7C39eB2f0F0095F41570af89eFC2C1Ea828;
    address constant SAFE_ETH = 0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B;
    uint32 constant ETH_EID = 30101;
    uint64 constant ETH_CONFIRMATIONS = 15;
    address constant SEND_LIB_ETH = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1; // SendUln302
    address constant RECEIVE_LIB_ETH = 0xc02Ab410f0734EFa3F14628780e6e695156024C2; // ReceiveUln302

    address constant SEND_LIB_ARBITRUM = 0x975bcD720be66659e3EB3C0e4F1866a3020E493A;

    address constant LZ_DVN_ARB = 0x2f55C492897526677C5B68fb199ea31E2c126416;
    address constant MIM_DVN_ARB = 0x9E930731cb4A6bf7eCc11F695A295c60bDd212eB;

    address constant LZ_DVN_ETH = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
    address constant MIM_DVN_ETH = 0x0Ae4e6a9a8B01EE22c6A49aF22B674A4E033A23D;

    // This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1
    bytes32 constant PROXY_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address alice = makeAddr("alice");

    ILayerZeroEndpointV2 endpoint;
    IOFTComplete mimOft;
    IOFTComplete spellV2Oft;
    IOFTComplete bSpellOft;

    uint32 sendingSrcEid;
    uint32 sendingDstEid;
    address safe;
    address usdt0Dvn;

    address mimOftPeer;
    address spellV2OftPeer;
    address bSpellOftPeer;

    address sendLib;
    address receiveLib;

    function setUp() public virtual {
        if (block.chainid == ETH_CHAIN_ID) {
            endpoint = ILayerZeroEndpointV2(ENDPOINT_ETH);
            mimOft = IOFTComplete(MIM_OFT_ETH);
            spellV2Oft = IOFTComplete(SPELLV2_OFT_ETH);
            bSpellOft = IOFTComplete(BSPELL_OFT_ETH);
            sendLib = SEND_LIB_ETH;
            sendingSrcEid = BERA_EID;
            mimOftPeer = MIM_OFT_BERA;
            spellV2OftPeer = SPELLV2_OFT_BERA;
            bSpellOftPeer = BSPELL_OFT_BERA;
            receiveLib = RECEIVE_LIB_ETH;
            safe = SAFE_ETH;
        } else if (block.chainid == ARB_CHAIN_ID) {
            endpoint = ILayerZeroEndpointV2(ENDPOINT_ARB);
            spellV2Oft = IOFTComplete(SPELLV2_OFT_ARB);
            bSpellOft = IOFTComplete(BSPELL_OFT_ARB);
            sendLib = SEND_LIB_ARB;
            receiveLib = RECEIVE_LIB_ARB;
            safe = SAFE_ARB;
            sendingSrcEid = ETH_EID;
            spellV2OftPeer = SPELLV2_OFT_ETH;
            bSpellOftPeer = BSPELL_OFT_ETH;
        } else if (block.chainid == BERA_CHAIN_ID) {
            endpoint = ILayerZeroEndpointV2(ENDPOINT_BERA);
            mimOft = IOFTComplete(MIM_OFT_BERA);
            spellV2Oft = IOFTComplete(SPELLV2_OFT_BERA);
            bSpellOft = IOFTComplete(BSPELL_OFT_BERA);
            mimOftPeer = MIM_OFT_ETH;
            spellV2OftPeer = SPELLV2_OFT_ETH;
            bSpellOftPeer = BSPELL_OFT_ETH;
            sendingSrcEid = ETH_EID;
            sendingDstEid = ETH_EID;
            safe = SAFE_BERA;
            sendLib = SEND_LIB_BERA;
            receiveLib = RECEIVE_LIB_BERA;
        } else {
            revert("unsupported chain!");
        }
    }

    function test_oft_decimals() public {
        if (block.chainid != ARB_CHAIN_ID) {
            assertEq(mimOft.sharedDecimals(), 6);
            if (block.chainid != ETH_CHAIN_ID) {
                // Adapter contract on ETH
                assertEq(mimOft.decimals(), 18);
            }
            assertEq(mimOft.decimalConversionRate(), 1e12);
        }

        assertEq(spellV2Oft.sharedDecimals(), 6);
        if (block.chainid != ETH_CHAIN_ID) {
            // Adapter contract on ETH
            assertEq(spellV2Oft.decimals(), 18);
        }
        assertEq(spellV2Oft.decimalConversionRate(), 1e12);

        assertEq(bSpellOft.sharedDecimals(), 6);
        if (block.chainid != ARB_CHAIN_ID) {
            // Adapter contract on ARB
            assertEq(bSpellOft.decimals(), 18);
        }
        assertEq(bSpellOft.decimalConversionRate(), 1e12);
    }

    function test_oft_send_mim() public {
        if (block.chainid == ARB_CHAIN_ID) return;
        if (block.chainid == ETH_CHAIN_ID) {
            assertEq(IERC20(mimOft.token()).balanceOf(alice), 0);
        } else {
            assertEq(mimOft.balanceOf(alice), 0); // alice address balance is 0 before
        }

        uint256 mimDecimalConversionRate = mimOft.decimalConversionRate();
        uint256 sharedDecimals = mimOft.sharedDecimals();
        uint256 localDecimals;
        if (block.chainid == ETH_CHAIN_ID) {
            localDecimals = IERC20Decimals(mimOft.token()).decimals();
        } else {
            localDecimals = mimOft.decimals();
        }
        uint256 tenTokensSD = 10 * (10 ** localDecimals / mimDecimalConversionRate);

        assertEq(10 * 10 ** sharedDecimals, tenTokensSD);

        vm.startPrank(address(endpoint));
        (bytes memory message, ) = OFTMsgCodec.encode(
            OFTComposeMsgCodec.addressToBytes32(address(alice)),
            uint64(tenTokensSD),
            ""
        );
        IOAppReceiver(address(mimOft)).lzReceive(
            Origin(sendingSrcEid, OFTComposeMsgCodec.addressToBytes32(mimOftPeer), 0),
            0,
            message,
            address(this),
            ""
        );

        if (block.chainid == ETH_CHAIN_ID) {
            assertEq(IERC20(mimOft.token()).balanceOf(alice), 10 * 10 ** localDecimals); // alice received the tokens
        } else {
            assertEq(mimOft.balanceOf(alice), 10 * 10 ** localDecimals); // alice received the tokens
        }

        vm.stopPrank();
    }

    function test_oft_send_bspell() public {
        if (block.chainid == ARB_CHAIN_ID) {
            assertEq(IERC20(bSpellOft.token()).balanceOf(alice), 0);
        } else {
            assertEq(bSpellOft.balanceOf(alice), 0); // alice address balance is 0 before
        }

        uint256 mimDecimalConversionRate = bSpellOft.decimalConversionRate();
        uint256 sharedDecimals = bSpellOft.sharedDecimals();
        uint256 localDecimals;

        if (block.chainid == ARB_CHAIN_ID) {
            localDecimals = IERC20Decimals(bSpellOft.token()).decimals();
        } else {
            localDecimals = bSpellOft.decimals();
        }

        uint256 tenTokensSD = 10 * (10 ** localDecimals / mimDecimalConversionRate);

        assertEq(10 * 10 ** sharedDecimals, tenTokensSD);

        vm.startPrank(address(endpoint));
        (bytes memory message, ) = OFTMsgCodec.encode(
            OFTComposeMsgCodec.addressToBytes32(address(alice)),
            uint64(tenTokensSD),
            ""
        );
        IOAppReceiver(address(bSpellOft)).lzReceive(
            Origin(sendingSrcEid, OFTComposeMsgCodec.addressToBytes32(bSpellOftPeer), 0),
            0,
            message,
            address(this),
            ""
        );

        if (block.chainid == ARB_CHAIN_ID) {
            assertEq(IERC20(bSpellOft.token()).balanceOf(alice), 10 * 10 ** localDecimals); // alice received the tokens
        } else {
            assertEq(bSpellOft.balanceOf(alice), 10 * 10 ** localDecimals); // alice received the tokens
        }

        vm.stopPrank();
    }

    function test_oft_send_spellv2() public {
        if (block.chainid == ETH_CHAIN_ID) {
            assertEq(IERC20(spellV2Oft.token()).balanceOf(alice), 0);
        } else {
            assertEq(spellV2Oft.balanceOf(alice), 0); // alice address balance is 0 before
        }

        uint256 mimDecimalConversionRate = spellV2Oft.decimalConversionRate();
        uint256 sharedDecimals = spellV2Oft.sharedDecimals();
        uint256 localDecimals;
        if (block.chainid == ETH_CHAIN_ID) {
            localDecimals = IERC20Decimals(spellV2Oft.token()).decimals();
        } else {
            localDecimals = spellV2Oft.decimals();
        }
        uint256 tenTokensSD = 10 * (10 ** localDecimals / mimDecimalConversionRate);

        assertEq(10 * 10 ** sharedDecimals, tenTokensSD);

        vm.startPrank(address(endpoint));
        (bytes memory message, ) = OFTMsgCodec.encode(
            OFTComposeMsgCodec.addressToBytes32(address(alice)),
            uint64(tenTokensSD),
            ""
        );
        IOAppReceiver(address(spellV2Oft)).lzReceive(
            Origin(sendingSrcEid, OFTComposeMsgCodec.addressToBytes32(spellV2OftPeer), 0),
            0,
            message,
            address(this),
            ""
        );

        if (block.chainid == ETH_CHAIN_ID) {
            assertEq(IERC20(spellV2Oft.token()).balanceOf(alice), 10 * 10 ** localDecimals); // alice received the tokens
        } else {
            assertEq(spellV2Oft.balanceOf(alice), 10 * 10 ** localDecimals); // alice received the tokens
        }

        vm.stopPrank();
    }

    function test_cannot_be_re_initialized() public {
        if (block.chainid != ARB_CHAIN_ID) {
            vm.expectRevert();
            mimOft.initialize("", "", address(0));
        }

        vm.expectRevert();
        spellV2Oft.initialize("", "", address(0));

        vm.expectRevert();
        bSpellOft.initialize("", "", address(0));
    }

    function test_initializers_are_disabled_on_implementation() public {
        if (block.chainid != ARB_CHAIN_ID) {
            address proxyAdmin = address(uint160(uint256(vm.load(address(mimOft), PROXY_ADMIN_SLOT))));

            vm.prank(proxyAdmin);
            IOFTComplete implementationMim = IOFTComplete(
                ITransparentUpgradeableProxy(address(mimOft)).implementation()
            );

            vm.expectRevert();
            implementationMim.initialize("XX", "XX", alice);
        }

        address proxyAdminSpell = address(uint160(uint256(vm.load(address(spellV2Oft), PROXY_ADMIN_SLOT))));

        vm.prank(proxyAdminSpell);
        IOFTComplete implementationSpell = IOFTComplete(
            ITransparentUpgradeableProxy(address(spellV2Oft)).implementation()
        );

        vm.expectRevert();
        implementationSpell.initialize("XX", "XX", alice);

        address proxyAdminBSpell = address(uint160(uint256(vm.load(address(bSpellOft), PROXY_ADMIN_SLOT))));

        vm.prank(proxyAdminBSpell);
        IOFTComplete implementationBSpell = IOFTComplete(
            ITransparentUpgradeableProxy(address(bSpellOft)).implementation()
        );

        vm.expectRevert();
        implementationBSpell.initialize("XX", "XX", alice);
    }

    function test_quote_oft_mim() public {
        if (block.chainid == ARB_CHAIN_ID) return;
        uint256 mimDecimalConversionRate = mimOft.decimalConversionRate();
        uint256 sharedDecimals = mimOft.sharedDecimals();
        uint256 localDecimals;
        if (block.chainid == ETH_CHAIN_ID) {
            localDecimals = IERC20Decimals(mimOft.token()).decimals();
        } else {
            localDecimals = mimOft.decimals();
        }
        uint256 tenTokensSD = 10 * (10 ** localDecimals / mimDecimalConversionRate);

        assertEq(10 * 10 ** sharedDecimals, tenTokensSD);

        SendParam memory sendParam = SendParam({
            dstEid: sendingDstEid,
            to: bytes32(uint256(uint160(alice))),
            amountLD: 10 * 10 ** localDecimals,
            minAmountLD: 10 * 10 ** localDecimals,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        (OFTLimit memory limit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory receipt) = mimOft.quoteOFT(
            sendParam
        );

        assertEq(limit.minAmountLD, 0);
        assertEq(limit.maxAmountLD, type(uint64).max);

        assertEq(oftFeeDetails.length, 0);

        assertEq(receipt.amountSentLD, 10 * 10 ** localDecimals);
        assertEq(receipt.amountReceivedLD, 10 * 10 ** localDecimals);
    }

    function test_quote_oft_spellV2() public {
        uint256 mimDecimalConversionRate = spellV2Oft.decimalConversionRate();
        uint256 sharedDecimals = spellV2Oft.sharedDecimals();
        uint256 localDecimals;
        if (block.chainid == ETH_CHAIN_ID) {
            localDecimals = IERC20Decimals(spellV2Oft.token()).decimals();
        } else {
            localDecimals = spellV2Oft.decimals();
        }
        uint256 tenTokensSD = 10 * (10 ** localDecimals / mimDecimalConversionRate);

        assertEq(10 * 10 ** sharedDecimals, tenTokensSD);

        SendParam memory sendParam = SendParam({
            dstEid: sendingDstEid,
            to: bytes32(uint256(uint160(alice))),
            amountLD: 10 * 10 ** localDecimals,
            minAmountLD: 10 * 10 ** localDecimals,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        (OFTLimit memory limit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory receipt) = spellV2Oft.quoteOFT(
            sendParam
        );

        assertEq(limit.minAmountLD, 0);
        assertEq(limit.maxAmountLD, type(uint64).max);

        assertEq(oftFeeDetails.length, 0);

        assertEq(receipt.amountSentLD, 10 * 10 ** localDecimals);
        assertEq(receipt.amountReceivedLD, 10 * 10 ** localDecimals);
    }

    function test_quote_oft_bSpell() public {
        uint256 mimDecimalConversionRate = bSpellOft.decimalConversionRate();
        uint256 sharedDecimals = bSpellOft.sharedDecimals();
        uint256 localDecimals;
        if (block.chainid == ARB_CHAIN_ID) {
            localDecimals = IERC20Decimals(bSpellOft.token()).decimals();
        } else {
            localDecimals = bSpellOft.decimals();
        }
        uint256 tenTokensSD = 10 * (10 ** localDecimals / mimDecimalConversionRate);

        assertEq(10 * 10 ** sharedDecimals, tenTokensSD);

        SendParam memory sendParam = SendParam({
            dstEid: sendingDstEid,
            to: bytes32(uint256(uint160(alice))),
            amountLD: 10 * 10 ** localDecimals,
            minAmountLD: 10 * 10 ** localDecimals,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        (OFTLimit memory limit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory receipt) = bSpellOft.quoteOFT(
            sendParam
        );

        assertEq(limit.minAmountLD, 0);
        assertEq(limit.maxAmountLD, type(uint64).max);

        assertEq(oftFeeDetails.length, 0);

        assertEq(receipt.amountSentLD, 10 * 10 ** localDecimals);
        assertEq(receipt.amountReceivedLD, 10 * 10 ** localDecimals);
    }

    function test_oft_peer() public {
        if (block.chainid == 1) {
            // MIM

            address mimBeraPeer = AddressCast.toAddress(mimOft.peers(BERA_EID));
            assertEq(mimBeraPeer, MIM_OFT_BERA);

            address mimArbPeer = AddressCast.toAddress(mimOft.peers(ARB_EID));
            assertEq(mimArbPeer, address(0));

            // SpellV2

            address spellV2BeraPeer = AddressCast.toAddress(spellV2Oft.peers(BERA_EID));
            assertEq(spellV2BeraPeer, SPELLV2_OFT_BERA);

            address spellV2ArbPeer = AddressCast.toAddress(spellV2Oft.peers(ARB_EID));
            assertEq(spellV2ArbPeer, SPELLV2_OFT_ARB);

            // bSpell

            address bspellBeraPeer = AddressCast.toAddress(bSpellOft.peers(BERA_EID));
            assertEq(bspellBeraPeer, BSPELL_OFT_BERA);

            address bspellArbPeer = AddressCast.toAddress(bSpellOft.peers(ARB_EID));
            assertEq(bspellArbPeer, BSPELL_OFT_ARB);
        } else if (block.chainid == ARB_CHAIN_ID) {
            // No MIM

            // SpellV2

            address spellV2EthPeer = AddressCast.toAddress(spellV2Oft.peers(ETH_EID));
            assertEq(spellV2EthPeer, SPELLV2_OFT_ETH);

            address spellV2BeraPeer = AddressCast.toAddress(spellV2Oft.peers(BERA_EID));
            assertEq(spellV2BeraPeer, SPELLV2_OFT_BERA);

            // bSpell

            address bspellEthPeer = AddressCast.toAddress(bSpellOft.peers(ETH_EID));
            assertEq(bspellEthPeer, BSPELL_OFT_ETH);

            address bspellBeraPeer = AddressCast.toAddress(bSpellOft.peers(BERA_EID));
            assertEq(bspellBeraPeer, BSPELL_OFT_BERA);
        } else if (block.chainid == BERA_CHAIN_ID) {
            // MIM

            address mimEthPeer = AddressCast.toAddress(mimOft.peers(ETH_EID));
            assertEq(mimEthPeer, MIM_OFT_ETH);

            address mimArbPeer = AddressCast.toAddress(mimOft.peers(ARB_EID));
            assertEq(mimArbPeer, address(0));

            // SpellV2

            address spellV2EthPeer = AddressCast.toAddress(spellV2Oft.peers(ETH_EID));
            assertEq(spellV2EthPeer, SPELLV2_OFT_ETH);

            address spellV2ArbPeer = AddressCast.toAddress(spellV2Oft.peers(ARB_EID));
            assertEq(spellV2ArbPeer, SPELLV2_OFT_ARB);

            // bSpell

            address bspellEthPeer = AddressCast.toAddress(bSpellOft.peers(ETH_EID));
            assertEq(bspellEthPeer, BSPELL_OFT_ETH);

            address bspellArbPeer = AddressCast.toAddress(bSpellOft.peers(ARB_EID));
            assertEq(bspellArbPeer, BSPELL_OFT_ARB);
        }
    }

    function test_proxy_admin_owner() public view {
        if (block.chainid != ARB_CHAIN_ID) {
            Ownable proxyAdminMim = Ownable(address(uint160(uint256(vm.load(address(mimOft), PROXY_ADMIN_SLOT)))));
            assertEq(proxyAdminMim.owner(), safe);
        }

        Ownable proxyAdminSpellV2 = Ownable(address(uint160(uint256(vm.load(address(spellV2Oft), PROXY_ADMIN_SLOT)))));
        assertEq(proxyAdminSpellV2.owner(), safe);

        Ownable proxyAdminBSpell = Ownable(address(uint160(uint256(vm.load(address(bSpellOft), PROXY_ADMIN_SLOT)))));
        assertEq(proxyAdminBSpell.owner(), safe);
    }

    function test_oft_owner() public view {
        if (block.chainid != ARB_CHAIN_ID) {
            assertEq(Ownable(address(mimOft)).owner(), safe);
        }
        assertEq(Ownable(address(spellV2Oft)).owner(), safe);
        assertEq(Ownable(address(bSpellOft)).owner(), safe);
    }

    function test_oft_delegate() public {
        if (block.chainid != ARB_CHAIN_ID) {
            assertEq(ILayerZeroEndpointDelegateable(address(endpoint)).delegates(address(mimOft)), safe);
        }
        assertEq(ILayerZeroEndpointDelegateable(address(endpoint)).delegates(address(spellV2Oft)), safe);
        assertEq(ILayerZeroEndpointDelegateable(address(endpoint)).delegates(address(bSpellOft)), safe);
    }

    function test_no_msg_inspector() public {
        if (block.chainid != ARB_CHAIN_ID) {
            assertEq(mimOft.msgInspector(), address(0));
        }
        assertEq(spellV2Oft.msgInspector(), address(0));
        assertEq(bSpellOft.msgInspector(), address(0));
    }

    function test_oft_config_mim() public view {
        if (block.chainid == 1) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = MIM_DVN_ETH;
            requiredDvns[1] = LZ_DVN_ETH;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(BERA_EID, address(mimOft), sendLib, ETH_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(
                BERA_EID,
                address(mimOft),
                receiveLib,
                BERA_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );
        } else if (block.chainid == ARB_CHAIN_ID) {
            // No MIM on ARB
        } else if (block.chainid == BERA_CHAIN_ID) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = LZ_DVN_BERA;
            requiredDvns[1] = MIM_DVN_BERA;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(ETH_EID, address(mimOft), sendLib, BERA_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(ETH_EID, address(mimOft), receiveLib, ETH_CONFIRMATIONS, requiredDvns, optionalDvns, 0);
        }
    }

    function test_oft_config_spellv2() public view {
        if (block.chainid == ETH_CHAIN_ID) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = MIM_DVN_ETH;
            requiredDvns[1] = LZ_DVN_ETH;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(BERA_EID, address(mimOft), sendLib, ETH_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(ARB_EID, address(spellV2Oft), sendLib, ETH_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(
                BERA_EID,
                address(mimOft),
                receiveLib,
                BERA_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ARB_EID,
                address(spellV2Oft),
                receiveLib,
                ARB_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );
        } else if (block.chainid == ARB_CHAIN_ID) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = LZ_DVN_ARB;
            requiredDvns[1] = MIM_DVN_ARB;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(
                ETH_EID,
                address(spellV2Oft),
                sendLib,
                ARB_CONFIRMATIONS, // 20
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                BERA_EID,
                address(spellV2Oft),
                sendLib,
                ARB_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ETH_EID,
                address(spellV2Oft),
                receiveLib,
                ETH_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                BERA_EID,
                address(spellV2Oft),
                receiveLib,
                BERA_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );
        } else if (block.chainid == BERA_CHAIN_ID) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = LZ_DVN_BERA;
            requiredDvns[1] = MIM_DVN_BERA;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(
                ETH_EID,
                address(spellV2Oft),
                sendLib,
                BERA_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ARB_EID,
                address(spellV2Oft),
                sendLib,
                BERA_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ETH_EID,
                address(spellV2Oft),
                receiveLib,
                ETH_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ARB_EID,
                address(spellV2Oft),
                receiveLib,
                ARB_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );
        }
    }

    function test_oft_config_bSpell() public view {
        if (block.chainid == 1) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = MIM_DVN_ETH;
            requiredDvns[1] = LZ_DVN_ETH;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(BERA_EID, address(bSpellOft), sendLib, ETH_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(ARB_EID, address(bSpellOft), sendLib, ETH_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(
                BERA_EID,
                address(bSpellOft),
                receiveLib,
                BERA_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ARB_EID,
                address(bSpellOft),
                receiveLib,
                ARB_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );
        } else if (block.chainid == ARB_CHAIN_ID) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = LZ_DVN_ARB;
            requiredDvns[1] = MIM_DVN_ARB;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(
                BERA_EID,
                address(bSpellOft),
                sendLib,
                ARB_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ETH_EID,
                address(bSpellOft),
                sendLib,
                ARB_CONFIRMATIONS, // 20
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                BERA_EID,
                address(bSpellOft),
                receiveLib,
                BERA_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ETH_EID,
                address(bSpellOft),
                receiveLib,
                ETH_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );
        } else if (block.chainid == BERA_CHAIN_ID) {
            address[] memory requiredDvns = new address[](2);
            requiredDvns[0] = LZ_DVN_BERA;
            requiredDvns[1] = MIM_DVN_BERA;

            address[] memory optionalDvns = new address[](0);

            _verify_uln_config(ETH_EID, address(bSpellOft), sendLib, BERA_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(ARB_EID, address(bSpellOft), sendLib, BERA_CONFIRMATIONS, requiredDvns, optionalDvns, 0);

            _verify_uln_config(
                ETH_EID,
                address(bSpellOft),
                receiveLib,
                ETH_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );

            _verify_uln_config(
                ARB_EID,
                address(bSpellOft),
                receiveLib,
                ARB_CONFIRMATIONS,
                requiredDvns,
                optionalDvns,
                0
            );
        }
    }

    function _verify_uln_config(
        uint32 _eid,
        address _oapp,
        address _lib,
        uint64 _confirmations,
        address[] memory _required_dvns,
        address[] memory _optional_dvns,
        uint8 _optionalDvnCount
    ) public view {
        bytes memory config = endpoint.getConfig(address(_oapp), _lib, _eid, 2);

        UlnConfig memory ulnConfig = abi.decode(config, (UlnConfig));

        assertEq(ulnConfig.confirmations, _confirmations);
        assertEq(ulnConfig.requiredDVNCount, _required_dvns.length);
        assertEq(ulnConfig.requiredDVNs.length, _required_dvns.length);
        assertEq(ulnConfig.optionalDVNCount, _optional_dvns.length);
        assertEq(ulnConfig.optionalDVNs.length, _optional_dvns.length);
        assertEq(ulnConfig.optionalDVNThreshold, _optionalDvnCount);

        for (uint i; i < _required_dvns.length; ++i) {
            assertEq(ulnConfig.requiredDVNs[i], _required_dvns[i]);
        }

        for (uint i; i < _optional_dvns.length; ++i) {
            assertEq(ulnConfig.optionalDVNs[i], _optional_dvns[i]);
        }
    }
}

contract AbraForkEthTest is AbraForkTestBase {
    function setUp() public override {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 21845805);
        super.setUp();
    }
}

contract AbraForkArbitrumTest is AbraForkTestBase {
    function setUp() public override {
        vm.createSelectFork(vm.rpcUrl("arbitrum"), 306026400);
        super.setUp();
    }
}

contract AbraForkBeraTest is AbraForkTestBase {
    function setUp() public override {
        vm.createSelectFork(vm.rpcUrl("berachain"), 1132358);
        super.setUp();
    }
}

interface IPreCrimeView {
    struct Packet {
        uint16 srcChainId; // source chain id
        bytes32 srcAddress; // source UA address
        uint64 nonce;
        bytes payload;
    }

    struct SimulationResult {
        uint chainTotalSupply;
        bool isProxy;
    }

    /**
    * @dev get precrime config,
    * @param _packets packets
    * @return bytes of [maxBatchSize, remotePrecrimes]
    */
    function getConfig(Packet[] calldata _packets) external view returns (bytes memory);

    /**
    * @dev
    * @param _simulation all simulation results from difference chains
    * @return code     precrime result code; check out the error code defination
    * @return reason   error reason
    */
    function precrime(Packet[] calldata _packets, bytes[] calldata _simulation) external view returns (uint16 code, bytes memory reason);

    /**
    * @dev protocol version
    */
    function version() external view returns (uint16);

    /**
    * @dev simulate run cross chain packets and get a simulation result for precrime later
    * @param _packets packets, the packets item should group by srcChainId, srcAddress, then sort by nonce
    * @return code   simulation result code; see the error code defination
    * @return result the result is use for precrime params
    */
    function simulate(Packet[] calldata _packets) external view returns (uint16 code, bytes memory result);

    function setRemotePrecrimeAddresses(
        uint16[] calldata _remoteChainIds,
        bytes32[] calldata _remotePrecrimeAddresses
    ) external;
}

interface ILayerZero {
    function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external;

    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external;

    function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes memory);
}

interface IElevated {

    function mint(address to, uint256 amount) external returns (bool);

    function burn(address from, uint256 amount) external returns (bool);

    function setOperator(address operator, bool status) external;

    function token() external returns (address);

    function operators(address operator) external view returns (bool);
}

interface IMIM {
  function setMinter(address _auth) external;

  function applyMinter() external;
}

interface ILzCommonOFT {
    struct LzCallParams {
        address payable refundAddress;
        address zroPaymentAddress;
        bytes adapterParams;
    }

    /**
     * @dev estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`)
     * _dstChainId - L0 defined chain id to send tokens too
     * _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain
     * _amount - amount of the tokens to transfer
     * _useZro - indicates to use zro to pay L0 fees
     * _adapterParam - flexible bytes array to indicate messaging adapter services in L0
     */
    function estimateSendFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint nativeFee, uint zroFee);

    function estimateSendAndCallFee(
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bytes calldata _payload,
        uint64 _dstGasForCall,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint nativeFee, uint zroFee);

    /**
     * @dev returns the circulating amount of tokens on current chain
     */
    function circulatingSupply() external view returns (uint);

    /**
     * @dev returns the address of the ERC20 token
     */
    function token() external view returns (address);
}

interface ILzOFTV2 is ILzCommonOFT {
    /**
     * @dev send `_amount` amount of token to (`_dstChainId`, `_toAddress`) from `_from`
     * `_from` the owner of token
     * `_dstChainId` the destination chain identifier
     * `_toAddress` can be any size depending on the `dstChainId`.
     * `_amount` the quantity of tokens in wei
     * `_refundAddress` the address LayerZero refunds if too much message fee is sent
     * `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token)
     * `_adapterParams` is a flexible bytes array to indicate messaging adapter services
     */
    function sendFrom(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        LzCallParams calldata _callParams
    ) external payable;

    function sendAndCall(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount,
        bytes calldata _payload,
        uint64 _dstGasForCall,
        LzCallParams calldata _callParams
    ) external payable;
}

interface IOAppSetPeer {
    function setPeer(uint32 _eid, bytes32 _peer) external;
    function endpoint() external view returns (ILayerZeroEndpointV2 iEndpoint);
}

contract AbraForkMigration is Test {
    using OptionsBuilder for bytes;

    address constant MAINNET_SAFE = 0x5f0DeE98360d8200b20812e174d139A1a633EDd2;
    address constant MAINNET_PRECRIME = 0xD0b97bd475f53767DBc7aDcD70f499000Edc916C;
    address constant MAINNET_OFT = 0x439a5f0f5E8d149DDA9a0Ca367D4a8e4D6f83C10;
    address constant MAINNET_ENDPOINT = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
    address constant MAINNET_MIM = 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3;
    address constant MAINNET_V2_ADAPTER = 0xE5169F892000fC3BEd5660f62C67FAEE7F97718B;
    address constant MAINNET_V2_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    address constant ARBITRUM_SAFE = 0xf46BB6dDA9709C49EfB918201D97F6474EAc5Aea;
    address constant ARBITRUM_PRECRIME = 0xD0b97bd475f53767DBc7aDcD70f499000Edc916C;
    address constant ARBITRUM_OFT = 0x957A8Af7894E76e16DB17c2A913496a4E60B7090;
    address constant ARBITRUM_ELEVATED = 0x26F20d6Dee51ad59AF339BEdF9f721113D01b6b3;
    address constant ARBITRUM_MIM = 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A;
    address constant ARBITRUM_V2_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    uint32 constant ETH_EID = 30101;
    uint32 constant ARB_EID = 30110;

    uint arbitrumId;
    uint mainnetId;

    AbraOFTUpgradeableExisting mimOFTExisting;
    address public proxyAdmin = makeAddr("proxyAdmin");

    function setUp() public {
        arbitrumId = vm.createSelectFork(vm.rpcUrl("arbitrum"), 306026400);
        mimOFTExisting = AbraOFTUpgradeableExisting(
            TestHelper.deployContractAndProxy(
                proxyAdmin,
                type(AbraOFTUpgradeableExisting).creationCode,
                abi.encode(address(0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A), address(ARBITRUM_V2_ENDPOINT)),
                abi.encodeWithSelector(AbraOFTUpgradeableExisting.initialize.selector, address(this))
            )
        );

        mainnetId = vm.createFork(vm.rpcUrl("mainnet"), 21845805);
    }

    function step1_close_precime_eth() public {
        vm.selectFork(mainnetId);

        uint16[] memory remoteChainIds = new uint16[](10);
        remoteChainIds[0] = 102;
        remoteChainIds[1] = 109;
        remoteChainIds[2] = 112;
        remoteChainIds[3] = 111;
        remoteChainIds[4] = 106;
        remoteChainIds[5] = 167;
        remoteChainIds[6] = 177;
        remoteChainIds[7] = 184;
        remoteChainIds[8] = 183;
        remoteChainIds[9] = 243;

        bytes32[] memory remotePrecrimeAddresses = new bytes32[](10);
        remotePrecrimeAddresses[0] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[1] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[2] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[3] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[4] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[5] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[6] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[7] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[8] = 0x000000000000000000000000374748a045b37c7541e915199edbf392915909a4;
        remotePrecrimeAddresses[9] = 0x000000000000000000000000374748a045b37c7541e915199edbf392915909a4;

        vm.prank(MAINNET_SAFE);
        IPreCrimeView(MAINNET_PRECRIME).setRemotePrecrimeAddresses(remoteChainIds, remotePrecrimeAddresses);
    }

    function step1_close_precime_arb() public {
        vm.selectFork(arbitrumId);

        uint16[] memory remoteChainIds = new uint16[](10);
        remoteChainIds[0] = 102;
        remoteChainIds[1] = 109;
        remoteChainIds[2] = 112;
        remoteChainIds[3] = 111;
        remoteChainIds[4] = 106;
        remoteChainIds[5] = 167;
        remoteChainIds[6] = 177;
        remoteChainIds[7] = 184;
        remoteChainIds[8] = 183;
        remoteChainIds[9] = 243;

        bytes32[] memory remotePrecrimeAddresses = new bytes32[](10);
        remotePrecrimeAddresses[0] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[1] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[2] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[3] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[4] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[5] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[6] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[7] = 0x000000000000000000000000d0b97bd475f53767dbc7adcd70f499000edc916c;
        remotePrecrimeAddresses[8] = 0x000000000000000000000000374748a045b37c7541e915199edbf392915909a4;
        remotePrecrimeAddresses[9] = 0x000000000000000000000000374748a045b37c7541e915199edbf392915909a4;

        vm.prank(ARBITRUM_SAFE);
        IPreCrimeView(ARBITRUM_PRECRIME).setRemotePrecrimeAddresses(remoteChainIds, remotePrecrimeAddresses);
    }

    function step1_close_precrime() public {
        step1_close_precime_eth();
        step1_close_precime_arb();
    }

    function test_close_precrime_eth_arb() public {
        step1_close_precrime();
    }

    // ===========================================================

    function step2_close_bridges_to_arb() public {
        uint16 remoteChainId = 110;
        bytes memory path = hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000";

        // Turn of Mainnet to Arb
        vm.selectFork(mainnetId);
        vm.prank(MAINNET_SAFE);
        ILayerZero(MAINNET_OFT).setTrustedRemote(remoteChainId, path);
    }

    function test_close_bridges() public {
        step2_close_bridges_to_arb();
    }

    // ===========================================================

    function step3_close_arb_to_all_bridges() public {
        vm.selectFork(arbitrumId);
        uint16[] memory remoteChainIds = new uint16[](11);
        remoteChainIds[0] = 101;
        remoteChainIds[1] = 102;
        remoteChainIds[2] = 109;
        remoteChainIds[3] = 112;
        remoteChainIds[4] = 111;
        remoteChainIds[5] = 106;
        remoteChainIds[6] = 167;
        remoteChainIds[7] = 177;
        remoteChainIds[8] = 184;
        remoteChainIds[9] = 183;
        remoteChainIds[10] = 243;

        // The empty _path to disable the trusted remote.
        bytes memory emptyPath = hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000";

        ILayerZero bridge = ILayerZero(ARBITRUM_OFT);
        vm.startPrank(ARBITRUM_SAFE);
        // Loop through each remote chain ID and clear the trusted remote path.
        for (uint256 i = 0; i < remoteChainIds.length; i++) {
            bridge.setTrustedRemote(remoteChainIds[i], emptyPath);
        }
        vm.stopPrank();
    }

    function test_close_arb_to_all_bridges() public {
        step3_close_arb_to_all_bridges();
    }

    // ===========================================================

    function step4_mint_total_supply() public {
        vm.selectFork(arbitrumId);
        // --- Step 1: Allow Minting ---
        vm.prank(ARBITRUM_SAFE);
        IElevated(ARBITRUM_ELEVATED).setOperator(ARBITRUM_SAFE, true);

        // --- Step 2: Mint MIM to ARB Safe ---
        uint totalSupply = IERC20(ARBITRUM_MIM).totalSupply();
        vm.prank(ARBITRUM_SAFE);
        IElevated(ARBITRUM_ELEVATED).mint(ARBITRUM_SAFE, totalSupply);

        // --- Step 3: Open ARB -> ETH Bridge ---
        bytes memory openPath = hex"439a5f0f5e8d149dda9a0ca367d4a8e4d6f83c10957a8af7894e76e16db17c2a913496a4e60b7090";
        ILayerZero bridge = ILayerZero(ARBITRUM_OFT);
        vm.prank(ARBITRUM_SAFE);
        bridge.setTrustedRemote(101, openPath);

        // Step 4: Bridge MIM to Mainnet via LayerZero OFT.
        // Prepare call parameters for the sendFrom call.
        ILzCommonOFT.LzCallParams memory callParams = ILzCommonOFT.LzCallParams({
            refundAddress: payable(address(ARBITRUM_SAFE)),
            zroPaymentAddress: address(0),
            adapterParams: hex"000200000000000000000000000000000000000000000000000000000000000186a000000000000000000000000000000000000000000000000000000000000000003fa975ac91a8be601e800d4fa777c7200498f975"
        });

        // Convert the mainnet recipient to bytes32.
        bytes32 recipientBytes = bytes32(uint256(uint160(MAINNET_SAFE)));
        vm.prank(ARBITRUM_SAFE);
        ILzOFTV2(ARBITRUM_OFT).sendFrom{value: 0.004 ether}(ARBITRUM_SAFE, 101, recipientBytes, totalSupply, callParams);

        // --- Step 5: Close ARB -> ETH Bridge ---
        bytes memory closePath = hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000";
        vm.prank(ARBITRUM_SAFE);
        bridge.setTrustedRemote(101, closePath);

        // --- Step 6: Disable Minting ---
        vm.startPrank(ARBITRUM_SAFE);
        IElevated(ARBITRUM_ELEVATED).setOperator(ARBITRUM_SAFE, false);
        IElevated(ARBITRUM_ELEVATED).setOperator(ARBITRUM_OFT, false);
        IElevated(ARBITRUM_ELEVATED).setOperator(address(mimOFTExisting), true);
        vm.stopPrank();

        // Recieve the message
        vm.selectFork(mainnetId);
        bytes memory payload = abi.encodePacked(
            bytes13(0),
            MAINNET_SAFE,
            uint64(totalSupply / 1e10) // adjust for ld2sd rate
        );

        // @notice Apply fix for current migration issue.
        // ========================================================
        uint16 remoteChainId = 110;
        bytes memory path = hex"957a8af7894e76e16db17c2a913496a4e60b7090439a5f0f5e8d149dda9a0ca367d4a8e4d6f83c10";

        // Turn of Mainnet to Arb
        vm.selectFork(mainnetId);
        vm.prank(MAINNET_SAFE);
        ILayerZero(MAINNET_OFT).setTrustedRemote(remoteChainId, path);
        // ========================================================

        uint balanceBeforeReceive = IERC20(MAINNET_MIM).balanceOf(MAINNET_SAFE);
        vm.prank(MAINNET_ENDPOINT);
        ILayerZero(MAINNET_OFT).lzReceive(110, abi.encodePacked(ARBITRUM_OFT, MAINNET_OFT), 1000, payload);
        uint balanceAfterReceive = IERC20(MAINNET_MIM).balanceOf(MAINNET_SAFE);

        // Transfer received funds
        uint receivedFunds = balanceAfterReceive - balanceBeforeReceive;
        console.log("<step4> received funds:", receivedFunds);
        vm.prank(MAINNET_SAFE);
        IERC20(MAINNET_MIM).transfer(MAINNET_V2_ADAPTER, receivedFunds);
    }

    function test_mint_total_supply() public {
        step4_mint_total_supply();
    }
    // ===========================================================

    function test_run_all_steps() public {
        vm.selectFork(arbitrumId);
        uint256 arbitrumMIMSupplyBeforeMigration = IERC20(ARBITRUM_MIM).totalSupply();
        vm.selectFork(mainnetId);
        uint256 mainnetMIMBalanceAdapterBeforeMigration = IERC20(MAINNET_MIM).balanceOf(MAINNET_V2_ADAPTER);
        uint256 mainnetMIMSupplyBeforeMigration = IERC20(MAINNET_MIM).totalSupply();

        step1_close_precrime();
        step2_close_bridges_to_arb();
        step3_close_arb_to_all_bridges();
        step4_mint_total_supply();

        vm.selectFork(arbitrumId);
        uint256 arbitrumMIMSupplyAfterMigration = IERC20(ARBITRUM_MIM).totalSupply();
        vm.selectFork(mainnetId);
        uint256 mainnetMIMBalanceAdapterAfterMigration = IERC20(MAINNET_MIM).balanceOf(MAINNET_V2_ADAPTER);
        uint256 mainnetMIMSupplyAfterMigration = IERC20(MAINNET_MIM).totalSupply();

        // Notice how theres a slight discrepency due to dust from LayerZero scaling
        console.log("Arbitrum supply before migration....................", arbitrumMIMSupplyBeforeMigration);
        console.log("Arbitrum supply after migration.....................", arbitrumMIMSupplyAfterMigration);

        console.log("Mainnet Adapter Balance before migration............", mainnetMIMBalanceAdapterBeforeMigration);
        console.log("Mainnet Adapter Balance after migration.............", mainnetMIMBalanceAdapterAfterMigration);

        // Total supply stays the same
        console.log("Mainnet supply before migration.....................", mainnetMIMSupplyBeforeMigration);
        console.log("Mainnet supply after migration......................", mainnetMIMSupplyAfterMigration);
    }

    function test_transfer_mim_arb_to_mainnet() public {
      test_run_all_steps();

      // Set peers
      vm.selectFork(arbitrumId);
      vm.prank(address(this));
      mimOFTExisting.setPeer(ETH_EID, bytes32(uint256(uint160(MAINNET_V2_ADAPTER))));

      vm.selectFork(mainnetId);
      vm.prank(0xDF2C270f610Dc35d8fFDA5B453E74db5471E126B); // owner
      IOAppSetPeer(MAINNET_V2_ADAPTER).setPeer(ARB_EID, bytes32(uint256(uint160(address(mimOFTExisting)))));

      // Set new OFT to be allowed to mint/burn
      vm.selectFork(arbitrumId);
      vm.prank(0xf46BB6dDA9709C49EfB918201D97F6474EAc5Aea);
      IMIM(ARBITRUM_MIM).setMinter(address(mimOFTExisting));
      skip(172800);
      vm.prank(0xf46BB6dDA9709C49EfB918201D97F6474EAc5Aea);
      IMIM(ARBITRUM_MIM).applyMinter();

      // Send tokens from arb to mainnet
      vm.selectFork(arbitrumId);
      uint256 arbMIMBalanceBefore = IERC20(ARBITRUM_MIM).balanceOf(ARBITRUM_SAFE);

      uint256 tokensToSend = 1 ether;
      bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
      SendParam memory sendParam = SendParam(
          ETH_EID,
          bytes32(uint256(uint160(ARBITRUM_SAFE))),
          tokensToSend,
          tokensToSend,
          options,
          "",
          ""
      );
      MessagingFee memory fee = mimOFTExisting.quoteSend(sendParam, false);

      vm.prank(ARBITRUM_SAFE);
      mimOFTExisting.send{ value: fee.nativeFee }(sendParam, fee, payable(address(ARBITRUM_SAFE)));

      uint256 arbMIMBalanceAfter = IERC20(ARBITRUM_MIM).balanceOf(ARBITRUM_SAFE);
      assertEq(arbMIMBalanceAfter, arbMIMBalanceBefore - tokensToSend);

      // Receive tokens on mainnet
      vm.selectFork(mainnetId);
      uint256 mainnetMIMBalanceBefore = IERC20(MAINNET_MIM).balanceOf(ARBITRUM_SAFE);
      vm.startPrank(MAINNET_V2_ENDPOINT);
      (bytes memory message, ) = OFTMsgCodec.encode(OFTComposeMsgCodec.addressToBytes32(address(ARBITRUM_SAFE)), uint64(tokensToSend / 1e12), "");

      IOAppReceiver(MAINNET_V2_ADAPTER).lzReceive(
        Origin(ARB_EID, bytes32(uint256(uint160(address(mimOFTExisting)))), 0),
        0,
        message,
        address(MAINNET_V2_ADAPTER),
        ""
      );

      uint256 mainnetMIMBalanceAfter = IERC20(MAINNET_MIM).balanceOf(ARBITRUM_SAFE);
      assertEq(mainnetMIMBalanceAfter, mainnetMIMBalanceBefore + tokensToSend);
    }
}
