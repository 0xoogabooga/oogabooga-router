// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library TokenHelper {
    using SafeERC20 for IERC20;

    error InvalidNativeTransfer();

    /// @dev The zero address is uniquely used to represent native token since it is already
    /// recognized as an invalid ERC20, and due to its gas efficiency
    address constant NATIVE_TOKEN = address(0);

    /// @notice helper function to get balance of ERC20 or native coin for this contract
    /// @param token address of the token to check, null for native coin
    /// @return balance of specified coin or token
    function universalBalance(address token) internal view returns (uint256) {
        if (token == NATIVE_TOKEN) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    /// @notice helper function to transfer ERC20 or native coin
    /// @param token address of the token being transferred, null for native coin
    /// @param to address to transfer to
    /// @param amount to transfer
    function universalTransfer(address token, address to, uint256 amount) internal {
        if (token == NATIVE_TOKEN) {
            (bool success,) = payable(to).call{value: amount}("");
            require(success, InvalidNativeTransfer());
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
