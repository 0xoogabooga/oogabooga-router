// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

import {OBRouter} from "contracts/OBRouter.sol";
import {IOBRouter} from "contracts/interfaces/IOBRouter.sol";
import {OnlyApproved} from "contracts/OnlyApproved.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {TestHelpers} from "test/utils/TestHelpers.sol";
import {WETH9} from "test/mock/WETH9.sol";

/// @title Authorization related tests of the OBRouter contract
/// @author @WuBruno
/// @dev Tests the authorization related functions of the OBRouter contract
contract OBRouterRegisterReferralCodeTest is Test, TestHelpers {
    WETH9 weth;
    OBRouter router;

    address immutable owner = makeAddr("OWNER");

    function setUp() external {
        weth = new WETH9();
        router = new OBRouter(owner, address(weth));
    }

    function test_RevertReferralCodeInUse() external {
        // Arrange
        uint32 referralCode = 10;
        uint64 referralFee = 0;
        address beneficiary = makeAddr("BENEFICIARY");
        vm.startPrank(owner);

        router.registerReferralCode(referralCode, referralFee, beneficiary);

        // Act/Assert
        vm.expectRevert(abi.encodeWithSelector(IOBRouter.ReferralCodeInUse.selector, referralCode));
        router.registerReferralCode(referralCode, referralFee, beneficiary);
    }

    function test_RevertFeeTooHigh() external {
        // Arrange
        uint32 referralCode = 10;
        uint64 referralFee = 1 * uint64(router.FEE_DENOM());
        address beneficiary = makeAddr("BENEFICIARY");

        // Act/Assert
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IOBRouter.FeeTooHigh.selector, referralFee));
        router.registerReferralCode(referralCode, referralFee, beneficiary);
    }

    function test_RevertInvalidFeeForCode_WhenBelowThreshold() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD() - 1);
        uint64 referralFee = uint64(router.FEE_DENOM() / 50 - 10);
        address beneficiary = makeAddr("BENEFICIARY");

        // Act/Assert
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IOBRouter.InvalidFeeForCode.selector, referralFee));
        router.registerReferralCode(referralCode, referralFee, beneficiary);
    }

    function test_RevertInvalidFeeForCode_WhenAboveThreshold() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD() + 1);
        uint64 referralFee = 0;
        address beneficiary = makeAddr("BENEFICIARY");

        // Act/Assert
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IOBRouter.InvalidFeeForCode.selector, referralFee));
        router.registerReferralCode(referralCode, referralFee, beneficiary);
    }

    function test_RevertNullBeneficiary() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD() + 1);
        uint64 referralFee = uint64(router.FEE_DENOM() / 50 - 10);
        address beneficiary = address(0);

        // Act/Assert
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IOBRouter.NullBeneficiary.selector));
        router.registerReferralCode(referralCode, referralFee, beneficiary);
    }

    function test_registerCodeAboveThreshold() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD() + 1);
        uint64 referralFee = uint64(router.FEE_DENOM() / 50 - 10);
        address beneficiary = makeAddr("BENEFICIARY");

        // Act/Assert
        vm.prank(owner);
        router.registerReferralCode(referralCode, referralFee, beneficiary);

        // Assert
        (uint64 actualFee, address actualBeneficiary, bool registered) = router.referralLookup(referralCode);

        // Check that the code remains unregistered
        assertEq(referralFee, actualFee);
        assertEq(beneficiary, actualBeneficiary);
        assertTrue(registered);
    }

    function test_registerCodeBelowThreshold() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD() + 1);
        uint64 referralFee = uint64(router.FEE_DENOM() / 50 - 10);
        address beneficiary = makeAddr("BENEFICIARY");

        // Act/Assert
        vm.prank(owner);
        router.registerReferralCode(referralCode, referralFee, beneficiary);

        // Assert
        (uint64 actualFee, address actualBeneficiary, bool registered) = router.referralLookup(referralCode);

        // Check that the code remains unregistered
        assertEq(referralFee, actualFee);
        assertEq(beneficiary, actualBeneficiary);
        assertTrue(registered);
    }
}
