// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TokenHelper} from "contracts/TokenHelper.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISignatureTransfer} from "test/mock/Permit2/interfaces/ISignatureTransfer.sol";
import {PermitHash} from "test/mock/Permit2/libraries/PermitHash.sol";
import {SignatureVerification} from "test/mock/Permit2/libraries/SignatureVerification.sol";

contract TestHelpers is Test {
    using PermitHash for ISignatureTransfer.PermitTransferFrom;
    using SignatureVerification for bytes;

    modifier TODO() {
        vm.skip(true);
        _;
    }

    function universalBalanceOf(address token, address owner) internal view returns (uint256) {
        if (token == TokenHelper.NATIVE_TOKEN) {
            return owner.balance;
        } else {
            return IERC20(token).balanceOf(owner);
        }
    }

    function universalDeal(address token, address recipient, uint256 amount) internal {
        if (token == TokenHelper.NATIVE_TOKEN) {
            deal(recipient, amount);
        } else {
            deal(token, recipient, amount);
        }
    }

    function signPermit2Signature(
        bytes32 permit2DomainSeparator,
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender,
        VmSafe.Wallet memory senderWallet
    ) internal pure returns (bytes memory) {
        bytes32 tokenPermissionsHash = keccak256(abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permit2DomainSeparator,
                keccak256(
                    abi.encode(
                        PermitHash._PERMIT_TRANSFER_FROM_TYPEHASH,
                        tokenPermissionsHash,
                        spender,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(senderWallet.privateKey, hash);
        return abi.encodePacked(r, s, v);
    }
}
