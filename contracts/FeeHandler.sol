// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { IFeeHandler } from "./interfaces/IFeeHandler.sol";
import { IAggregator } from "./interfaces/IAggregator.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

enum QuoteType {
    Oracle,
    Fixed
}

contract FeeHandler is IFeeHandler, Ownable {
    event FixedNativeFeeChanged(uint256 previous, uint256 current);
    event OracleImplementationChange(IAggregator indexed previous, IAggregator indexed current);
    event QuoteTypeChanged(QuoteType previous, QuoteType current);
    event FeeToChanged(address indexed previous, address indexed current);
    event UsdFeeChanged(uint256 previous, uint256 current);

    error InvalidQuoteType(QuoteType);
    error Unauthorized();

    uint256 public constant DEFAULT_USD_FEE = 1e18;

    address public override feeTo;
    IAggregator public aggregator;
    uint256 public fixedNativeFee;
    uint256 public usdFee;
    QuoteType public quoteType = QuoteType.Oracle;

    constructor(
        uint256 _fixedNativeFee,
        address _aggregator,
        address _feeTo,
        QuoteType _quoteType,
        address _owner
    ) Ownable(_owner) {
        fixedNativeFee = _fixedNativeFee;
        aggregator = IAggregator(_aggregator);
        feeTo = _feeTo;
        quoteType = _quoteType;
        usdFee = DEFAULT_USD_FEE;
    }

    /////////////////////////////////////////////////////////////////////////
    // PUBLIC
    /////////////////////////////////////////////////////////////////////////

    function quoteNativeFee() external view override returns (uint256 nativeFee) {
        if (quoteType == QuoteType.Oracle) {
            nativeFee = ((10 ** aggregator.decimals()) * usdFee) / uint256(aggregator.latestAnswer());
        } else if (quoteType == QuoteType.Fixed) {
            nativeFee = fixedNativeFee;
        }
    }

    /////////////////////////////////////////////////////////////////////////
    // ADMIN
    /////////////////////////////////////////////////////////////////////////

    function setFixedNativeFee(uint256 _fixedNativeFee) external onlyOwner {
        emit FixedNativeFeeChanged(fixedNativeFee, _fixedNativeFee);
        fixedNativeFee = _fixedNativeFee;
    }

    function setAggregator(IAggregator _aggregator) external onlyOwner {
        emit OracleImplementationChange(aggregator, _aggregator);
        aggregator = _aggregator;
    }

    function setUsdFee(uint256 _usdFee) external onlyOwner {
        emit UsdFeeChanged(usdFee, _usdFee);
        usdFee = _usdFee;
    }

    function setQuoteType(QuoteType _quoteType) external onlyOwner {
        if (_quoteType > QuoteType.Fixed) {
            revert InvalidQuoteType(_quoteType);
        }
        emit QuoteTypeChanged(quoteType, _quoteType);
        quoteType = _quoteType;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        emit FeeToChanged(feeTo, _feeTo);
        feeTo = _feeTo;
    }
}
