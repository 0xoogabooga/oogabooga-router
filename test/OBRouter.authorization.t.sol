// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {OBRouter} from "contracts/OBRouter.sol";
import {OnlyApproved} from "contracts/OnlyApproved.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TestHelpers} from "test/utils/TestHelpers.sol";
import {WETH9} from "test/mock/WETH9.sol";

/// @title Authorization related tests of the OBRouter contract
/// @author @WuBruno
/// @dev Tests the authorization related functions of the OBRouter contract
contract OBRouterAuthorizationTest is Test, TestHelpers {
    OBRouter router;

    address immutable owner = makeAddr("OWNER");
    WETH9 weth;
    address immutable attacker = makeAddr("ATTACKER");

    function setUp() external {
        weth = new WETH9();
        router = new OBRouter(owner, address(weth));
    }

    function test_pause_RevertWhenNotOwner() external {
        // Act
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        router.pause();

        // Assert
        assertFalse(router.paused());
    }

    function test_pause_whenOwner() external {
        // Act
        vm.prank(owner);
        router.pause();

        // Assert
        assertTrue(router.paused());
    }

    function test_unpause_RevertWhenNotOwner() external {
        // Arrange
        vm.prank(owner);
        router.pause();

        // Act
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        router.unpaused();

        // Assert
        assertTrue(router.paused());
    }

    function test_unpause_WhenOwner() external {
        // Arrange
        vm.prank(owner);
        router.pause();

        // Act
        vm.prank(owner);
        router.unpaused();

        // Assert
        assertFalse(router.paused());
    }

    function test_registerReferralCode_RevertWhenNotOwner() external {
        // Arrange
        uint32 referralCode = 1234;
        address beneficiary = makeAddr("BENEFICIARY");
        uint64 fee = 0;

        // Act
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        router.registerReferralCode(referralCode, fee, beneficiary);

        // Assert
        (uint64 actualFee, address actualBeneficiary, bool registered) = router.referralLookup(referralCode);

        // Check that the code remains unregistered
        assertEq(actualFee, 0);
        assertEq(actualBeneficiary, address(0));
        assertFalse(registered);
    }

    function test_registerReferralCode_WhenOwner() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD()) + 1;
        address beneficiary = makeAddr("BENEFICIARY");
        uint64 fee = 0.01 ether;

        // Act
        vm.prank(owner);
        router.registerReferralCode(referralCode, fee, beneficiary);

        // Assert
        (uint64 actualFee, address actualBeneficiary, bool registered) = router.referralLookup(referralCode);

        // Check that the code remains unregistered
        assertEq(fee, actualFee);
        assertEq(beneficiary, actualBeneficiary);
        assertTrue(registered);
    }

    function test_addApprovedAddress_RevertWhenNotOwner() external {
        // Arrange
        address approvedAddress = makeAddr("APPROVED_ADDRESS");

        // Act
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        router.addApprovedAddress(approvedAddress);

        // Assert
        assertFalse(router.isApproved(approvedAddress));
    }

    function test_addApprovedAddress_whenOwner() external {
        // Arrange
        address approvedAddress = makeAddr("APPROVED_ADDRESS");

        // Act
        vm.prank(owner);
        router.addApprovedAddress(approvedAddress);

        // Assert
        assertTrue(router.isApproved(approvedAddress));
    }

    function test_removeApprovedAddress_RevertWhenNotOwner() external {
        // Arrange
        address approvedAddress = makeAddr("APPROVED_ADDRESS");
        vm.prank(owner);
        router.addApprovedAddress(approvedAddress);

        // Act
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        router.removeApprovedAddress(approvedAddress);

        // Assert
        assertTrue(router.isApproved(approvedAddress));
    }

    function test_removeApprovedAddress_whenOwner() external {
        // Arrange
        address approvedAddress = makeAddr("APPROVED_ADDRESS");
        vm.prank(owner);
        router.addApprovedAddress(approvedAddress);

        // Act
        vm.prank(owner);
        router.removeApprovedAddress(approvedAddress);

        // Assert
        assertFalse(router.isApproved(approvedAddress));
    }

    function test_transferRouterFunds_WhenApprovedAddress() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;
        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), amounts[0]);

        // Act
        vm.prank(owner);
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(tokens[0], recipient), amounts[0]);
        assertEq(universalBalanceOf(tokens[0], address(router)), 0);
    }

    function test_transferRouterFunds_WhenNotApprovedAddress() external {
        // Arrange
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;
        address recipient = makeAddr("RECIPIENT");
        universalDeal(tokens[0], address(router), amounts[0]);

        // Act
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(OnlyApproved.NotApprovedAddress.selector, attacker));
        router.transferRouterFunds(tokens, amounts, recipient);

        // Assert
        assertEq(universalBalanceOf(tokens[0], recipient), 0);
        assertEq(universalBalanceOf(tokens[0], address(router)), amounts[0]);
    }
}
