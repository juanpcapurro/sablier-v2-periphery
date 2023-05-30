// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPRBProxyAnnex } from "@prb/proxy/interfaces/IPRBProxyAnnex.sol";
import { IPRBProxyRegistry } from "@prb/proxy/interfaces/IPRBProxyRegistry.sol";
import { ISablierV2LockupDynamic } from "@sablier/v2-core/interfaces/ISablierV2LockupDynamic.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/interfaces/ISablierV2LockupLinear.sol";
import { IAllowanceTransfer } from "permit2/interfaces/IAllowanceTransfer.sol";

import { IWrappedNativeAsset } from "src/interfaces/IWrappedNativeAsset.sol";

import { Defaults } from "../utils/Defaults.sol";
import { Base_Test } from "../Base.t.sol";

/// @notice Common logic needed by all fork tests.
abstract contract Fork_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    IERC20 internal immutable asset;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(IERC20 asset_) {
        asset = asset_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Fork the Goerli testnet.
        vm.createSelectFork({ blockNumber: 9_091_600, urlOrAlias: "goerli" });

        // The base is set up after the fork is selected so that the base test contracts are deployed on the fork.
        Base_Test.setUp();

        // Load the dependencies.
        loadDependencies();

        // Deploy the defaults contract.
        defaults = new Defaults(users, dai, permit2, proxy);

        // Deploy V2 Periphery.
        deployPeripheryConditionally();

        // Label the contracts.
        labelContracts();

        // Approve Permit2 to spend funds.
        approvePermit2();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Checks the user assumptions.
    function checkUsers(address user, address recipient, address proxy_) internal virtual {
        // The protocol does not allow the zero address to interact with it.
        vm.assume(user != address(0) && recipient != address(0));

        // The goal is to not have overlapping users because the asset balance tests would fail otherwise.
        vm.assume(user != recipient && user != users.broker.addr && recipient != users.broker.addr);
        vm.assume(user != address(proxy_) && recipient != address(proxy_));
        vm.assume(user != address(dynamic) && recipient != address(dynamic));
        vm.assume(user != address(linear) && recipient != address(linear));
    }

    /// @dev Loads all dependencies pre-deployed on Goerli.
    function loadDependencies() private {
        // Load WETH.
        weth = IWrappedNativeAsset(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

        // Load the proxy annex.
        proxyAnnex = IPRBProxyAnnex(0x0254C4467cBbdbe8d5E01e68de0DF7b20dD2A167);

        // Load the proxy registry.
        proxyRegistry = IPRBProxyRegistry(0xa87bc4C1Bc54E1C1B28d2dD942A094A6B665B8C9);

        // Deploy a proxy for Alice.
        proxy = proxyRegistry.deployFor(users.alice.addr);

        // Load Permit2.
        permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);

        // Load V2 Core.
        dynamic = ISablierV2LockupDynamic(0x4a57C183333a0a81300259d1795836fA0F4863BB);
        linear = ISablierV2LockupLinear(0xd78D4FE35779342d5FE2E8206d886D57139d6abB);
    }
}
