// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {OBRouter} from "contracts/OBRouter.sol";
import {console} from "forge-std/console.sol";

contract RegisterReferral is Script {
    // use
    // forge script script/deployRouter.s.sol --broadcast --account <walletName>

    function run() external {
        vm.createSelectFork("bartio");

        vm.startBroadcast();
        address payable routerAddress = payable(0x014e37443C5112E4312F04Ce9eC60f600c46e71b);

        OBRouter router = OBRouter(routerAddress);

        uint32 referralCode = (1 << 31) + 1; // 2147483648 + 1 = 2147483649
        uint64 referralFee = 0.00069 * 1 ether;
        // 0.15%
        // 0.069% = 0.00069

        router.registerReferralCode(referralCode, referralFee, routerAddress);

        vm.stopBroadcast();
    }
}
