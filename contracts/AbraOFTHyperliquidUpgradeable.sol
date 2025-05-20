// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { AbraOFTUpgradeable } from "./AbraOFTUpgradeable.sol";

contract AbraOFTHyperliquidUpgradeable is AbraOFTUpgradeable {
    event SetTrusted(address indexed _address, bool _isTrusted);
    error OnlyTrusted();
    error InvalidRecipient();

    mapping(address => bool) public isTrusted;

    constructor(address _lzEndpoint) AbraOFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }

    function setTrusted(address _address, bool _isTrusted) external onlyOwner {
        isTrusted[_address] = _isTrusted;
        emit SetTrusted(_address, _isTrusted);
    }

    function transferWithHop(address intermediate, address recipient, uint256 amount) external {
        if (!isTrusted[msg.sender]) {
            revert OnlyTrusted();
        }

        if (intermediate == recipient) {
            revert InvalidRecipient();
        }

        _transfer(msg.sender, intermediate, amount);
        _transfer(intermediate, recipient, amount);
    }
}
