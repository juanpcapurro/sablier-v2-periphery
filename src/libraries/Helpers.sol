// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.19;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IAllowanceTransfer } from "@permit2/interfaces/IAllowanceTransfer.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ISablierV2Lockup } from "@sablier/v2-core/interfaces/ISablierV2Lockup.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { ISablierV2LockupPro } from "@sablier/v2-core/interfaces/ISablierV2LockupPro.sol";
import { LockupLinear, LockupPro } from "@sablier/v2-core/types/DataTypes.sol";

import { Errors } from "./Errors.sol";
import { IWETH9 } from "../interfaces/IWETH9.sol";
import { Permit2Params, CreateLinear, CreatePro } from "../types/DataTypes.sol";

library Helpers {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks the arguments of the create multiple functions.
    function checkCreateMultipleParams(uint128 totalAmount, uint128 amountsSum) internal pure {
        // Checks: the total amount is not zero.
        if (totalAmount == 0) {
            revert Errors.SablierV2ProxyTarget_TotalAmountZero();
        }

        /// Checks: the total amount is equal to the parameters amounts summed up.
        if (amountsSum != totalAmount) {
            revert Errors.SablierV2ProxyTarget_TotalAmountNotEqualToAmountsSum(totalAmount, amountsSum);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                          INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Helper function that:
    /// 1. Gets the asset of the stream.
    /// 2. Gets the return amount of the stream.
    /// 3. Performs an external call on {SablierV2Lockup-cancel}.
    /// 4. Transfers the return amount to proxy owner, if greater than zero.
    function cancel(ISablierV2Lockup lockup, uint256 streamId) internal {
        // Interactions: get the asset.
        IERC20 asset = lockup.getAsset(streamId);

        // Interactions: get the return amount.
        uint256 returnAmount = lockup.returnableAmountOf(streamId);

        // Interactions: cancel the stream.
        lockup.cancel(streamId);

        // Interactions: transfer the return amount to proxy owner, if greater than zero.
        if (returnAmount > 0) {
            asset.safeTransfer(msg.sender, returnAmount);
        }
    }

    /// @dev Helper function that:
    /// 1. Gets the proxy balances of each asset before the streams are canceled.
    /// 2. Performs an external call on {SablierV2Lockup-cancelMultiple}.
    /// 3. Transfers the return amounts sum to proxy owner, if greater than zero.
    function cancelMultiple(ISablierV2Lockup lockup, IERC20[] calldata assets, uint256[] calldata streamIds) internal {
        uint256 i;
        uint256 assetsCount = assets.length;
        uint256[] memory balancesBefore = new uint256[](assetsCount);
        for (i = 0; i < assetsCount; ) {
            balancesBefore[i] = assets[i].balanceOf(address(this));

            unchecked {
                i += 1;
            }
        }

        /// Interactions: cancel the streams.
        lockup.cancelMultiple(streamIds);

        uint256 balanceAfter;
        uint256 balanceDelta;
        for (i = 0; i < assetsCount; ) {
            balanceAfter = assets[i].balanceOf(address(this));
            balanceDelta = balanceAfter - balancesBefore[i];
            if (balanceDelta > 0) {
                assets[i].safeTransfer(msg.sender, balanceDelta);
            }

            unchecked {
                i += 1;
            }
        }
    }

    /// @dev Checks the wrap function parameters and deposits the Ether in the WETH9 contract.
    function checkParamsAndDepositEther(IWETH9 weth9, IERC20 asset, uint256 amount) internal {
        // Checks: the asset is the actual WETH9 contract.
        if (asset != weth9) {
            revert Errors.SablierV2ProxyTarget_AssetNotWETH9(asset, weth9);
        }

        uint256 value = msg.value;

        // Checks: the amount of WETH9 is the same as the amount of Ether sent.
        if (amount != value) {
            revert Errors.SablierV2ProxyTarget_WrongEtherAmount(value, amount);
        }

        // Interactions: deposit the Ether into the WETH9 contract.
        weth9.deposit{ value: value }();
    }

    /// @dev Helper function that:
    /// 1. Transfers funds from the `msg.sender` to the proxy contract via Permit2.
    /// 2. Approves the {SablierV2LockupPro} contract to spend funds from proxy, if necessary.
    /// 3. Performs an external call on {SablierV2LockupPro-createWithDeltas}.
    function createWithDeltas(
        ISablierV2LockupPro pro,
        LockupPro.CreateWithDeltas calldata params,
        Permit2Params calldata permit2Params
    ) internal returns (uint256 streamId) {
        assetActions(address(pro), params.asset, params.totalAmount, permit2Params);
        streamId = pro.createWithDeltas(params);
    }

    /// @dev Helper function that:
    /// 1. Transfers funds from the `msg.sender` to the proxy contract via Permit2.
    /// 2. Approves the {SablierV2LockupLinear} contract to spend funds from proxy, if necessary.
    /// 3. Performs an external call on {SablierV2LockupLinear-createWithDeltas}.
    function createWithDurations(
        ISablierV2LockupLinear linear,
        LockupLinear.CreateWithDurations calldata params,
        Permit2Params calldata permit2Params
    ) internal returns (uint256 streamId) {
        assetActions(address(linear), params.asset, params.totalAmount, permit2Params);
        streamId = linear.createWithDurations(params);
    }

    /// @dev Helper function that:
    /// 1. Transfers funds from the `msg.sender` to the proxy contract via Permit2.
    /// 2. Approves the {SablierV2LockupPro} contract to spend funds from proxy, if necessary.
    /// 3. Performs an external call on {SablierV2LockupPro-createWithMilestones}.
    function createWithMilestones(
        ISablierV2LockupPro pro,
        LockupPro.CreateWithMilestones calldata params,
        Permit2Params calldata permit2Params
    ) internal returns (uint256 streamId) {
        assetActions(address(pro), params.asset, params.totalAmount, permit2Params);
        streamId = pro.createWithMilestones(params);
    }

    /// @dev Helper function that:
    /// 1. Transfers funds from the `msg.sender` to the proxy contract via Permit2.
    /// 2. Approves the {SablierV2LockupLinear} contract to spend funds from proxy, if necessary.
    /// 3. Performs an external call on {SablierV2LockupLinear-createWithRange}.
    function createWithRange(
        ISablierV2LockupLinear linear,
        LockupLinear.CreateWithRange calldata params,
        Permit2Params calldata permit2Params
    ) internal returns (uint256 streamId) {
        assetActions(address(linear), params.asset, params.totalAmount, permit2Params);
        streamId = linear.createWithRange(params);
    }

    /// @dev Helper function that transfers `amount` funds from `msg.sender` to `address(this)` via Permit2
    /// and approves `amount` to `lockup`, if necessary.
    function assetActions(address lockup, IERC20 asset, uint160 amount, Permit2Params calldata permit2Params) internal {
        /// Interactions: get the nonce for `msg.sender`.
        (, , uint48 nonce) = permit2Params.permit2.allowance(msg.sender, address(asset), address(this));

        /// Declare the `PermitSingle` struct used in `permit` function.
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(asset),
                amount: amount,
                expiration: permit2Params.expiration,
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: permit2Params.sigDeadline
        });

        /// Interactions: permit the proxy to spend funds from `msg.sender`.
        permit2Params.permit2.permit(msg.sender, permitSingle, permit2Params.signature);

        /// Interactions: transfer funds from `msg.sender` to proxy.
        permit2Params.permit2.transferFrom(msg.sender, address(this), amount, address(asset));

        /// Interactions: get the allownace of the proxy for `lockup`
        /// and approve `lockup`, if necessary.
        uint256 allowance = asset.allowance(address(this), lockup);
        if (allowance < uint256(amount)) {
            asset.approve(lockup, type(uint256).max);
        }
    }
}
