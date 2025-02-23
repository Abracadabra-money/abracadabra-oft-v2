// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IMintable {
    function mint(address to, uint256 amount) external returns (bool);

    function burn(address from, uint256 amount) external returns (bool);
}
