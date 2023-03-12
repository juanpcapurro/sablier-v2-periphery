// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ISablierV2Lockup } from "@sablier/v2-core/interfaces/ISablierV2Lockup.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2LockupPro } from "@sablier/v2-core/interfaces/ISablierV2LockupPro.sol";
import { LockupLinear, LockupPro } from "@sablier/v2-core/types/DataTypes.sol";

import { ISablierV2ProxyTarget } from "./interfaces/ISablierV2ProxyTarget.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
import { Helpers } from "./libraries/Helpers.sol";
import { Permit2Params, CreateLinear, CreatePro } from "./types/DataTypes.sol";

/// @title SablierV2ProxyTarget
/// @notice Implements the {ISablierV2ProxyTarget} interface.
contract SablierV2ProxyTarget is ISablierV2ProxyTarget {
    /*//////////////////////////////////////////////////////////////////////////
                                 SABLIER-V2-LOCKUP
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2ProxyTarget
    function cancel(ISablierV2Lockup lockup, uint256 streamId) external {
        Helpers.cancel(lockup, streamId);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function cancelMultiple(ISablierV2Lockup lockup, IERC20[] calldata assets, uint256[] calldata streamIds) external {
        Helpers.cancelMultiple(lockup, assets, streamIds);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function renounce(ISablierV2Lockup lockup, uint256 streamId) external {
        lockup.renounce(streamId);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function withdraw(ISablierV2Lockup lockup, uint256 streamId, address to, uint128 amount) external {
        lockup.withdraw(streamId, to, amount);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function withdrawMax(ISablierV2Lockup lockup, uint256 streamId, address to) external {
        lockup.withdrawMax(streamId, to);
    }

    /*//////////////////////////////////////////////////////////////////////////
                              SABLIER-V2-LOCKUP-LINEAR
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2ProxyTarget
    function cancelAndCreateWithDurations(
        ISablierV2Lockup lockup,
        ISablierV2LockupLinear linear,
        uint256 streamId,
        LockupLinear.CreateWithDurations calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 newStreamId) {
        Helpers.cancel(lockup, streamId);
        newStreamId = Helpers.createWithDurations(linear, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function cancelAndCreateWithRange(
        ISablierV2Lockup lockup,
        ISablierV2LockupLinear linear,
        uint256 streamId,
        LockupLinear.CreateWithRange calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 newStreamId) {
        Helpers.cancel(lockup, streamId);
        newStreamId = Helpers.createWithRange(linear, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithDurations(
        ISablierV2LockupLinear linear,
        LockupLinear.CreateWithDurations calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 streamId) {
        streamId = Helpers.createWithDurations(linear, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithRange(
        ISablierV2LockupLinear linear,
        LockupLinear.CreateWithRange calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 streamId) {
        streamId = Helpers.createWithRange(linear, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithDurationsMultiple(
        ISablierV2LockupLinear linear,
        IERC20 asset,
        uint128 totalAmount,
        CreateLinear.DurationsParams[] calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256[] memory streamIds) {
        uint128 amountsSum;
        uint256 count = params.length;
        uint256 i;

        // Calculate the params amounts summed up.
        for (i = 0; i < count; ) {
            amountsSum += params[i].amount;
            unchecked {
                i += 1;
            }
        }

        // Checks: the `totalAmount` is zero and if it's equal to the sum of the `params.amount`.
        Helpers.checkCreateMultipleParams(totalAmount, amountsSum);

        // Interactions: perform the ERC-20 transfer and approve {SablierV2LockupLinear} to spend the amount of assets.
        Helpers.assetActions(address(linear), asset, totalAmount, permit2Params);

        // Declare an array of `count` length to avoid "Index out of bounds error".
        uint256[] memory _streamIds = new uint256[](count);
        for (i = 0; i < count; ) {
            // Interactions: make the external call.
            _streamIds[i] = linear.createWithDurations(
                LockupLinear.CreateWithDurations({
                    asset: asset,
                    broker: params[i].broker,
                    cancelable: params[i].cancelable,
                    durations: params[i].durations,
                    recipient: params[i].recipient,
                    sender: params[i].sender,
                    totalAmount: params[i].amount
                })
            );

            // Increment the for loop iterator.
            unchecked {
                i += 1;
            }
        }

        streamIds = _streamIds;
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithRangeMultiple(
        ISablierV2LockupLinear linear,
        IERC20 asset,
        uint128 totalAmount,
        CreateLinear.RangeParams[] calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256[] memory streamIds) {
        uint128 amountsSum;
        uint256 count = params.length;
        uint256 i;

        // Calculate the params amounts summed up.
        for (i = 0; i < count; ) {
            amountsSum += params[i].amount;
            unchecked {
                i += 1;
            }
        }

        // Checks: the `totalAmount` is zero and if it's equal to the sum of the `params.amount`.
        Helpers.checkCreateMultipleParams(totalAmount, amountsSum);

        // Interactions: perform the ERC-20 transfer and approve {SablierV2LockupLinear} to spend the amount of assets.
        Helpers.assetActions(address(linear), asset, totalAmount, permit2Params);

        // Declare an array of `count` length to avoid "Index out of bounds error".
        uint256[] memory _streamIds = new uint256[](count);
        for (i = 0; i < count; ) {
            // Interactions: make the external call.
            _streamIds[i] = linear.createWithRange(
                LockupLinear.CreateWithRange({
                    asset: asset,
                    broker: params[i].broker,
                    cancelable: params[i].cancelable,
                    range: params[i].range,
                    recipient: params[i].recipient,
                    sender: params[i].sender,
                    totalAmount: params[i].amount
                })
            );

            // Increment the for loop iterator.
            unchecked {
                i += 1;
            }
        }

        streamIds = _streamIds;
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function wrapEtherAndCreateWithDurations(
        ISablierV2LockupLinear linear,
        IWETH9 weth9,
        LockupLinear.CreateWithDurations calldata params,
        Permit2Params calldata permit2Params
    ) external payable override returns (uint256 streamId) {
        // Checks and interactions: check the params and deposit the ether.
        Helpers.checkParamsAndDepositEther(weth9, params.asset, params.totalAmount);
        streamId = Helpers.createWithDurations(linear, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function wrapEtherAndCreateWithRange(
        ISablierV2LockupLinear linear,
        IWETH9 weth9,
        LockupLinear.CreateWithRange calldata params,
        Permit2Params calldata permit2Params
    ) external payable override returns (uint256 streamId) {
        // Checks and interactions: check the params and deposit the ether.
        Helpers.checkParamsAndDepositEther(weth9, params.asset, params.totalAmount);
        streamId = Helpers.createWithRange(linear, params, permit2Params);
    }

    /*//////////////////////////////////////////////////////////////////////////
                               SABLIER-V2-LOCKUP-PRO
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2ProxyTarget
    function cancelAndCreateWithDeltas(
        ISablierV2Lockup lockup,
        ISablierV2LockupPro pro,
        uint256 streamId,
        LockupPro.CreateWithDeltas calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 newStreamId) {
        Helpers.cancel(lockup, streamId);
        newStreamId = Helpers.createWithDeltas(pro, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function cancelAndCreateWithMilestones(
        ISablierV2Lockup lockup,
        ISablierV2LockupPro pro,
        uint256 streamId,
        LockupPro.CreateWithMilestones calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 newStreamId) {
        Helpers.cancel(lockup, streamId);
        newStreamId = Helpers.createWithMilestones(pro, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithDelta(
        ISablierV2LockupPro pro,
        LockupPro.CreateWithDeltas calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 streamId) {
        streamId = Helpers.createWithDeltas(pro, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithMilestones(
        ISablierV2LockupPro pro,
        LockupPro.CreateWithMilestones calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256 streamId) {
        streamId = Helpers.createWithMilestones(pro, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithDeltasMultiple(
        ISablierV2LockupPro pro,
        IERC20 asset,
        uint128 totalAmount,
        CreatePro.DeltasParams[] calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256[] memory streamIds) {
        uint128 amountsSum;
        uint256 count = params.length;
        uint256 i;

        // Calculate the params amounts summed up.
        for (i = 0; i < count; ) {
            amountsSum += params[i].amount;
            unchecked {
                i += 1;
            }
        }

        // Checks: the `totalAmount` is zero and if it's equal to the sum of the `params.amount`.
        Helpers.checkCreateMultipleParams(totalAmount, amountsSum);

        // Interactions: perform the ERC-20 transfer and approve {SablierV2LockupPro} to spend the amount of assets.
        Helpers.assetActions(address(pro), asset, totalAmount, permit2Params);

        // Declare an array of `count` length to avoid "Index out of bounds error".
        uint256[] memory _streamIds = new uint256[](count);
        for (i = 0; i < count; ) {
            // Interactions: make the external call.
            _streamIds[i] = pro.createWithDeltas(
                LockupPro.CreateWithDeltas({
                    asset: asset,
                    broker: params[i].broker,
                    cancelable: params[i].cancelable,
                    recipient: params[i].recipient,
                    segments: params[i].segments,
                    sender: params[i].sender,
                    totalAmount: params[i].amount
                })
            );

            // Increment the for loop iterator.
            unchecked {
                i += 1;
            }
        }

        streamIds = _streamIds;
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function createWithMilestonesMultiple(
        ISablierV2LockupPro pro,
        IERC20 asset,
        uint128 totalAmount,
        CreatePro.MilestonesParams[] calldata params,
        Permit2Params calldata permit2Params
    ) external override returns (uint256[] memory streamIds) {
        uint128 amountsSum;
        uint256 count = params.length;
        uint256 i;

        // Calculate the params amounts summed up.
        for (i = 0; i < count; ) {
            amountsSum += params[i].amount;
            unchecked {
                i += 1;
            }
        }

        // Checks: the `totalAmount` is zero and if it's equal to the sum of the `params.amount`.
        Helpers.checkCreateMultipleParams(totalAmount, amountsSum);

        // Interactions: perform the ERC-20 transfer and approve {SablierV2LockupPro} to spend the amount of assets.
        Helpers.assetActions(address(pro), asset, totalAmount, permit2Params);

        // Declare an array of `count` length to avoid "Index out of bounds error".
        uint256[] memory _streamIds = new uint256[](count);
        for (i = 0; i < count; ) {
            // Interactions: make the external call.
            _streamIds[i] = pro.createWithMilestones(
                LockupPro.CreateWithMilestones({
                    asset: asset,
                    broker: params[i].broker,
                    cancelable: params[i].cancelable,
                    recipient: params[i].recipient,
                    segments: params[i].segments,
                    sender: params[i].sender,
                    startTime: params[i].startTime,
                    totalAmount: params[i].amount
                })
            );

            // Increment the for loop iterator.
            unchecked {
                i += 1;
            }
        }

        streamIds = _streamIds;
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function wrapEtherAndCreateWithDeltas(
        ISablierV2LockupPro pro,
        IWETH9 weth9,
        LockupPro.CreateWithDeltas calldata params,
        Permit2Params calldata permit2Params
    ) external payable override returns (uint256 streamId) {
        // Checks and interactions: check the params and deposit the ether.
        Helpers.checkParamsAndDepositEther(weth9, params.asset, params.totalAmount);
        streamId = Helpers.createWithDeltas(pro, params, permit2Params);
    }

    /// @inheritdoc ISablierV2ProxyTarget
    function wrapEtherAndCreateWithMilestones(
        ISablierV2LockupPro pro,
        IWETH9 weth9,
        LockupPro.CreateWithMilestones calldata params,
        Permit2Params calldata permit2Params
    ) external payable override returns (uint256 streamId) {
        // Checks and interactions: check the params and deposit the ether.
        Helpers.checkParamsAndDepositEther(weth9, params.asset, params.totalAmount);
        streamId = Helpers.createWithMilestones(pro, params, permit2Params);
    }
}
