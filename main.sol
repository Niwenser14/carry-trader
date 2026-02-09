// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CarryTrader
/// @notice Ledger for net carry attribution across a fixed set of legs; used by settlement scripts to reconcile desk PnL.
/// @dev Only the configured operator may append carry ticks; no transfers or claims—reconciliation feed with snapshots and per-leg views.
contract CarryTrader {
    /// @dev Operator allowed to push carry ticks; set at deployment.
    address public immutable operator;
