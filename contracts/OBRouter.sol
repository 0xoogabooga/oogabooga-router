// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {ISignatureTransfer} from "contracts/interfaces/ISignatureTransfer.sol";
import {IOBExecutor} from "contracts/interfaces/IOBExecutor.sol";
import {IOBRouter} from "contracts/interfaces/IOBRouter.sol";

import {TokenHelper} from "contracts/TokenHelper.sol";
import {OnlyApproved} from "contracts/OnlyApproved.sol";
import {IWETH} from "contracts/interfaces/IWETH.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title Routing contract for Ooga Booga SOR
/// @notice Wrapper with security gaurantees around execution of arbitrary operations on user tokens
contract OBRouter is Ownable, Pausable, IOBRouter, OnlyApproved {
    using SafeERC20 for IERC20;
    using TokenHelper for address;

    // @dev constants for managing referrals and fees
    uint256 public constant REFERRAL_WITH_FEE_THRESHOLD = 1 << 31;
    uint256 public constant FEE_DENOM = 1e18;
    address public immutable WETH;

    /// @dev Register referral fee and information
    mapping(uint32 => referralInfo) public referralLookup;

    /// @dev Set the null referralCode as "Unregistered" with no additional fee
    constructor(address _owner, address _weth) Ownable(_owner) {
        referralLookup[0].referralFee = 0;
        referralLookup[0].beneficiary = address(0);
        referralLookup[0].registered = true;
        WETH = _weth;
        _addApprovedAddress(_owner);
    }

    /// @dev Must exist in order for contract to receive eth
    receive() external payable {}

    /// @dev Pause swap restricted to the owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpause swap restricted to the owner
    function unpaused() external onlyOwner {
        _unpause();
    }

    /// @notice Externally facing interface for swapping two tokens
    /// @param tokenInfo All information about the tokens being swapped
    /// @param pathDefinition Encoded path definition for executor
    /// @param executor Address of contract that will execute the path
    /// @param referralCode referral code to specify the source of the swap
    function swap(swapTokenInfo memory tokenInfo, bytes calldata pathDefinition, address executor, uint32 referralCode)
        external
        payable
        whenNotPaused
        returns (uint256 amountOut)
    {
        return _swapApproval(tokenInfo, pathDefinition, executor, referralCode);
    }

    /// @notice Internal function for initiating approval transfers
    /// @param tokenInfo All information about the tokens being swapped
    /// @param pathDefinition Encoded path definition for executor
    /// @param executor Address of contract that will execute the path
    /// @param referralCode referral code to specify the source of the swap
    function _swapApproval(
        swapTokenInfo memory tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) internal returns (uint256 amountOut) {
        if (tokenInfo.inputToken == TokenHelper.NATIVE_TOKEN) {
            // Support rebasing tokens by allowing the user to trade the entire balance
            if (tokenInfo.inputAmount == 0) {
                tokenInfo.inputAmount = msg.value;
            } else {
                require(
                    msg.value == tokenInfo.inputAmount, NativeDepositValueMismatch(tokenInfo.inputAmount, msg.value)
                );
            }
        } else {
            // Support rebasing tokens by allowing the user to trade the entire balance
            if (tokenInfo.inputAmount == 0) {
                tokenInfo.inputAmount = IERC20(tokenInfo.inputToken).balanceOf(msg.sender);
            }
            IERC20(tokenInfo.inputToken).safeTransferFrom(msg.sender, executor, tokenInfo.inputAmount);
        }
        return _swap(tokenInfo, pathDefinition, executor, referralCode);
    }

    /// @notice Externally facing interface for swapping two tokens
    /// @param permit2 All additional info for Permit2 transfers
    /// @param tokenInfo All information about the tokens being swapped
    /// @param pathDefinition Encoded path definition for executor
    /// @param executor Address of contract that will execute the path
    /// @param referralCode referral code to specify the source of the swap
    function swapPermit2(
        permit2Info calldata permit2,
        swapTokenInfo calldata tokenInfo,
        bytes calldata pathDefinition,
        address executor,
        uint32 referralCode
    ) external whenNotPaused returns (uint256 amountOut) {
        ISignatureTransfer(permit2.contractAddress).permitTransferFrom(
            ISignatureTransfer.PermitTransferFrom(
                ISignatureTransfer.TokenPermissions(tokenInfo.inputToken, tokenInfo.inputAmount),
                permit2.nonce,
                permit2.deadline
            ),
            ISignatureTransfer.SignatureTransferDetails(executor, tokenInfo.inputAmount),
            msg.sender,
            permit2.signature
        );
        return _swap(tokenInfo, pathDefinition, executor, referralCode);
    }

    /// @notice contains the main logic for swapping one token for another
    /// Assumes input tokens have already been sent to their destinations and
    /// that msg.value is set to expected ETH input value, or 0 for ERC20 input
    /// @param tokenInfo All information about the tokens being swapped
    /// @param pathDefinition Encoded path definition for executor
    /// @param executor Address of contract that will execute the path
    /// @param referralCode referral code to specify the source of the swap
    function _swap(swapTokenInfo memory tokenInfo, bytes calldata pathDefinition, address executor, uint32 referralCode)
        internal
        returns (uint256 amountOut)
    {
        // Check for valid output specifications
        require(
            tokenInfo.outputMin <= tokenInfo.outputQuote,
            MinimumOutputGreaterThanQuote(tokenInfo.outputMin, tokenInfo.outputQuote)
        );
        require(tokenInfo.outputMin > 0, MinimumOutputIsZero());
        require(tokenInfo.inputToken != tokenInfo.outputToken, SameTokenInAndOut(tokenInfo.inputToken));

        uint256 balanceBefore = tokenInfo.outputToken.universalBalance();

        IOBExecutor(executor).executePath{value: msg.value}(pathDefinition);

        amountOut = tokenInfo.outputToken.universalBalance() - balanceBefore;

        if (referralCode > REFERRAL_WITH_FEE_THRESHOLD) {
            referralInfo memory thisReferralInfo = referralLookup[referralCode];

            if (thisReferralInfo.beneficiary != address(this)) {
                tokenInfo.outputToken.universalTransfer(
                    thisReferralInfo.beneficiary, amountOut * thisReferralInfo.referralFee * 8 / (FEE_DENOM * 10)
                );
            }

            // Takes the fees and keeps them in this contract
            amountOut = amountOut * (FEE_DENOM - thisReferralInfo.referralFee) / FEE_DENOM;
        }
        int256 slippage = int256(amountOut) - int256(tokenInfo.outputQuote);
        if (slippage > 0) {
            amountOut = tokenInfo.outputQuote;
        }
        require(amountOut >= tokenInfo.outputMin, SlippageExceeded(amountOut, tokenInfo.outputMin));

        // Transfer out the final output to the end user
        tokenInfo.outputToken.universalTransfer(tokenInfo.outputReceiver, amountOut);

        emit Swap(
            msg.sender,
            tokenInfo.inputAmount,
            tokenInfo.inputToken,
            amountOut,
            tokenInfo.outputToken,
            slippage,
            referralCode,
            tokenInfo.outputReceiver
        );
    }

    /// @notice Register a new referrer, optionally with an additional swap fee
    /// @param _referralCode the referral code to use for the new referral
    /// @param _referralFee the additional fee to add to each swap using this code
    /// @param _beneficiary the address to send the referral's share of fees to
    function registerReferralCode(uint32 _referralCode, uint64 _referralFee, address _beneficiary) external onlyOwner {
        // Do not allow for any overwriting of referral codes
        require(!referralLookup[_referralCode].registered, ReferralCodeInUse(_referralCode));

        // Maximum additional fee a referral can set is 2%
        require(_referralFee <= FEE_DENOM / 50, FeeTooHigh(_referralFee));

        // Reserve the lower half of referral codes to be informative only
        if (_referralCode <= REFERRAL_WITH_FEE_THRESHOLD) {
            require(_referralFee == 0, InvalidFeeForCode(_referralFee));
        } else {
            require(_referralFee > 0, InvalidFeeForCode(_referralFee));

            // Make sure the beneficiary is not the null address if there is a fee
            require(_beneficiary != address(0), NullBeneficiary());
        }
        referralLookup[_referralCode].referralFee = _referralFee;
        referralLookup[_referralCode].beneficiary = _beneficiary;
        referralLookup[_referralCode].registered = true;
    }

    /// @notice Allows the owner to assign approved addresses to withdraw fees
    /// @param _address the address to add to the approved list
    function addApprovedAddress(address _address) external onlyOwner {
        _addApprovedAddress(_address);
    }

    /// @notice Allows the owner to remove approved addresses from withdraw fees
    /// @param _address the address to remove from the approved list
    function removeApprovedAddress(address _address) external onlyOwner {
        _removeApprovedAddress(_address);
    }

    /// @notice Allows the owner to transfer funds held by the router contract
    /// @param tokens List of token address to be transferred
    /// @param amounts List of amounts of each token to be transferred
    /// @param dest Address to which the funds should be sent
    function transferRouterFunds(address[] calldata tokens, uint256[] calldata amounts, address dest)
        external
        onlyApproved
    {
        require(tokens.length == amounts.length, InvalidRouterFundsTransfer());
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == TokenHelper.NATIVE_TOKEN) {
                uint256 amount = amounts[i] == 0 ? tokens[i].universalBalance() : amounts[i];
                IWETH(WETH).deposit{value: amount}();
                IERC20(WETH).safeTransfer(dest, amount);
            } else {
                IERC20(tokens[i]).safeTransfer(dest, amounts[i] == 0 ? tokens[i].universalBalance() : amounts[i]);
            }
        }
    }
}
