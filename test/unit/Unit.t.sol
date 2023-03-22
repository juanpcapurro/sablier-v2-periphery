// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { UD2x18, ud2x18 } from "@prb/math/UD2x18.sol";
import { Broker, LockupDynamic } from "@sablier/v2-core/types/DataTypes.sol";

import { Batch, Permit2Params } from "src/types/DataTypes.sol";

import { Base_Test } from "../Base.t.sol";

contract Unit_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Permit2Params internal defaultPermit2Params;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();

        // Deploy and label the sender proxy.
        proxy = registry.deployFor(users.sender);
        vm.label({ account: address(proxy), newLabel: "Proxy" });

        defaultPermit2Params = Permit2Params({
            permit2: permit2,
            expiration: DEFAULT_PERMIT2_EXPIRATION,
            sigDeadline: DEFAULT_PERMIT2_SIG_DEADLINE,
            signature: getPermit2Signature(privateKeys.sender, address(proxy))
        });

        deployCore();
        approvePermit2();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Helper function to return an array of `Batch.CreateWithDeltas` that is not "storage ref".
    function defaultDeltasParams() internal view returns (Batch.CreateWithDeltas[] memory) {
        Batch.CreateWithDeltas[] memory params = new Batch.CreateWithDeltas[](BATCH_PARAMS_COUNT);

        for (uint256 i = 0; i < BATCH_PARAMS_COUNT; ++i) {
            params[i] = Batch.CreateWithDeltas({
                amount: DEFAULT_AMOUNT,
                broker: Broker({ account: users.broker, fee: DEFAULT_BROKER_FEE }),
                cancelable: true,
                recipient: users.recipient,
                segments: defaultSegmentsWithDeltas(),
                sender: users.sender
            });
        }

        return params;
    }

    /// @dev Helper function to return an array of `Batch.CreateWithDurations` that is not "storage ref".
    function defaultDurationsParams() internal view returns (Batch.CreateWithDurations[] memory) {
        Batch.CreateWithDurations[] memory params = new Batch.CreateWithDurations[](BATCH_PARAMS_COUNT);

        for (uint256 i = 0; i < BATCH_PARAMS_COUNT; ++i) {
            params[i] = Batch.CreateWithDurations({
                amount: DEFAULT_AMOUNT,
                broker: Broker({ account: users.broker, fee: DEFAULT_BROKER_FEE }),
                cancelable: true,
                durations: DEFAULT_DURATIONS,
                recipient: users.recipient,
                sender: users.sender
            });
        }

        return params;
    }

    /// @dev Helper function to return an array of `Batch.CreateWithMilestones` that is not "storage ref".
    function defaultMilestonesParams() internal view returns (Batch.CreateWithMilestones[] memory) {
        Batch.CreateWithMilestones[] memory params = new Batch.CreateWithMilestones[](BATCH_PARAMS_COUNT);

        for (uint256 i = 0; i < BATCH_PARAMS_COUNT; ++i) {
            params[i] = Batch.CreateWithMilestones({
                amount: DEFAULT_AMOUNT,
                broker: Broker({ account: users.broker, fee: DEFAULT_BROKER_FEE }),
                cancelable: true,
                recipient: users.recipient,
                segments: defaultSegments(),
                sender: users.sender,
                startTime: DEFAULT_START_TIME
            });
        }

        return params;
    }

    /// @dev Helper function to return an array of `Batch.CreateWithRange` that is not "storage ref".
    function defaultRangeParams() internal view returns (Batch.CreateWithRange[] memory) {
        Batch.CreateWithRange[] memory params = new Batch.CreateWithRange[](BATCH_PARAMS_COUNT);

        for (uint256 i = 0; i < BATCH_PARAMS_COUNT; ++i) {
            params[i] = Batch.CreateWithRange({
                amount: DEFAULT_AMOUNT,
                broker: Broker({ account: users.broker, fee: DEFAULT_BROKER_FEE }),
                cancelable: true,
                range: DEFAULT_LINEAR_RANGE,
                recipient: users.recipient,
                sender: users.sender
            });
        }

        return params;
    }

    /// @dev Helper function to return an array of `LockupDynamic.Segment` that is not "storage ref".
    function defaultSegments() internal view returns (LockupDynamic.Segment[] memory) {
        LockupDynamic.Segment[] memory segments = new LockupDynamic.Segment[](2);

        segments[0] = LockupDynamic.Segment({
            amount: 2500e18,
            exponent: ud2x18(3.14e18),
            milestone: DEFAULT_START_TIME + DEFAULT_CLIFF_DURATION
        });
        segments[1] = LockupDynamic.Segment({
            amount: 2500e18,
            exponent: ud2x18(3.14e18),
            milestone: DEFAULT_START_TIME + DEFAULT_CLIFF_DURATION
        });

        return segments;
    }

    /// @dev Helper function to return an array of `LockupDynamic.SegmentWithDelta` that is not "storage ref".
    function defaultSegmentsWithDeltas() internal pure returns (LockupDynamic.SegmentWithDelta[] memory) {
        LockupDynamic.SegmentWithDelta[] memory segments = new LockupDynamic.SegmentWithDelta[](2);

        segments[0] =
            LockupDynamic.SegmentWithDelta({ amount: 2500e18, delta: 2500 seconds, exponent: ud2x18(3.14e18) });
        segments[1] =
            LockupDynamic.SegmentWithDelta({ amount: 2500e18, delta: 2500 seconds, exponent: ud2x18(3.14e18) });

        return segments;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Creates default streams with deltas.
    function batchCreateWithDeltasDefault() internal returns (uint256[] memory streamIds) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithDeltas,
            (dynamic, asset, DEFAULT_TOTAL_AMOUNT, defaultDeltasParams(), defaultPermit2Params)
        );
        bytes memory response = proxy.execute(address(target), data);
        streamIds = abi.decode(response, (uint256[]));
    }

    /// @dev Creates default streams with durations.
    function batchCreateWithDurationsDefault() internal returns (uint256[] memory streamIds) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithDurations,
            (linear, asset, DEFAULT_TOTAL_AMOUNT, defaultDurationsParams(), defaultPermit2Params)
        );
        bytes memory response = proxy.execute(address(target), data);
        streamIds = abi.decode(response, (uint256[]));
    }

    /// @dev Creates default streams with milestones.
    function batchCreateWithMilestonesDefault() internal returns (uint256[] memory streamIds) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithMilestones,
            (dynamic, asset, DEFAULT_TOTAL_AMOUNT, defaultMilestonesParams(), defaultPermit2Params)
        );
        bytes memory response = proxy.execute(address(target), data);
        streamIds = abi.decode(response, (uint256[]));
    }

    /// @dev Creates default streams with range.
    function batchCreateWithRangeDefault() internal returns (uint256[] memory streamIds) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithRange,
            (linear, asset, DEFAULT_TOTAL_AMOUNT, defaultRangeParams(), defaultPermit2Params)
        );
        bytes memory response = proxy.execute(address(target), data);
        streamIds = abi.decode(response, (uint256[]));
    }
}
