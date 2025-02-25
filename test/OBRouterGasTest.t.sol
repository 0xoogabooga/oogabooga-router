// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {IOBExecutor} from "contracts/interfaces/IOBExecutor.sol";
import {OBRouter} from "contracts/OBRouter.sol";
import {IOBRouter} from "contracts/interfaces/IOBRouter.sol";
import {TokenHelper} from "contracts/TokenHelper.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {TestHelpers} from "test/utils/TestHelpers.sol";
import {ISignatureTransfer} from "test/mock/Permit2/interfaces/ISignatureTransfer.sol";
import {SignatureVerification} from "test/mock/Permit2/libraries/SignatureVerification.sol";
import {Permit2} from "test/mock/Permit2/Permit2.sol";
import {MockExecutor, DEPOSIT, WITHDRAW} from "test/mock/MockExecutor.sol";
import {WETH9} from "test/mock/WETH9.sol";

// RESULTS =>
// 1.  SWAP_NATIVE->ERC20 gas used: 118492
// 2.  SWAP_NATIVE_WRAP gas used: 94286

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

    /// Helper to measure gas usage for swap()
    function measureSwapGas(
        IOBRouter.swapTokenInfo memory tokenInfo,
        bytes memory pathDefinition,
        address executorAddr,
        uint32 referralCode,
        uint256 valueToSend,
        string memory label
    ) internal returns (uint256 gasUsed) {
        uint256 gasStart = gasleft();
        router.swap{value: valueToSend}(tokenInfo, pathDefinition, executorAddr, referralCode);
        gasUsed = gasStart - gasleft();
        console.log("%s gas used:", label, gasUsed);
    }

    // Test: Swap from native deposit → ERC20 output.
    function test_Gas_Swap_NativeToERC20() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: NATIVE_TOKEN,
            inputAmount: 100 ether,
            outputToken: address(weth),
            outputQuote: 100 ether,
            outputMin: 99 ether,
            outputReceiver: sender
        });
        universalDeal(NATIVE_TOKEN, sender, tokenInfo.inputAmount);
        bytes memory pathDefinition = abi.encode(DEPOSIT, tokenInfo.inputAmount);
        measureSwapGas(tokenInfo, pathDefinition, address(mockExecutor), 0, tokenInfo.inputAmount, "SWAP_NATIVE->ERC20");
    }

    // Test: Swap from native deposit → ERC20 output.
    function test_Gas_Swap_NativeWrap() external {
        IOBRouter.swapTokenInfo memory tokenInfo = IOBRouter.swapTokenInfo({
            inputToken: address(weth),
            inputAmount: 1 ether,
            outputToken: NATIVE_TOKEN,
            outputQuote: 1 ether,
            outputMin: 1 ether,
            outputReceiver: sender
        });
        universalDeal(address(tokenInfo.inputToken), sender, tokenInfo.inputAmount);
        universalDeal(address(tokenInfo.outputToken), address(weth), tokenInfo.inputAmount);

        vm.startPrank(sender);
        weth.approve(address(router), tokenInfo.inputAmount);

        bytes memory pathDefinition = abi.encode(WITHDRAW, tokenInfo.inputAmount);
        measureSwapGas(tokenInfo, pathDefinition, address(mockExecutor), 0, 0, "SWAP_NATIVE_WRAP");
    }
}
