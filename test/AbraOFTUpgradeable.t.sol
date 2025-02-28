// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { IOFT, SendParam, OFTReceipt } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import { OFTInspectorMock } from "@layerzerolabs/oft-evm-upgradeable/test/mocks/OFTInspectorMock.sol";
import { OFTComposerMock } from "@layerzerolabs/oft-evm-upgradeable/test/mocks/OFTComposerMock.sol";
import { ProxyAdmin } from "hardhat-deploy/solc_0.8/openzeppelin/proxy/transparent/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "hardhat-deploy/solc_0.8/openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/libs/OAppOptionsType3Upgradeable.sol";
import { OFTMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTMsgCodec.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import { OFTInspectorMock, IOAppMsgInspector } from "@layerzerolabs/oft-evm-upgradeable/test/mocks/OFTInspectorMock.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { FeeHandler, QuoteType } from "contracts/FeeHandler.sol";
import { MockAggregator } from "./mocks/MockAggregator.sol";
import { AbraOFTUpgradeable } from "contracts/AbraOFTUpgradeable.sol";
import { AbraOFTAdapterUpgradeable } from "contracts/AbraOFTAdapterUpgradeable.sol";
import { AbraOFTUpgradeableExisting } from "contracts/AbraOFTUpgradeableExisting.sol";

contract AbraOFTUpgradeableTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;
    uint32 cEid = 3;

    AbraOFTUpgradeable aOFT;
    AbraOFTUpgradeable bOFT;
    AbraOFTAdapterUpgradeable cOFTAdapter;
    ERC20Mock cERC20Mock;

    OFTInspectorMock oAppInspector;

    address public userA = address(0x1);
    address public userB = address(0x2);
    address public userC = address(0x3);
    uint256 public initialBalance = 100 ether;

    address public proxyAdmin = makeAddr("proxyAdmin");

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.deal(userC, 1000 ether);

        super.setUp();
        setUpEndpoints(3, LibraryType.UltraLightNode);

        aOFT = AbraOFTUpgradeable(
            TestHelper.deployContractAndProxy(
                proxyAdmin,
                type(AbraOFTUpgradeable).creationCode,
                abi.encode(address(endpoints[aEid])),
                abi.encodeWithSelector(AbraOFTUpgradeable.initialize.selector, "aOFT", "aOFT", address(this))
            )
        );

        bOFT = AbraOFTUpgradeable(
            TestHelper.deployContractAndProxy(
                proxyAdmin,
                type(AbraOFTUpgradeable).creationCode,
                abi.encode(address(endpoints[bEid])),
                abi.encodeWithSelector(AbraOFTUpgradeable.initialize.selector, "bOFT", "bOFT", address(this))
            )
        );

        cERC20Mock = new ERC20Mock("cToken", "cToken");
        cOFTAdapter = AbraOFTAdapterUpgradeable(
            TestHelper.deployContractAndProxy(
                proxyAdmin,
                type(AbraOFTAdapterUpgradeable).creationCode,
                abi.encode(address(cERC20Mock), address(endpoints[cEid])),
                abi.encodeWithSelector(AbraOFTAdapterUpgradeable.initialize.selector, address(this))
            )
        );

        // config and wire the ofts
        address[] memory ofts = new address[](3);
        ofts[0] = address(aOFT);
        ofts[1] = address(bOFT);
        ofts[2] = address(cOFTAdapter);
        this.wireOApps(ofts);

        // mint tokens
        deal(address(aOFT), userA, initialBalance, true);
        deal(address(bOFT), userB, initialBalance, true);

        cERC20Mock.mint(userC, initialBalance);

        // deploy a universal inspector, can be used by each oft
        oAppInspector = new OFTInspectorMock();
    }

    function _deployContractAndProxy(
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

        return address(new TransparentUpgradeableProxy(addr, proxyAdmin, _initializeArgs));
    }

    function test_constructor() public view {
        assertEq(aOFT.owner(), address(this));
        assertEq(bOFT.owner(), address(this));
        assertEq(cOFTAdapter.owner(), address(this));

        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(bOFT.balanceOf(userB), initialBalance);
        assertEq(IERC20(cOFTAdapter.token()).balanceOf(userC), initialBalance);

        assertEq(aOFT.token(), address(aOFT));
        assertEq(bOFT.token(), address(bOFT));
        assertEq(cOFTAdapter.token(), address(cERC20Mock));
    }

    function test_oftVersion() public view {
        (bytes4 interfaceId, ) = aOFT.oftVersion();
        bytes4 expectedId = 0x02e49c2c;
        assertEq(interfaceId, expectedId);
    }

    function test_send_oft() public {
        uint256 tokensToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userB),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

        assertEq(aOFT.balanceOf(userA), initialBalance);
        assertEq(bOFT.balanceOf(userB), initialBalance);

        vm.prank(userA);
        aOFT.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(bOFT)));

        assertEq(aOFT.balanceOf(userA), initialBalance - tokensToSend);
        assertEq(bOFT.balanceOf(userB), initialBalance + tokensToSend);
    }

    function test_feeHandler_revert() public {
        FeeHandler feeHandler = new FeeHandler(
            1 ether,
            address(new MockAggregator()),
            address(this),
            QuoteType.Fixed,
            address(this)
        );

        // Test unauthorized access
        vm.prank(address(0xdead));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xdead)));
        feeHandler.setFeeTo(address(0x123));
    }

    function test_feeHandler() public {
        // Test fixed fee quote type
        FeeHandler feeHandler = new FeeHandler(
            1 ether, // fixedNativeFee
            address(new MockAggregator()), // aggregator
            address(this), // feeTo
            QuoteType.Fixed, // quoteType
            address(this) // owner
        );

        // Test fixed native fee quote
        uint256 nativeFee = feeHandler.quoteNativeFee();
        assertEq(nativeFee, 1 ether);

        // Test oracle quote type
        MockAggregator mockAggregator = new MockAggregator();
        mockAggregator.setAnswer(2000e8); // $2000 per ETH

        feeHandler = new FeeHandler(1 ether, address(mockAggregator), address(this), QuoteType.Oracle, address(this));

        // Test oracle-based fee quote
        nativeFee = feeHandler.quoteNativeFee();
        // Expected fee should be $1 worth of ETH at $2000/ETH rate
        assertEq(nativeFee, 0.0005 ether);

        // Test admin functions
        address newFeeTo = address(0x123);
        feeHandler.setFeeTo(newFeeTo);
        assertEq(feeHandler.feeTo(), newFeeTo);

        uint256 newFixedFee = 2 ether;
        feeHandler.setFixedNativeFee(newFixedFee);
        assertEq(feeHandler.fixedNativeFee(), newFixedFee);

        // Test quote type change
        feeHandler.setQuoteType(QuoteType.Fixed);
        assertEq(uint256(feeHandler.quoteType()), uint256(QuoteType.Fixed));

        // Test USD fee change
        uint256 newUsdFee = 2e18; // $2
        feeHandler.setUsdFee(newUsdFee);
        assertEq(feeHandler.usdFee(), newUsdFee);
    }

    function test_send_with_fee_collection() public {
        // Setup fee handler
        MockAggregator mockAggregator = new MockAggregator();
        address feeTo = makeAddr("feeTo");
        FeeHandler feeHandler = new FeeHandler(0, address(mockAggregator), feeTo, QuoteType.Oracle, address(this));

        feeHandler.setUsdFee(1e18); // $1 fee
        mockAggregator.setAnswer(2000e8); // $2000 per ETH

        // Set fee handler in OFTs
        aOFT.setFeeHandler(address(feeHandler));
        bOFT.setFeeHandler(address(feeHandler));

        uint256 tokensToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userB),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );

        MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

        uint256 feeHandlerFee = feeHandler.quoteNativeFee();

        // Record initial balances
        uint256 feeToInitialBalance = feeTo.balance;

        // Send tokens
        vm.prank(userA);
        aOFT.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(bOFT)));

        // Verify token transfers
        assertEq(aOFT.balanceOf(userA), initialBalance - tokensToSend, "aOFT balance of userA");
        assertEq(bOFT.balanceOf(userB), initialBalance + tokensToSend, "bOFT balance of userB");

        // Verify fee collection
        assertEq(feeTo.balance - feeToInitialBalance, feeHandlerFee, "feeTo balance");
    }

    function test_upgrade() public {
        // Deploy initial implementation
        AbraOFTUpgradeable initialImpl = new AbraOFTUpgradeable(address(endpoints[aEid]));

        // Deploy ProxyAdmin
        ProxyAdmin admin = new ProxyAdmin(address(this));

        // Deploy proxy with initialization data
        bytes memory initData = abi.encodeWithSelector(
            AbraOFTUpgradeable.initialize.selector,
            "MyOFT",
            "MOFT",
            address(this)
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(initialImpl),
            address(admin),
            initData
        );

        AbraOFTUpgradeable oft = AbraOFTUpgradeable(address(proxy));

        // Get initial implementation
        address initialImplAddress = admin.getProxyImplementation(TransparentUpgradeableProxy(payable(address(proxy))));

        // Deploy mock implementation with mint function
        AbraOFTUpgradeableMock mockImpl = new AbraOFTUpgradeableMock(address(endpoints[aEid]));

        // Upgrade to mock implementation
        vm.prank(address(this));
        admin.upgrade(TransparentUpgradeableProxy(payable(address(proxy))), address(mockImpl));

        // Verify implementation changed
        address newImplAddress = address(
            admin.getProxyImplementation(TransparentUpgradeableProxy(payable(address(proxy))))
        );
        assertTrue(initialImplAddress != newImplAddress, "Implementation should change");
        assertEq(newImplAddress, address(mockImpl), "Should point to mock implementation");

        // Test new mint functionality
        uint256 balanceBefore = oft.balanceOf(userA);
        AbraOFTUpgradeableMock(address(oft)).mint(userA, 100);
        assertEq(oft.balanceOf(userA), balanceBefore + 100, "Should mint new tokens");

        // Deploy new implementation without mint
        AbraOFTUpgradeable newImpl = new AbraOFTUpgradeable(address(endpoints[aEid]));

        // Upgrade to new implementation
        vm.prank(address(this));
        admin.upgrade(TransparentUpgradeableProxy(payable(address(proxy))), address(newImpl));

        // Verify final balance remains after upgrade
        assertEq(oft.balanceOf(userA), balanceBefore + 100, "Balance should be preserved after upgrade");
    }

    function test_upgrade_revert_unauthorized() public {
        // Deploy new implementation
        AbraOFTUpgradeable newImpl = new AbraOFTUpgradeable(address(endpoints[aEid]));

        // Deploy ProxyAdmin
        ProxyAdmin admin = new ProxyAdmin(address(this));

        // Try to upgrade from non-admin address
        vm.prank(userA);
        vm.expectRevert("Ownable: caller is not the owner");
        admin.upgradeAndCall(TransparentUpgradeableProxy(payable(address(aOFT))), address(newImpl), "");
    }

    // Helper function to get implementation address
    function _getImplementationAddress() internal view returns (address implementation) {
        // Storage slot for implementation address in EIP-1967
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        assembly {
            implementation := sload(slot)
        }
    }
}

