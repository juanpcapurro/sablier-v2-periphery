// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Errors } from "src/libraries/Errors.sol";
import { Batch } from "src/types/DataTypes.sol";

import { Unit_Test } from "../Unit.t.sol";
import { DefaultParams } from "../../helpers/DefaultParams.t.sol";

contract BatchCreateWithDurations_Test is Unit_Test {
    function setUp() public virtual override {
        Unit_Test.setUp();

        changePrank(users.sender);
    }

    /// @dev it should revert.
    function test_RevertWhen_TotalAmountZero() external {
        uint128 totalAmountZero = 0;
        bytes memory data = abi.encodeCall(
            target.batchCreateWithDurations,
            (
                linear,
                asset,
                totalAmountZero,
                DefaultParams.batchCreateWithDurations(users, address(proxy)),
                permit2Params(totalAmountZero)
            )
        );
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2ProxyTarget_TotalAmountZero.selector));
        proxy.execute(address(target), data);
    }

    modifier whenTotalAmountNotZero() {
        _;
    }

    /// @dev it should revert.
    function test_RevertWhen_ParamsCountZero() external whenTotalAmountNotZero {
        Batch.CreateWithDurations[] memory params;
        bytes memory data = abi.encodeCall(
            target.batchCreateWithDurations,
            (linear, asset, DefaultParams.TOTAL_AMOUNT, params, permit2Params(DefaultParams.TOTAL_AMOUNT))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2ProxyTarget_TotalAmountNotEqualToAmountsSum.selector, DefaultParams.TOTAL_AMOUNT, 0
            )
        );
        proxy.execute(address(target), data);
    }

    modifier whenParamsCountNotZero() {
        _;
    }

    /// @dev it should revert.
    function test_RevertWhen_TotalAmountNotEqualToAmountsSum() external whenTotalAmountNotZero whenParamsCountNotZero {
        uint128 totalAmount = DefaultParams.TOTAL_AMOUNT - 1;
        bytes memory data = abi.encodeCall(
            target.batchCreateWithDurations,
            (
                linear,
                asset,
                totalAmount,
                DefaultParams.batchCreateWithDurations(users, address(proxy)),
                permit2Params(totalAmount)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2ProxyTarget_TotalAmountNotEqualToAmountsSum.selector,
                totalAmount,
                DefaultParams.TOTAL_AMOUNT
            )
        );
        proxy.execute(address(target), data);
    }

    modifier whenTotalAmountEqualToAmountsSum() {
        _;
    }

    /// @dev it should create multiple streams.
    function test_BatchCreateWithDurations()
        external
        whenTotalAmountNotZero
        whenParamsCountNotZero
        whenTotalAmountEqualToAmountsSum
    {
        // Asset flow: sender -> proxy -> linear
        expectTransferFromCall(users.sender, address(proxy), DefaultParams.TOTAL_AMOUNT);
        expectMultipleTransferCalls(address(proxy), address(linear), DefaultParams.AMOUNT);
        expectMultipleCreateWithDurationsCalls(DefaultParams.createWithDurations(users, address(proxy), asset));

        uint256[] memory streamIds = batchCreateWithDurationsDefault();
        assertEq(streamIds, DefaultParams.streamIds());
    }
}
