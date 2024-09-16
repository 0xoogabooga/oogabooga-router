// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

interface IOBExecutor {
    /// @notice Processes the route generated off-chain. Has a lock
    /// @param route Encoded call path
    function executePath(bytes calldata route) external payable;
}
