// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPRBProxy } from "@prb/proxy/interfaces/IPRBProxy.sol";
import { IPRBProxyAnnex } from "@prb/proxy/interfaces/IPRBProxyAnnex.sol";
import { IPRBProxyRegistry } from "@prb/proxy/interfaces/IPRBProxyRegistry.sol";
import { ISablierV2Lockup } from "@sablier/v2-core/interfaces/ISablierV2Lockup.sol";
import { ISablierV2LockupDynamic } from "@sablier/v2-core/interfaces/ISablierV2LockupDynamic.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { IAllowanceTransfer } from "permit2/interfaces/IAllowanceTransfer.sol";
import { LockupDynamic, LockupLinear } from "@sablier/v2-core/types/DataTypes.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Utils as V2CoreUtils } from "@sablier/v2-core-test/utils/Utils.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import { ISablierV2Archive } from "src/interfaces/ISablierV2Archive.sol";
import { ISablierV2ProxyPlugin } from "src/interfaces/ISablierV2ProxyPlugin.sol";
import { ISablierV2ProxyTarget } from "src/interfaces/ISablierV2ProxyTarget.sol";
import { IWrappedNativeAsset } from "src/interfaces/IWrappedNativeAsset.sol";
import { SablierV2Archive } from "src/SablierV2Archive.sol";
import { SablierV2ProxyPlugin } from "src/SablierV2ProxyPlugin.sol";
import { SablierV2ProxyTarget } from "src/SablierV2ProxyTarget.sol";
import { Permit2Params } from "src/types/DataTypes.sol";

