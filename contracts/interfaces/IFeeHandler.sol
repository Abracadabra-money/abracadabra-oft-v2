// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IFeeHandler {
    function feeTo() external view returns (address);

    function quoteNativeFee() external view returns (uint256 feeAmount);
}
