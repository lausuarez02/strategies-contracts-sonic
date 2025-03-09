// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDeBridgeGate {
    struct SubmissionParams {
        uint256 executionFee;
        uint256 flags;
        bytes fallbackAddress;
        bytes data;
    }

    struct SwapDescription {
        address srcToken;
        address dstToken;
        address srcReceiver;
        address dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 guaranteedAmount;
        uint256 flags;
        address referrer;
        bytes permit;
    }

    function send(
        address _token,
        uint256 _amount,
        uint256 _chainIdTo,
        bytes memory _receiver,
        bytes memory _nativeTokenTo,
        bytes memory _permitData,
        bool _useAssetFee,
        uint32 _referralCode,
        SubmissionParams memory _autoParams
    ) external payable;

    function swap(
        address _callTo,
        SwapDescription memory _desc,
        bytes[] memory _calls
    ) external returns (uint256);
} 