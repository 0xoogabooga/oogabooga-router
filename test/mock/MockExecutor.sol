// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.27;

import "contracts/interfaces/IWETH.sol";
import "contracts/interfaces/IOBExecutor.sol";

uint8 constant DEPOSIT = 1;
uint8 constant WITHDRAW = 2;

contract MockExecutor is IOBExecutor {
    IWETH public immutable WETH;

    // added to exclude from code coverage report
    function test() public {}

    constructor(address _weth) {
        WETH = IWETH(_weth);
    }

    receive() external payable {}

    function executePath(bytes calldata bytecode) external payable {
        (uint8 code, uint256 inputAmount) = abi.decode(bytecode, (uint8, uint256));

        if (code == DEPOSIT) {
            WETH.deposit{value: inputAmount}();
            WETH.transfer(msg.sender, inputAmount);
        } else if (code == WITHDRAW) {
            WETH.withdraw(inputAmount);
            payable(msg.sender).transfer(inputAmount);
        }
    }
}
