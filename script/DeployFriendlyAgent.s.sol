// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FriendlyAgent} from "../src/FriendlyAgent.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFriendlyAgent is Script {
    function run() external returns (FriendlyAgent) {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast(ownerPrivateKey);
        FriendlyAgent friendlyAgent = new FriendlyAgent(helperConfig.friendsTechAddress());
        vm.stopBroadcast();

        return friendlyAgent;
    }
}