import { Assertions } from "./utils/Assertions.sol";
import { Defaults } from "./utils/Defaults.sol";
import { Events } from "./utils/Events.sol";
import { Users } from "./utils/Types.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Assertions, Events, StdCheats, V2CoreUtils {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ISablierV2Archive internal archive;
    IERC20 internal asset;
    Defaults internal defaults;
    ISablierV2LockupDynamic internal dynamic;
    ISablierV2LockupLinear internal linear;
    IAllowanceTransfer internal permit2;
    ISablierV2ProxyPlugin internal plugin;
    IPRBProxy internal proxy;
    IPRBProxyAnnex internal proxyAnnex;
    IPRBProxyRegistry internal proxyRegistry;
    ISablierV2ProxyTarget internal target;
    IWrappedNativeAsset internal weth;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        users.alice = createUser("Alice");
        users.admin = createUser("Admin");
        users.broker = createUser("Broker");
        users.eve = createUser("Eve");
        users.recipient = createUser("Recipient");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with ETH.
    function createUser(string memory name) internal returns (Account memory user) {
        user = makeAccount(name);
        vm.deal({ account: user.addr, newBalance: 100_000 ether });
        deal({ token: address(asset), to: user.addr, give: 1_000_000e18 });
    }

    /// @dev Conditionally deploy V2 Periphery normally or from a source precompiled with `--via-ir`.
    function deployPeripheryConditionally() internal {
        if (!isTestOptimizedProfile()) {
            archive = new SablierV2Archive(users.admin.addr);
            plugin = new SablierV2ProxyPlugin(archive);
            target = new SablierV2ProxyTarget();
        } else {
            archive = deployPrecompiledArchive(users.admin.addr);
            plugin = deployPrecompiledPlugin(archive);
            target = deployPrecompiledTarget();
        }
    }

    /// @dev Deploys {SablierV2Archive} from a source precompiled with `--via-ir`.
    function deployPrecompiledArchive(address initialAdmin) internal returns (ISablierV2Archive) {
        return ISablierV2Archive(
            deployCode("out-optimized/SablierV2Archive.sol/SablierV2Archive.json", abi.encode(initialAdmin))
        );
    }

    /// @dev Deploys {SablierV2ProxyPlugin} from a source precompiled with `--via-ir`.
    function deployPrecompiledPlugin(ISablierV2Archive archive_) internal returns (ISablierV2ProxyPlugin) {
        return ISablierV2ProxyPlugin(
            deployCode("out-optimized/SablierV2ProxyPlugin.sol/SablierV2ProxyPlugin.json", abi.encode(archive_))
        );
    }

    /// @dev Deploys {SablierV2ProxyTarget} from a source precompiled with `--via-ir`.
    function deployPrecompiledTarget() internal returns (ISablierV2ProxyTarget) {
        return ISablierV2ProxyTarget(deployCode("out-optimized/SablierV2ProxyTarget.sol/SablierV2ProxyTarget.json"));
    }

    /// @dev Labels the most relevant contracts.
    function labelContracts() internal {
        vm.label({ account: address(archive), newLabel: "Archive" });
        vm.label({ account: address(asset), newLabel: IERC20Metadata(address(asset)).symbol() });
        vm.label({ account: address(defaults), newLabel: "Defaults" });
        vm.label({ account: address(dynamic), newLabel: "LockupDynamic" });
        vm.label({ account: address(linear), newLabel: "LockupLinear" });
        vm.label({ account: address(permit2), newLabel: "Permit2" });
        vm.label({ account: address(plugin), newLabel: "Proxy Plugin" });
        vm.label({ account: address(proxy), newLabel: "Proxy" });
        vm.label({ account: address(target), newLabel: "Proxy Target" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Expects a call to {ISablierV2Lockup.cancel}.
    function expectCallToCancel(ISablierV2Lockup lockup, uint256 streamId) internal {
        vm.expectCall({ callee: address(lockup), data: abi.encodeCall(ISablierV2Lockup.cancel, (streamId)) });
    }

    /// @dev Expect calls to {ISablierV2Lockup.cancel}, {IERC20.transfer}, and {IERC20.transferFrom}.
    function expectCallsToCancelAndTransfer(
        ISablierV2Lockup cancelContract,
        ISablierV2Lockup createContract,
        uint256 streamId
    )
        internal
    {
        expectCallToCancel(cancelContract, streamId);

        // Asset flow: Sablier → proxy → proxy owner
        // Expect transfers from Sablier to the proxy, and then from the proxy to the proxy owner.
        expectCallToTransfer({ to: address(proxy), amount: defaults.PER_STREAM_AMOUNT() });
        expectCallToTransfer({ to: users.alice.addr, amount: defaults.PER_STREAM_AMOUNT() });

        // Asset flow: proxy owner → proxy → Sablier
        // Expect transfers from the proxy owner to the proxy, and then from the proxy to the Sablier contract.
        expectCallToTransferFrom({ from: users.alice.addr, to: address(proxy), amount: defaults.PER_STREAM_AMOUNT() });
        expectCallToTransferFrom({
            from: address(proxy),
            to: address(createContract),
            amount: defaults.PER_STREAM_AMOUNT()
        });
    }

    /// @dev Expects a call to {ISablierV2Lockup.cancelMultiple}.
    function expectCallToCancelMultiple(ISablierV2Lockup lockup, uint256[] memory streamIds) internal {
        vm.expectCall({ callee: address(lockup), data: abi.encodeCall(ISablierV2Lockup.cancelMultiple, (streamIds)) });
    }

    /// @dev Expects a call to {ISablierV2LockupDynamic.createWithDeltas}.
    function expectCallToCreateWithDeltas(LockupDynamic.CreateWithDeltas memory params) internal {
        vm.expectCall({
            callee: address(dynamic),
            data: abi.encodeCall(ISablierV2LockupDynamic.createWithDeltas, (params))
        });
    }

    /// @dev Expects a call to {ISablierV2LockupLinear.createWithDurations}.
    function expectCallToCreateWithDurations(LockupLinear.CreateWithDurations memory params) internal {
        vm.expectCall({
            callee: address(linear),
            data: abi.encodeCall(ISablierV2LockupLinear.createWithDurations, (params))
        });
    }

    /// @dev Expects a call to {ISablierV2LockupDynamic.createWithMilestones}.
    function expectCallToCreateWithMilestones(LockupDynamic.CreateWithMilestones memory params) internal {
        vm.expectCall({
            callee: address(dynamic),
            data: abi.encodeCall(ISablierV2LockupDynamic.createWithMilestones, (params))
        });
    }

    /// @dev Expects a call to {ISablierV2LockupLinear.createWithRange}.
    function expectCallToCreateWithRange(LockupLinear.CreateWithRange memory params) internal {
        vm.expectCall({ callee: address(linear), data: abi.encodeCall(ISablierV2LockupLinear.createWithRange, (params)) });
    }

    /// @dev Expects a call to {IERC20.transfer}.
    function expectCallToTransfer(address to, uint256 amount) internal {
        expectCallToTransfer(address(asset), to, amount);
    }

    /// @dev Expects a call to {IERC20.transfer}.
    function expectCallToTransfer(address asset_, address to, uint256 amount) internal {
        vm.expectCall({ callee: asset_, data: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /// @dev Expects a call to {IERC20.transferFrom}.
    function expectCallToTransferFrom(address from, address to, uint256 amount) internal {
        expectCallToTransferFrom(address(asset), from, to, amount);
    }

    /// @dev Expects a call to {IERC20.transferFrom}.
    function expectCallToTransferFrom(address asset_, address from, address to, uint256 amount) internal {
        vm.expectCall({ callee: asset_, data: abi.encodeCall(IERC20.transferFrom, (from, to, amount)) });
    }

    /// @dev Expects multiple calls to {ISablierV2LockupDynamic.createWithMilestones}.
    function expectMultipleCallsToCreateWithDeltas(
        uint64 count,
        LockupDynamic.CreateWithDeltas memory params
    )
        internal
    {
        vm.expectCall({
            callee: address(dynamic),
            count: count,
            data: abi.encodeCall(ISablierV2LockupDynamic.createWithDeltas, (params))
        });
    }

    /// @dev Expects multiple calls to {ISablierV2LockupLinear.createWithDurations}.
    function expectMultipleCallsToCreateWithDurations(
        uint64 count,
        LockupLinear.CreateWithDurations memory params
    )
        internal
    {
        vm.expectCall({
            callee: address(linear),
            count: count,
            data: abi.encodeCall(ISablierV2LockupLinear.createWithDurations, (params))
        });
    }

    /// @dev Expects multiple calls to {ISablierV2LockupDynamic.createWithMilestones}.
    function expectMultipleCallsToCreateWithMilestones(
        uint64 count,
        LockupDynamic.CreateWithMilestones memory params
    )
        internal
    {
        vm.expectCall({
            callee: address(dynamic),
            count: count,
            data: abi.encodeCall(ISablierV2LockupDynamic.createWithMilestones, (params))
        });
    }

    /// @dev Expects multiple calls to {ISablierV2LockupLinear.createWithRange}.
    function expectMultipleCallsToCreateWithRange(uint64 count, LockupLinear.CreateWithRange memory params) internal {
        vm.expectCall({
            callee: address(linear),
            count: count,
            data: abi.encodeCall(ISablierV2LockupLinear.createWithRange, (params))
        });
    }

    /// @dev Expects multiple calls to {IERC20.transfer}.
    function expectMultipleCallsToTransfer(uint64 count, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), count: count, data: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /// @dev Expects multiple calls to {IERC20.transferFrom}.
    function expectMultipleCallsToTransferFrom(uint64 count, address from, address to, uint256 amount) internal {
        expectMultipleCallsToTransferFrom(address(asset), count, from, to, amount);
    }

    /// @dev Expects multiple calls to {IERC20.transferFrom}.
    function expectMultipleCallsToTransferFrom(
        address asset_,
        uint64 count,
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        vm.expectCall({ callee: asset_, count: count, data: abi.encodeCall(IERC20.transferFrom, (from, to, amount)) });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       PLUGIN
    //////////////////////////////////////////////////////////////////////////*/

    function installPlugin() internal {
        bytes memory data = abi.encodeCall(proxyAnnex.installPlugin, (plugin));
        proxy.execute(address(proxyAnnex), data);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       TARGET
    //////////////////////////////////////////////////////////////////////////*/

    function batchCreateWithDeltas() internal returns (uint256[] memory) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithDeltas,
            (dynamic, asset, defaults.batchCreateWithDeltas(), defaults.permit2Params(defaults.TOTAL_TRANSFER_AMOUNT()))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256[]));
    }

    function batchCreateWithDurations() internal returns (uint256[] memory) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithDurations,
            (
                linear,
                asset,
                defaults.batchCreateWithDurations(),
                defaults.permit2Params(defaults.TOTAL_TRANSFER_AMOUNT())
            )
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256[]));
    }

    function batchCreateWithMilestones() internal returns (uint256[] memory) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithMilestones,
            (
                dynamic,
                asset,
                defaults.batchCreateWithMilestones(),
                defaults.permit2Params(defaults.TOTAL_TRANSFER_AMOUNT())
            )
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256[]));
    }

    function batchCreateWithMilestones(uint256 batchSize) internal returns (uint256[] memory) {
        uint128 totalTransferAmount = uint128(batchSize) * defaults.PER_STREAM_AMOUNT();
        bytes memory data = abi.encodeCall(
            target.batchCreateWithMilestones,
            (dynamic, asset, defaults.batchCreateWithMilestones(batchSize), defaults.permit2Params(totalTransferAmount))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256[]));
    }

    function batchCreateWithRange() internal returns (uint256[] memory) {
        bytes memory data = abi.encodeCall(
            target.batchCreateWithRange,
            (linear, asset, defaults.batchCreateWithRange(), defaults.permit2Params(defaults.TOTAL_TRANSFER_AMOUNT()))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256[]));
    }

    function batchCreateWithRange(uint256 batchSize) internal returns (uint256[] memory) {
        uint128 totalTransferAmount = uint128(batchSize) * defaults.PER_STREAM_AMOUNT();
        bytes memory data = abi.encodeCall(
            target.batchCreateWithRange,
            (linear, asset, defaults.batchCreateWithRange(batchSize), defaults.permit2Params(totalTransferAmount))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256[]));
    }

    function createWithDeltas() internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            target.createWithDeltas,
            (dynamic, defaults.createWithDeltas(), defaults.permit2Params(defaults.PER_STREAM_AMOUNT()))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256));
    }

    function createWithDurations() internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            target.createWithDurations,
            (linear, defaults.createWithDurations(), defaults.permit2Params(defaults.PER_STREAM_AMOUNT()))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256));
    }

    function createWithMilestones() internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            target.createWithMilestones,
            (dynamic, defaults.createWithMilestones(), defaults.permit2Params(defaults.PER_STREAM_AMOUNT()))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256));
    }

    function createWithRange() internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            target.createWithRange,
            (linear, defaults.createWithRange(), defaults.permit2Params(defaults.PER_STREAM_AMOUNT()))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256));
    }

    function createWithRange(LockupLinear.CreateWithRange memory params) internal returns (uint256) {
        bytes memory data = abi.encodeCall(
            target.createWithRange, (linear, params, defaults.permit2Params(defaults.PER_STREAM_AMOUNT()))
        );
        bytes memory response = proxy.execute(address(target), data);
        return abi.decode(response, (uint256));
    }
}
