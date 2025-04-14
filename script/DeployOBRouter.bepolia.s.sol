// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {OBRouter} from "contracts/OBRouter.sol";
import {console} from "forge-std/console.sol";

contract DeployOBRouter is Script {
    // use
    // forge script script/deployRouter.s.sol --broadcast --account <walletName>

    function run() external {
        vm.createSelectFork("bepolia");
        vm.startBroadcast();
        address owner = 0x4b741204257ED68A7E0a8542eC1eA1Ac1Db829d7;
        address WETH = 0x6969696969696969696969696969696969696969;

        OBRouter router = new OBRouter{salt: "oogabooga"}(owner, WETH);
        console.log("Router address: %s", address(router));

        vm.stopBroadcast();
    }
}
