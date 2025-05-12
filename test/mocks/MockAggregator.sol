// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

contract MockAggregator {
    int256 private answer;
    uint8 public constant decimals = 8;

    function setAnswer(int256 _answer) external {
        answer = _answer;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, answer, 0, 0, 0);
    }
}
