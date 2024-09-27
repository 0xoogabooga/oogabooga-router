// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

interface IOBRouter {
    /// @dev Contains all information needed to describe the input and output for a swap
    struct permit2Info {
        address contractAddress;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    /// @dev Contains all information needed to describe the input and output for a swap
    struct swapTokenInfo {
        address inputToken;
        uint256 inputAmount;
        address outputToken;
        uint256 outputQuote;
        uint256 outputMin;
        address outputReceiver;
    }

    /// @dev event for swapping one token for another
    event Swap(
        address indexed sender,
        uint256 inputAmount,
        address indexed inputToken,
        uint256 amountOut,
        address indexed outputToken,
        int256 slippage,
        uint32 referralCode,
        address to
    );

    /// @dev Holds all information for a given referral
    struct referralInfo {
        uint64 referralFee;
        address beneficiary;
        bool registered;
    }

    /// @dev throws when msg.value is not equal to swapTokenInfo.inputAmount
    error NativeDepositValueMismatch(uint256 expected, uint256 received);
    /// @dev throws when outputMin is greater than outputQuote in swap parameters
    error MinimumOutputGreaterThanQuote(uint256 outputMin, uint256 outputQuote);
    /// @dev throws when outputMin is zero
    error MinimumOutputIsZero();
    /// @dev throws when inputToken is equal to outputToken
    error SameTokenInAndOut(address token);
    /// @dev throws when outputAmount is less than outputMin
    error SlippageExceeded(uint256 amountOut, uint256 outputMin);
    /// @dev throws when trying to register an already registered referral code
    error ReferralCodeInUse(uint32 referralCode);
    /// @dev throws when fees set to referral code is too high
    error FeeTooHigh(uint64 fee);
    /// @dev throws when fee set is not accepted in the referralCode range
    error InvalidFeeForCode(uint64 fee);
    /// @dev throws when beneficiary is null when fee is set
    error NullBeneficiary();
    /// @dev throws when paramters for transferRouterFunds are invalid
    error InvalidRouterFundsTransfer();
    /// @dev throws when native value is deposited on an ERC20 swap
    error InvalidNativeValueDepositOnERC20Swap();

    /// @notice Externally facing interface for swapping two tokens
    /// @param tokenInfo All information about the tokens being swapped
    /// @param pathDefinition Encoded path definition for executor
    /// @param executor Address of contract that will execute the path
    /// @param referralCode referral code to specify the source of the swap

    function swap(swapTokenInfo memory tokenInfo, bytes calldata pathDefinition, address executor, uint32 referralCode)
        external
        payable
        returns (uint256 amountOut);

    /// @notice Externally facing interface for swapping two tokens
    /// @param permit2 All additional info for Permit2 transfers
    /// @param tokenInfo All information about the tokens being swapped
    /// @param pathDefinition Encoded path definition for executor
    /// @param executor Address of contract that will execute the path
    /// @param referralCode referral code to specify the source of the swap
    function swapPermit2(
        permit2Info memory permit2,
        swapTokenInfo memory tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external returns (uint256 amountOut);
}
