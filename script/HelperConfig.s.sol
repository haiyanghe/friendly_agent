// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FriendtechSharesV1} from "../src/FriendtechSharesV1.sol";

contract HelperConfig is Script {
    address public friendsTechAddress;

    constructor() {
        if (block.chainid == 8453) {
            friendsTechAddress = getBaseMainnet();
        } else {
            friendsTechAddress = getOrCreateAnvilConfig();
        }
    }

    function getOrCreateAnvilConfig() public returns (address) {
        if (friendsTechAddress != address(0)) {
            return friendsTechAddress;
        }

        vm.startBroadcast();
        FriendtechSharesV1 friendTechSharesV1 = new FriendtechSharesV1();
        friendTechSharesV1.setSubjectFeePercent(0);
        friendTechSharesV1.setProtocolFeePercent(0);

        // Set to burn address for tests
        friendTechSharesV1.setFeeDestination(0x0000000000000000000000000000000000000000);
        vm.stopBroadcast();

        return address(friendTechSharesV1);
    }

    function getBaseMainnet() public pure returns (address) {
        return 0xCF205808Ed36593aa40a44F10c7f7C2F67d4A4d4;
    }
}
