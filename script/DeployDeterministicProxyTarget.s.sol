// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19 <=0.9.0;

import { BaseScript } from "@sablier/v2-core-script/shared/Base.s.sol";
import { IAllowanceTransfer } from "permit2/interfaces/IAllowanceTransfer.sol";

import { SablierV2ProxyTarget } from "../src/SablierV2ProxyTarget.sol";

/// @notice Deploys {SablierV2ProxyTarget} at a deterministic address across chains.
/// @dev Reverts if the contract has already been deployed.
contract DeployDeterministicProxyTarget is BaseScript {
    /// @dev The presence of the salt instructs Forge to deploy contracts via this deterministic CREATE2 factory:
    /// https://github.com/Arachnid/deterministic-deployment-proxy
    function run(IAllowanceTransfer permit2) public virtual broadcaster returns (SablierV2ProxyTarget proxyTarget) {
        proxyTarget = new SablierV2ProxyTarget{ salt: ZERO_SALT }(permit2);
    }
}