contract AbraOFTUpgradeableMock is AbraOFTUpgradeable {
    constructor(address _lzEndpoint) AbraOFTUpgradeable(_lzEndpoint) {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

contract AbraOFTUpgradeableExistingTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    AbraOFTUpgradeableExisting aOFT;
    AbraOFTUpgradeableExisting bOFT;
    ERC20Mock aToken;
    ERC20Mock bToken;

    address public userA = address(0x1);
    address public userB = address(0x2);
    uint256 public initialBalance = 100 ether;

    address public proxyAdmin = makeAddr("proxyAdmin");

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy underlying tokens
        aToken = new ERC20Mock("aToken", "aTKN");
        bToken = new ERC20Mock("bToken", "bTKN");

        // Deploy OFTs with existing tokens
        aOFT = AbraOFTUpgradeableExisting(
            TestHelper.deployContractAndProxy(
                proxyAdmin,
                type(AbraOFTUpgradeableExisting).creationCode,
                abi.encode(address(aToken),address(aToken), address(endpoints[aEid])),
                abi.encodeWithSelector(AbraOFTUpgradeableExisting.initialize.selector, address(this))
            )
        );

        bOFT = AbraOFTUpgradeableExisting(
            TestHelper.deployContractAndProxy(
                proxyAdmin,
                type(AbraOFTUpgradeableExisting).creationCode,
                abi.encode(address(bToken), address(bToken), address(endpoints[bEid])),
                abi.encodeWithSelector(AbraOFTUpgradeableExisting.initialize.selector, address(this))
            )
        );

        // Wire the OFTs
        address[] memory ofts = new address[](2);
        ofts[0] = address(aOFT);
        ofts[1] = address(bOFT);
        this.wireOApps(ofts);

        // Mint tokens to users
        deal(address(aToken), userA, initialBalance, true);
        deal(address(bToken), userB, initialBalance, true);
    }

    function test_constructor_existing() public view {
        assertEq(aOFT.owner(), address(this));
        assertEq(bOFT.owner(), address(this));

        assertEq(IERC20(aOFT.token()).balanceOf(userA), initialBalance);
        assertEq(IERC20(bOFT.token()).balanceOf(userB), initialBalance);

        assertEq(aOFT.token(), address(aToken));
        assertEq(bOFT.token(), address(bToken));
    }

    function test_send_existing_oft() public {
        uint256 tokensToSend = 1 ether;
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam(
            bEid,
            addressToBytes32(userB),
            tokensToSend,
            tokensToSend,
            options,
            "",
            ""
        );
        MessagingFee memory fee = aOFT.quoteSend(sendParam, false);

        // Initial balances
        assertEq(IERC20(aToken).balanceOf(userA), initialBalance);
        assertEq(IERC20(bToken).balanceOf(userB), initialBalance);

        // Send tokens
        vm.prank(userA);
        aOFT.send{ value: fee.nativeFee }(sendParam, fee, payable(address(this)));
        verifyPackets(bEid, addressToBytes32(address(bOFT)));

        // Verify balances after transfer
        assertEq(IERC20(aToken).balanceOf(userA), initialBalance - tokensToSend);
        assertEq(IERC20(bToken).balanceOf(userB), initialBalance + tokensToSend);
    }
}

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
