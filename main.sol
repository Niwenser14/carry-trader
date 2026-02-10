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

    /// @dev Snapshots: epochId => (block number, netCarryBps at that block).
    mapping(uint256 epochId => uint256 blockNum) private _snapshotBlock;
    mapping(uint256 epochId => int256 carryBps) private _snapshotCarry;

    event CarryTick(bytes32 indexed legId, int256 deltaBps, int256 newNetCarryBps);
    event CarryTickBatch(uint256 legCount, int256 totalDeltaBps, int256 newNetCarryBps);
    event SnapshotSealed(uint256 indexed epochId, uint256 blockNum, int256 carryBps);

    constructor() {
        operator = 0x8Ba1f109551bD432803012645Ac136ddd64DBA72;
        deploymentBlock = block.number;
        lastTickBlock = block.number;
    }

    /// @notice Append a carry tick from the authorized operator; no claim or transfer.
    /// @param legId Identifier for the leg (e.g. hash of instrument + tenor).
    /// @param deltaBps Carry delta in basis-point scale (1e8 = one "unit").
    function pushCarry(bytes32 legId, int256 deltaBps) external {
        require(msg.sender == operator, "CarryTrader: not operator");
        netCarryBps += deltaBps;
        legCarryBps[legId] += deltaBps;
        tickCount++;
        lastTickBlock = block.number;
        emit CarryTick(legId, deltaBps, netCarryBps);
    }

    /// @notice Append multiple carry ticks in one call; same authorization as pushCarry.
    /// @param legIds Leg identifiers.
    /// @param deltaBps Carry deltas (same length as legIds).
    function pushCarryBatch(bytes32[] calldata legIds, int256[] calldata deltaBps) external {
        require(msg.sender == operator, "CarryTrader: not operator");
        uint256 n = legIds.length;
        require(n == deltaBps.length, "CarryTrader: length mismatch");
        int256 totalDelta;
        for (uint256 i; i < n; ) {
            bytes32 legId = legIds[i];
            int256 d = deltaBps[i];
            legCarryBps[legId] += d;
            totalDelta += d;
            unchecked { ++i; }
        }
        netCarryBps += totalDelta;
        tickCount += n;
        lastTickBlock = block.number;
