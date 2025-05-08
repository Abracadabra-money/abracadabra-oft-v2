// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Test } from "forge-std/Test.sol";
import { FeeHandler, QuoteType } from "../contracts/FeeHandler.sol";
import { IAggregator } from "../contracts/interfaces/IAggregator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Extended MockAggregator that implements the full IAggregator interface
contract MockAggregatorFull is IAggregator {
    int256 private _answer;
    uint8 public constant decimals = 8;

    constructor(int256 _initialAnswer) {
        _answer = _initialAnswer;
    }

    function setAnswer(int256 _newAnswer) external {
        _answer = _newAnswer;
    }

    function latestAnswer() external view returns (int256) {
        return _answer;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _answer, block.timestamp, block.timestamp, 1);
    }
}

contract FeeHandlerTest is Test {
    FeeHandler public feeHandler;
    MockAggregatorFull public mockAggregator;

    address public owner = address(0x1);
    address public feeTo = address(0x2);
    address public user = address(0x3);

    uint256 public fixedNativeFee = 0.01 ether;
    int256 public initialPrice = 2000 * 10 ** 8; // $2000 with 8 decimals

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock aggregator with initial ETH/USD price
        mockAggregator = new MockAggregatorFull(initialPrice);

        // Deploy FeeHandler with Oracle type by default
        feeHandler = new FeeHandler(fixedNativeFee, address(mockAggregator), feeTo, QuoteType.Oracle, owner);

        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(feeHandler.fixedNativeFee(), fixedNativeFee);
        assertEq(address(feeHandler.aggregator()), address(mockAggregator));
        assertEq(feeHandler.feeTo(), feeTo);
        assertEq(uint(feeHandler.quoteType()), uint(QuoteType.Oracle));
        assertEq(feeHandler.owner(), owner);
        assertEq(feeHandler.usdFee(), feeHandler.DEFAULT_USD_FEE());
    }

    function testQuoteNativeFeeOracle() public view {
        // With price of $2000/ETH and usdFee of $1, the native fee should be 0.0005 ETH
        uint256 expectedFee = 0.0005 ether;

        // Call quoteNativeFee
        uint256 quotedFee = feeHandler.quoteNativeFee();

        assertApproxEqRel(quotedFee, expectedFee, 0.01e18); // Allow 1% deviation due to rounding
    }

    function testQuoteNativeFeeFixed() public {
        // Change quote type to Fixed
        vm.prank(owner);
        feeHandler.setQuoteType(QuoteType.Fixed);

        // Call quoteNativeFee
        uint256 quotedFee = feeHandler.quoteNativeFee();

        // Should return the fixed fee
        assertEq(quotedFee, fixedNativeFee);
    }

    function testSetFixedNativeFee() public {
        uint256 newFixedFee = 0.02 ether;

        vm.prank(owner);
        feeHandler.setFixedNativeFee(newFixedFee);

        assertEq(feeHandler.fixedNativeFee(), newFixedFee);
    }

    function testSetAggregator() public {
        // Deploy new mock aggregator
        MockAggregatorFull newAggregator = new MockAggregatorFull(initialPrice);

        vm.prank(owner);
        feeHandler.setAggregator(IAggregator(address(newAggregator)));

        assertEq(address(feeHandler.aggregator()), address(newAggregator));
    }

    function testSetUsdFee() public {
        uint256 newUsdFee = 2 * 10 ** 18; // $2

        vm.prank(owner);
        feeHandler.setUsdFee(newUsdFee);

        assertEq(feeHandler.usdFee(), newUsdFee);
    }

    function testSetQuoteType() public {
        vm.startPrank(owner);

        // Switch to Fixed
        feeHandler.setQuoteType(QuoteType.Fixed);
        assertEq(uint(feeHandler.quoteType()), uint(QuoteType.Fixed));

        // Switch back to Oracle
        feeHandler.setQuoteType(QuoteType.Oracle);
        assertEq(uint(feeHandler.quoteType()), uint(QuoteType.Oracle));

        vm.stopPrank();
    }

    function testSetFeeTo() public {
        address newFeeTo = address(0x4);

        vm.prank(owner);
        feeHandler.setFeeTo(newFeeTo);

        assertEq(feeHandler.feeTo(), newFeeTo);
    }

    function testOnlyOwnerRestrictions() public {
        vm.startPrank(user);

        // All admin functions should revert with OwnableUnauthorizedAccount error
        // The error format matches OpenZeppelin v5.0+
        bytes memory expectedError = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user);

        vm.expectRevert(expectedError);
        feeHandler.setFixedNativeFee(0.03 ether);

        vm.expectRevert(expectedError);
        feeHandler.setAggregator(IAggregator(address(0x5)));

        vm.expectRevert(expectedError);
        feeHandler.setUsdFee(3 * 10 ** 18);

        vm.expectRevert(expectedError);
        feeHandler.setQuoteType(QuoteType.Fixed);

        vm.expectRevert(expectedError);
        feeHandler.setFeeTo(address(0x6));

        vm.stopPrank();
    }

    function testChangingOraclePriceAffectsFee() public {
        // Initial fee with $2000/ETH
        uint256 initialFee = feeHandler.quoteNativeFee();

        // Change price to $1000/ETH
        int256 newPrice = 1000 * 10 ** 8;
        mockAggregator.setAnswer(newPrice);

        // Fee should double since ETH price halved
        uint256 newFee = feeHandler.quoteNativeFee();
        assertEq(newFee, initialFee * 2);
    }
}
