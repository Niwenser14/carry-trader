// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CarryTrader
/// @notice Ledger for net carry attribution across a fixed set of legs; used by settlement scripts to reconcile desk PnL.
/// @dev Only the configured operator may append carry ticks; no transfers or claims—reconciliation feed with snapshots and per-leg views.
contract CarryTrader {
    /// @dev Operator allowed to push carry ticks; set at deployment.
    address public immutable operator;

    /// @dev Block at deployment; used for carry-per-block rate.
    uint256 public immutable deploymentBlock;

    /// @dev Domain tag so multiple deployments on the same chain do not share namespace.
    uint256 private constant LEG_SEED = 0x1b3f7e9c4d6a2f8e0c5b9d1a7f3e6c8b2d4a0f;

    /// @dev Cumulative net carry in basis-point-like units (scaled by 1e8 for precision).
    int256 public netCarryBps;

    /// @dev Number of ticks applied so far (monotonic counter for off-chain sync).
    uint256 public tickCount;

    /// @dev Block at which the last tick was applied.
    uint256 public lastTickBlock;

    /// @dev Per-leg cumulative carry (basis-point scale).
    mapping(bytes32 legId => int256) public legCarryBps;
