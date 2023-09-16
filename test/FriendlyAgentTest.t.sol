// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FriendlyAgent, IFriendtechSharesV1} from "../../src/FriendlyAgent.sol";
import {DeployFriendlyAgent} from "../../script/DeployFriendlyAgent.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("MockToken", "MT") {
        _mint(msg.sender, initialSupply);
    }
}

contract FriendlyAgentTest is Test {
    DeployFriendlyAgent deployFriendlyAgent;
    FriendlyAgent friendlyAgent;

    uint256 constant STARTING_BALANCE = 10 ether;
    address ALICE = makeAddr("alice"); // Owner
    address BOB = makeAddr("bob"); // Not Owner
    IFriendtechSharesV1 friendtechShares;
    HelperConfig helperConfig;
    MockToken mockToken;

    function setUp() external {
        helperConfig = new HelperConfig();

        vm.startBroadcast(ALICE);
        friendlyAgent = new FriendlyAgent(helperConfig.friendsTechAddress());
        mockToken = new MockToken(100);
        vm.stopBroadcast();

        friendtechShares = friendlyAgent.i_friendtechShares();
        vm.deal(ALICE, STARTING_BALANCE);
        vm.deal(BOB, STARTING_BALANCE);
    }

    modifier setupShares() {
        // Need to buy 1 share to get over arithmetic over/underflow
        uint256 priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 1);

        vm.prank(ALICE);
        friendtechShares.buyShares{value: priceAfterFee}(ALICE, 1);

        priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 4);

        vm.prank(ALICE);
        friendtechShares.buyShares{value: priceAfterFee}(ALICE, 4);
        _;
    }

    // Testing owner functionality

    function testOwnerCanBuy() public setupShares {
        uint256 priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 1);

        vm.prank(ALICE);
        friendlyAgent.buyShares{value: priceAfterFee}(priceAfterFee + 10, 1, ALICE);
        assert(friendlyAgent.getHoldings(ALICE) == 1);
    }

    function testOwnerCantBuyOverLimit() public setupShares {
        uint256 priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 1);

        vm.prank(ALICE);
        vm.expectRevert(FriendlyAgent.FriendlyAgent__OverMaxLimit.selector);
        friendlyAgent.buyShares{value: priceAfterFee}(priceAfterFee - 10, 1, ALICE);
    }

    function testOwnerCanSell() public setupShares {
        uint256 priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 1);

        vm.prank(ALICE);
        friendlyAgent.buyShares{value: priceAfterFee}(priceAfterFee + 10, 1, ALICE);
        assert(friendlyAgent.getHoldings(ALICE) == 1);

        priceAfterFee = friendtechShares.getSellPriceAfterFee(ALICE, 1);
        assert(address(friendlyAgent).balance == 0);

        vm.prank(ALICE);
        friendlyAgent.sellShares(priceAfterFee - 10, 1, ALICE);
        assert(address(friendlyAgent).balance != 0);
    }

    function testOwnerCantSellUnderLimit() public setupShares {
        uint256 priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 1);

        vm.prank(ALICE);
        friendlyAgent.buyShares{value: priceAfterFee}(priceAfterFee + 10, 1, ALICE);
        assert(friendlyAgent.getHoldings(ALICE) == 1);

        priceAfterFee = friendtechShares.getSellPriceAfterFee(ALICE, 1);
        assert(address(friendlyAgent).balance == 0);

        vm.prank(ALICE);
        vm.expectRevert(FriendlyAgent.FriendlyAgent__UnderMinLimit.selector);
        friendlyAgent.sellShares(priceAfterFee + 10, 1, ALICE);
    }

    function testOwnerCanWithdraw() public {
        vm.prank(ALICE);
        payable(address(friendlyAgent)).transfer(5 ether);
        uint256 aliceBalance = ALICE.balance;

        assert(aliceBalance == 5 ether);

        vm.prank(ALICE);
        friendlyAgent.withdraw();

        assert(aliceBalance == 5 ether);
    }

    function testOwnerCanWithdrawToken() public {
        vm.prank(ALICE);
        mockToken.transfer(address(friendlyAgent), 10);

        assert(mockToken.balanceOf(address(friendlyAgent)) == 10);
        assert(mockToken.balanceOf(address(ALICE)) == 90);

        vm.prank(ALICE);
        friendlyAgent.withdrawToken(address(mockToken));

        assert(mockToken.balanceOf(address(friendlyAgent)) == 0);
        assert(mockToken.balanceOf(ALICE) == 100);
    }

    // Test non owners reverts

    function testNonOwnerCantBuy() public setupShares {
        uint256 priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 1);

        vm.prank(BOB);
        vm.expectRevert(FriendlyAgent.FriendlyAgent__NotOwner.selector);
        friendlyAgent.buyShares{value: priceAfterFee}(priceAfterFee + 10, 1, ALICE);
    }

    function testOwnerCantSell() public setupShares {
        uint256 priceAfterFee = friendtechShares.getBuyPriceAfterFee(ALICE, 1);

        vm.prank(ALICE);
        friendlyAgent.buyShares{value: priceAfterFee}(priceAfterFee + 10, 1, ALICE);
        assert(friendlyAgent.getHoldings(ALICE) == 1);

        priceAfterFee = friendtechShares.getSellPriceAfterFee(ALICE, 1);
        assert(address(friendlyAgent).balance == 0);

        vm.prank(BOB);
        vm.expectRevert(FriendlyAgent.FriendlyAgent__NotOwner.selector);
        friendlyAgent.sellShares(priceAfterFee - 10, 1, ALICE);
    }

    function testNonOwnerCantWithdraw() public setupShares {
        vm.prank(BOB);
        payable(address(friendlyAgent)).transfer(1 ether);

        vm.prank(BOB);
        vm.expectRevert(FriendlyAgent.FriendlyAgent__NotOwner.selector);
        friendlyAgent.withdraw();
    }

    function testNonOwnerCantWithdrawToken() public {
        vm.prank(ALICE);
        mockToken.transfer(address(friendlyAgent), 10);

        assert(mockToken.balanceOf(address(friendlyAgent)) == 10);

        vm.prank(BOB);
        vm.expectRevert(FriendlyAgent.FriendlyAgent__NotOwner.selector);
        friendlyAgent.withdrawToken(address(mockToken));
    }
}
