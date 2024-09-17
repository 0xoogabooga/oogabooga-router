// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {OBRouter} from "contracts/OBRouter.sol";
import {IOBRouter} from "contracts/interfaces/IOBRouter.sol";
import {OnlyApproved} from "contracts/OnlyApproved.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TokenHelper} from "contracts/TokenHelper.sol";

import {TestHelpers} from "test/utils/TestHelpers.sol";
import {WETH9} from "test/mock/WETH9.sol";

/// @title Withdrawal Tests of the OBRouter contract
/// @author @WuBruno
/// @dev Tests related to the withdrawing process of funds from the OBRouter
contract OBRouterTransferRouterFundsTest is Test, TestHelpers {
    OBRouter router;

    address immutable owner = makeAddr("OWNER");
    address immutable authorized = makeAddr("OWNER");
    WETH9 weth;
    address immutable attacker = makeAddr("ATTACKER");

    function setUp() external {
        weth = new WETH9();
        router = new OBRouter(owner, address(weth));
        vm.prank(owner);
        router.addApprovedAddress(authorized);
    }

    function test_RevertWhenInvalidArguments() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        address recipient = makeAddr("RECIPIENT");

        // Act
        vm.prank(authorized);
        vm.expectRevert(IOBRouter.InvalidRouterFundsTransfer.selector);
        router.transferRouterFunds(tokens, amounts, recipient);
    }

    function test_nativeTransferAutomaticallyWraps() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = TokenHelper.NATIVE_TOKEN;
        amounts[0] = 1 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), amounts[0]);

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(address(weth), recipient), amounts[0]);
        assertEq(universalBalanceOf(address(weth), address(router)), 0);
        assertEq(universalBalanceOf(tokens[0], recipient), 0);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_RevertTransferMoreThanNativeBalance() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = TokenHelper.NATIVE_TOKEN;
        amounts[0] = 1 ether;
        uint256 balance = 0.4 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), balance);

        // Act
        vm.prank(authorized);
        // Generic revert as it is running out of funds
        vm.expectRevert();
        router.transferRouterFunds(tokens, amounts, recipient);
    }

    function test_RevertTransferMoreThanERC20Balance() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;
        uint256 balance = 0.4 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), balance);

        // Act
        vm.prank(authorized);
        // Generic revert as it is running out of funds
        vm.expectRevert();
        router.transferRouterFunds(tokens, amounts, recipient);
    }

    function test_nativeTransferAll() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = TokenHelper.NATIVE_TOKEN;
        amounts[0] = 0;
        uint256 balance = 1 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), balance);

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(address(weth), recipient), balance);
        assertEq(universalBalanceOf(address(weth), address(router)), 0);
        assertEq(universalBalanceOf(tokens[0], recipient), 0);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_ERC20TransferAll() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 0;
        uint256 balance = 1 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), balance);

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(tokens[0], recipient), balance);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_transferNone() external {
        // Arrange
        address[] memory tokens = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        address recipient = makeAddr("RECIPIENT");

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);
    }

    function test_nativeTransferAllWhenZeroBalance() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = TokenHelper.NATIVE_TOKEN;
        amounts[0] = 0;

        address recipient = makeAddr("RECIPIENT");

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(address(weth), recipient), 0);
        assertEq(universalBalanceOf(address(weth), address(router)), 0);
        assertEq(universalBalanceOf(tokens[0], recipient), 0);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_erc20TransferAllWhenZeroBalance() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 0;

        address recipient = makeAddr("RECIPIENT");

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(tokens[0], recipient), 0);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_ERC20Transfer() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), amounts[0]);

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(tokens[0], recipient), amounts[0]);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_multiTokenTransfer() external {
        // Arrange
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = TokenHelper.NATIVE_TOKEN;
        amounts[0] = 1 ether;
        tokens[1] = address(weth);
        amounts[1] = 2 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), amounts[0]);
        universalDeal(tokens[1], address(router), amounts[1]);

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(tokens[1], recipient), amounts[0] + amounts[1]);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
        assertEq(universalBalanceOf(tokens[1], address(router)), 0);
    }

    function test_splitNativeTokenTransfer() external {
        // Arrange
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        tokens[0] = TokenHelper.NATIVE_TOKEN;
        amounts[0] = 1 ether;
        tokens[1] = TokenHelper.NATIVE_TOKEN;
        amounts[1] = 2 ether;
        tokens[2] = tokens[0];
        amounts[2] = 0 ether;
        uint256 balance = 3.5 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), balance);

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(address(weth), recipient), balance);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_splitERC20TokenTransfer() external {
        // Arrange
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;
        tokens[1] = tokens[0];
        amounts[1] = 2 ether;
        tokens[2] = tokens[0];
        amounts[2] = 0 ether;
        uint256 balance = 3.5 ether;

        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), balance);

        // Act
        vm.prank(authorized);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(tokens[0], recipient), balance);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }
}
