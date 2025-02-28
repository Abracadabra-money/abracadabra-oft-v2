// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { OAppSenderUpgradeable } from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppSenderUpgradeable.sol";
import { MessagingFee, MessagingReceipt, MessagingParams } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { IFeeHandler } from "./interfaces/IFeeHandler.sol";

abstract contract SenderWithFees is OAppSenderUpgradeable {
    event FeeHandlerSet(address indexed feeHandler);
    event FeeCollected(uint256 amount);

    address public feeHandler;

    function setFeeHandler(address _feeHandler) external onlyOwner {
        feeHandler = _feeHandler;
        emit FeeHandlerSet(_feeHandler);
    }

    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal virtual override returns (MessagingReceipt memory receipt) {
        uint256 msgValue = msg.value;
        uint256 protocolNativeFees;

        if (feeHandler != address(0)) {
            protocolNativeFees = IFeeHandler(feeHandler).quoteNativeFee();
        }

        if (_fee.lzTokenFee > 0) {
            _payLzToken(_fee.lzTokenFee);
        }

        if (protocolNativeFees > 0) {
            (bool success, ) = IFeeHandler(feeHandler).feeTo().call{ value: protocolNativeFees }("");
            require(success, "FEE_TRANSFER_FAILED");
            emit FeeCollected(protocolNativeFees);

            msgValue -= protocolNativeFees;
        }

        return
            // solhint-disable-next-line check-send-result
            endpoint.send{ value: msgValue }(
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0),
                _refundAddress
            );
    }

    function _quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) internal view virtual override returns (MessagingFee memory fee) {
        fee = super._quote(_dstEid, _message, _options, _payInLzToken);

        if (feeHandler != address(0)) {
            fee.nativeFee += IFeeHandler(feeHandler).quoteNativeFee();
        }
    }
}
