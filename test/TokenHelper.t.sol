// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {OBRouter} from "contracts/OBRouter.sol";
import {OnlyApproved} from "contracts/OnlyApproved.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TokenHelper} from "contracts/TokenHelper.sol";

import {TestHelpers} from "test/utils/TestHelpers.sol";
import {WETH9} from "test/mock/WETH9.sol";

contract TokenHelperHarness {
    using TokenHelper for address;

    function universalBalance(address token) external view returns (uint256) {
        return token.universalBalance();
    }

    function universalTransfer(address token, address to, uint256 amount) external {
        token.universalTransfer(to, amount);
    }
}

/// @title Withdrawal Tests of the OBRouter contract
/// @author @WuBruno
/// @dev Tests related to the withdrawing process of funds from the OBRouter
contract TokenHelperTest is Test, TestHelpers {
    TokenHelperHarness target;

    address immutable owner = makeAddr("OWNER");
    address immutable authorized = makeAddr("OWNER");
    WETH9 weth;
    address immutable attacker = makeAddr("ATTACKER");

    function setUp() external {
        weth = new WETH9();
        target = new TokenHelperHarness();
    }

    function test_universalBalance_erc20() external {
        // Arrange
        address token = address(weth);
        uint256 amount = 1 ether;
        universalDeal(token, address(target), amount);

        // Act
        uint256 balance = target.universalBalance(token);

        // Assert
        vm.assertEq(balance, amount);
    }

    function test_universalTransfer_erc20() external {
        // Arrange
        address token = address(weth);
        uint256 amount = 1 ether;
        universalDeal(token, address(target), amount);
        address recipient = makeAddr("RECIPIENT");

        // Act
        target.universalTransfer(token, recipient, amount);

        // Assert
        vm.assertEq(weth.balanceOf(recipient), amount);
    }

    function test_universalTransfer_RevertErc20() external {
        // Arrange
        address token = address(weth);
        uint256 amount = 1 ether;
        address recipient = makeAddr("RECIPIENT");

        // Act
        vm.expectRevert();
        target.universalTransfer(token, recipient, amount);

        // Assert
        vm.assertEq(weth.balanceOf(recipient), 0);
        vm.assertEq(weth.balanceOf(address(target)), 0);
    }

    function test_universalBalance_native() external {
        // Arrange
        address token = TokenHelper.NATIVE_TOKEN;
        uint256 amount = 1 ether;
        universalDeal(token, address(target), amount);

        // Act
        uint256 balance = target.universalBalance(token);

        // Assert
        vm.assertEq(balance, amount);
    }

    function test_universalTransfer_native() external {
        // Arrange
        address token = TokenHelper.NATIVE_TOKEN;
        uint256 amount = 1 ether;
        universalDeal(token, address(target), amount);
        address recipient = makeAddr("RECIPIENT");

        // Act
        target.universalTransfer(token, recipient, amount);

        // Assert
        vm.assertEq(address(recipient).balance, amount);
    }

    function test_universalTransfer_RevertNative() external {
        // Arrange
        address token = TokenHelper.NATIVE_TOKEN;
        uint256 amount = 1 ether;
        address recipient = makeAddr("RECIPIENT");

        // Act
        vm.expectRevert(TokenHelper.InvalidNativeTransfer.selector);
        target.universalTransfer(token, recipient, amount);

        // Assert
        vm.assertEq(address(recipient).balance, 0);
        vm.assertEq(address(target).balance, 0);
    }
}
