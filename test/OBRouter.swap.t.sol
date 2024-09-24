// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {IOBExecutor} from "contracts/interfaces/IOBExecutor.sol";
import {OBRouter} from "contracts/OBRouter.sol";
import {IOBRouter} from "contracts/interfaces/IOBRouter.sol";
import {TokenHelper} from "contracts/TokenHelper.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {TestHelpers} from "test/utils/TestHelpers.sol";
import {ISignatureTransfer} from "test/mock/Permit2/interfaces/ISignatureTransfer.sol";
import {SignatureVerification} from "test/mock/Permit2/libraries/SignatureVerification.sol";
import {Permit2} from "test/mock/Permit2/Permit2.sol";
import {MockExecutor, DEPOSIT, WITHDRAW} from "test/mock/MockExecutor.sol";
import {WETH9} from "test/mock/WETH9.sol";

contract OBRouterSwapTest is Test, TestHelpers {
    IOBExecutor mockExecutor;
    OBRouter router;

    address immutable owner = makeAddr("OWNER");
    WETH9 weth;
    address immutable sender = makeAddr("SENDER");

    address WETH_ADDRESS = address(weth);
    address immutable NATIVE_TOKEN = TokenHelper.NATIVE_TOKEN;

    function setUp() external {
        weth = new WETH9();
        router = new OBRouter(owner, address(weth));
        mockExecutor = new MockExecutor(address(weth));
    }

    function verifySenderAndRecipientBalance(IOBRouter.swapTokenInfo memory tokenInfo, address from, bool isSuccess)
        private
    {
        if (isSuccess) {
            assertGe(
                universalBalanceOf(tokenInfo.outputToken, tokenInfo.outputReceiver),
                tokenInfo.outputMin,
                "Receiver receives greater than outputMin"
            );
            assertLe(
                universalBalanceOf(tokenInfo.outputToken, tokenInfo.outputReceiver),
                tokenInfo.outputQuote,
                "Receiver receives less than outputQuote"
            );
            if (from != tokenInfo.outputReceiver) {
                assertEq(universalBalanceOf(tokenInfo.inputToken, from), 0, "Sender balance of input token is 0");
            }
        } else {
            assertEq(
                universalBalanceOf(tokenInfo.inputToken, from),
                tokenInfo.inputAmount,
                "Sender balance of input token remains the same"
            );
            if (tokenInfo.outputToken != tokenInfo.inputToken) {
                assertEq(
                    universalBalanceOf(tokenInfo.outputToken, from), 0, "Sender balance of outputToken remains the same"
                );
            }
        }
    }

    function test_pause_whenOwner() external {
        // Act
        vm.prank(owner);
        router.pause();

        // Assert
        assertTrue(router.paused());
    }

    function test_RevertNativeDepositValueMismatch() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });
        uint256 sendAmount = 0.5 ether;

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.startPrank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(IOBRouter.NativeDepositValueMismatch.selector, tokenInfo.inputAmount, sendAmount)
        );
        router.swap{value: sendAmount}(tokenInfo, "", address(mockExecutor), 0);

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_RevertMinimumOutputGreaterThanQuote() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 0.9 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.startPrank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOBRouter.MinimumOutputGreaterThanQuote.selector, tokenInfo.outputMin, tokenInfo.outputQuote
            )
        );
        router.swap{value: tokenInfo.inputAmount}(tokenInfo, "", address(mockExecutor), 0);

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_RevertSameTokenInAndOut() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.startPrank(sender);
        weth.approve(address(router), tokenInfo.inputAmount);

        vm.expectRevert(abi.encodeWithSelector(IOBRouter.SameTokenInAndOut.selector, tokenInfo.inputToken));
        router.swap(tokenInfo, "", address(mockExecutor), 0);

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_RevertMinimumOutputIsZero() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: TokenHelper.NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 0 ether,
            outputReceiver: sender
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.startPrank(sender);
        weth.approve(address(router), tokenInfo.inputAmount);

        vm.expectRevert(IOBRouter.MinimumOutputIsZero.selector);
        router.swap(tokenInfo, "", address(mockExecutor), 0);

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_RevertSlippageExceeded() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });
        uint256 actualAmountDeposited = 0.5 ether;

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.prank(sender);
        vm.expectRevert(
            abi.encodeWithSelector(IOBRouter.SlippageExceeded.selector, actualAmountDeposited, tokenInfo.outputMin)
        );
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, actualAmountDeposited), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_RevertInvalidNativeValueDepositOnERC20Swap() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: TokenHelper.NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);
        universalDeal(address(tokenInfo.outputToken), address(weth), tokenInfo.inputAmount);
        // Amount necessary to deposit upon swap
        universalDeal(TOkenHelper.NATIVE_TOKEN, sender, tokenInfo.inputAmount);

        // Act
        vm.startPrank(sender);
        weth.approve(address(router), tokenInfo.inputAmount);
        vm.expectRevert(abi.encodeWithSelector(IOBRouter.InvalidNativeValueDepositOnERC20Swap.selector));
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(WITHDRAW, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
    }

    function test_RevertWhenPaused() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        // Arrange
        vm.prank(owner);
        router.pause();

        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.prank(sender);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_SwapNativeToERC20() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.prank(sender);
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
    }

    function test_SwapERC20ToNative() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: TokenHelper.NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);
        // WETH contract needs to have weth before it can send out
        universalDeal(address(tokenInfo.outputToken), address(weth), tokenInfo.inputAmount);

        // Act
        vm.startPrank(sender);
        weth.approve(address(router), tokenInfo.inputAmount);

        router.swap(tokenInfo, abi.encode(WITHDRAW, tokenInfo.inputAmount), address(mockExecutor), 0);

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
    }

    function test_SwapDifferentReceiver() external {
        address receiver = makeAddr("RECEIVER");
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: receiver
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.startPrank(sender);

        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
    }

    function test_SwapMaxAmount_NativeToERC20() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 0,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });
        uint256 balance = 1 ether;

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, balance);

        // Act
        vm.prank(sender);
        router.swap{value: balance}(tokenInfo, abi.encode(DEPOSIT, balance), address(mockExecutor), 0);

        // Assert
        tokenInfo.inputAmount = balance;
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
    }

    function test_SwapMaxAmount_ERC20ToNative() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 0,
            outputToken: TokenHelper.NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });
        uint256 balance = 1 ether;

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, balance);
        universalDeal(address(tokenInfo.outputToken), address(weth), balance);

        // Act
        vm.startPrank(sender);
        weth.approve(address(router), balance);

        router.swap(tokenInfo, abi.encode(WITHDRAW, balance), address(mockExecutor), 0);

        // Assert
        tokenInfo.inputAmount = balance;
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
    }

    function test_SwapPositiveSlippage() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 0.9 ether,
            outputMin: 0.8 ether,
            outputReceiver: sender
        });

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.prank(sender);
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
        assertEq(
            universalBalanceOf(tokenInfo.outputToken, sender)
                + universalBalanceOf(tokenInfo.outputToken, address(router)),
            tokenInfo.inputAmount,
            "Positive slippage + amounts received is equal to total output (=inputAmount)"
        );
    }

    function test_SwapReferralFee_ExternalBeneficiary() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD() + 1);
        // 1% fee
        uint64 referralFee = 0.01 ether;
        address beneficiary = makeAddr("BENEFICIARY");

        vm.prank(owner);
        router.registerReferralCode(referralCode, referralFee, beneficiary);

        uint256 amountReceivedAfterFee = 1 ether - 0.01 ether;

        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: amountReceivedAfterFee,
            outputMin: amountReceivedAfterFee,
            outputReceiver: sender
        });

        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.prank(sender);
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), referralCode
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
        assertEq(universalBalanceOf(tokenInfo.outputToken, address(router)), 0.002 ether);
        assertEq(universalBalanceOf(tokenInfo.outputToken, beneficiary), 0.008 ether);
        assertEq(
            universalBalanceOf(tokenInfo.outputToken, sender)
                + universalBalanceOf(tokenInfo.outputToken, address(router))
                + universalBalanceOf(tokenInfo.outputToken, beneficiary),
            tokenInfo.inputAmount,
            "Invariant that total output is equal to inputAmount wrapping/unwrapping"
        );
    }

    function test_SwapReferralFee_BeneficiaryIsSelf() external {
        // Arrange
        uint32 referralCode = uint32(router.REFERRAL_WITH_FEE_THRESHOLD() + 1);
        // 1% fee
        uint64 referralFee = 0.01 ether;
        address beneficiary = address(router);

        vm.prank(owner);
        router.registerReferralCode(referralCode, referralFee, beneficiary);

        uint256 amountReceivedAfterFee = 1 ether - 0.01 ether;

        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: amountReceivedAfterFee,
            outputMin: amountReceivedAfterFee,
            outputReceiver: sender
        });

        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);

        // Act
        vm.prank(sender);
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), referralCode
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, true);
        assertEq(universalBalanceOf(tokenInfo.outputToken, address(router)), 0.01 ether);
        assertEq(
            universalBalanceOf(tokenInfo.outputToken, sender)
                + universalBalanceOf(tokenInfo.outputToken, address(router)),
            tokenInfo.inputAmount,
            "Invariant that total output is equal to inputAmount wrapping/unwrapping"
        );
    }

    function test_RevertInsuficientBalance() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: TokenHelper.NATIVE_TOKEN,
            inputAmount: 1 ether,
            outputToken: address(weth),
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });
        uint256 balance = 0.9 ether;

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, balance);

        // Act
        vm.prank(sender);
        vm.expectRevert();
        router.swap{value: tokenInfo.inputAmount}(
            tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        tokenInfo.inputAmount = balance;
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_RevertInsuficientERC20Approval() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: TokenHelper.NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });
        uint256 approveAmount = 0.9 ether;

        // Arrange
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);
        // Approved amount is less than inputAmount
        weth.approve(address(router), approveAmount);

        // Act
        vm.prank(sender);
        vm.expectRevert();
        router.swap(tokenInfo, abi.encode(DEPOSIT, tokenInfo.inputAmount), address(mockExecutor), 0);

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, sender, false);
    }

    function test_SwapPermit2() external {
        // Arrange
        Permit2 permit2 = new Permit2();
        VmSafe.Wallet memory senderWallet = vm.createWallet("SENDER_WALLET");

        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: TokenHelper.NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        ISignatureTransfer.PermitTransferFrom memory permitInfo = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: tokenInfo.inputToken, amount: tokenInfo.inputAmount}),
            nonce: 0,
            deadline: block.timestamp + 1
        });

        bytes memory signature =
            signPermit2Signature(permit2.DOMAIN_SEPARATOR(), permitInfo, address(router), senderWallet);

        IOBRouter.permit2Info memory permit2Info = IOBRouter.permit2Info({
            contractAddress: address(permit2),
            nonce: permitInfo.nonce,
            deadline: permitInfo.deadline,
            signature: signature
        });

        // Set addresses with correct balance
        universalDeal(tokenInfo.inputToken, senderWallet.addr, tokenInfo.inputAmount);
        universalDeal(tokenInfo.outputToken, address(weth), tokenInfo.outputQuote);

        // Act
        vm.startPrank(senderWallet.addr);
        weth.approve(address(permit2), tokenInfo.inputAmount);

        router.swapPermit2(
            permit2Info, tokenInfo, abi.encode(WITHDRAW, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, senderWallet.addr, true);
    }

    function test_SwapPermit2RevertBadSignature() external {
        // Arrange
        Permit2 permit2 = new Permit2();
        VmSafe.Wallet memory senderWallet = vm.createWallet("SENDER_WALLET");
        VmSafe.Wallet memory attackerWallet = vm.createWallet("ATTACKER_WALLET");

        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: TokenHelper.NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });

        ISignatureTransfer.PermitTransferFrom memory permitInfo = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: tokenInfo.inputToken, amount: tokenInfo.inputAmount}),
            nonce: 0,
            deadline: block.timestamp + 1
        });

        bytes memory signature =
            signPermit2Signature(permit2.DOMAIN_SEPARATOR(), permitInfo, address(router), attackerWallet);

        IOBRouter.permit2Info memory permit2Info = IOBRouter.permit2Info({
            contractAddress: address(permit2),
            nonce: permitInfo.nonce,
            deadline: permitInfo.deadline,
            signature: signature
        });

        // Set contracts with the correct amounts
        universalDeal(tokenInfo.inputToken, senderWallet.addr, tokenInfo.inputAmount);
        universalDeal(tokenInfo.outputToken, address(weth), tokenInfo.outputQuote);

        // Act
        vm.startPrank(senderWallet.addr);
        weth.approve(address(permit2), tokenInfo.inputAmount);

        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        router.swapPermit2(
            permit2Info, tokenInfo, abi.encode(WITHDRAW, tokenInfo.inputAmount), address(mockExecutor), 0
        );

        // Assert
        verifySenderAndRecipientBalance(tokenInfo, senderWallet.addr, false);
    }
}
