// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import {IEIP712} from "../interfaces/IEIP712.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";

interface IPermit2 is ISignatureTransfer, IEIP712 {}
