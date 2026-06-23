//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {Ludo} from "src/Ludo.sol";

contract RejectEther {
    receive() external payable {
        revert("no ETH");
    }
}

contract TestLudo is Test {
    Ludo public ludo;
    address[] public players;
    uint256 public playersNum = 100;

    constructor() {
        players = new address[](playersNum);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = address(uint160(i + 1)); // Assign unique addresses
        }
    }

    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        ludo = new Ludo();
        for (uint256 i = 0; i < players.length; i++) {
            vm.deal(players[i], STARTING_BALANCE); // Fund each player with 10 ether
        }
    }

    function testJoinGame() public {
        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
            vm.stopPrank();
        }

        console2.log("BossTierPool is full");

        for (uint256 i = 4; i < 8; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: 3 ether}(Ludo.StakeTier.Giant);
            vm.stopPrank();
        }

        console2.log("GiantTierPool is full");

        for (uint256 i = 8; i < 12; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: 1 ether}(Ludo.StakeTier.Heavy);
            vm.stopPrank();
        }

        console2.log("HeavyTierPool is full");

        for (uint256 i = 12; i < 16; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: 0.7 ether}(Ludo.StakeTier.Pro);
            vm.stopPrank();
        }

        console2.log("ProTierPool is full");

        for (uint256 i = 16; i < 20; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: 0.5 ether}(Ludo.StakeTier.Big);
            vm.stopPrank();
        }

        console2.log("BigTierPool is full");

        for (uint256 i = 20; i < 24; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: 0.3 ether}(Ludo.StakeTier.Medium);
            vm.stopPrank();
        }

        console2.log("MediumTierPool is full");

        for (uint256 i = 24; i < 28; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
            vm.stopPrank();
        }

        console2.log("StandardTierPool is full");
    }

    // ========== leaveGame error handling ==========

    function testLeaveGameRevertsIfNotInPool() public {
        vm.startPrank(players[0]);
        vm.expectRevert(Ludo.Ludo__NotInWaitingPool.selector);
        ludo.leaveGame(Ludo.StakeTier.Boss);
        vm.stopPrank();
    }

    function testLeaveGameRevertsOnWrongTier() public {
        vm.startPrank(players[0]);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
        vm.expectRevert(Ludo.Ludo__WrongTier.selector);
        ludo.leaveGame(Ludo.StakeTier.Standard);
        vm.stopPrank();
    }

    function testLeaveGameSoloPlayer() public {
        vm.startPrank(players[0]);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);

        uint256 balanceBefore = players[0].balance;
        ludo.leaveGame(Ludo.StakeTier.Boss);
        uint256 balanceAfter = players[0].balance;

        assertEq(balanceAfter - balanceBefore, 5 ether);
        assertFalse(ludo.inWaitingPool(players[0]));
        vm.stopPrank();
    }

    function testLeaveGameRefund() public {
        vm.prank(players[0]);
        ludo.joinGame{value: 1 ether}(Ludo.StakeTier.Heavy);

        vm.prank(players[1]);
        ludo.joinGame{value: 1 ether}(Ludo.StakeTier.Heavy);

        uint256 balBefore = players[0].balance;
        vm.prank(players[0]);
        ludo.leaveGame(Ludo.StakeTier.Heavy);
        uint256 balAfter = players[0].balance;

        assertEq(balAfter - balBefore, 1 ether);
        assertFalse(ludo.inWaitingPool(players[0]));
    }

    // ========== cleanupStalePool error handling ==========

    function testCleanupRevertsOnEmptyPool() public {
        vm.expectRevert(Ludo.Ludo__PoolEmpty.selector);
        ludo.cleanupStalePool(Ludo.StakeTier.Boss);
    }

    function testCleanupRevertsIfNotStale() public {
        vm.prank(players[0]);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);

        vm.expectRevert(Ludo.Ludo__PoolNotStale.selector);
        ludo.cleanupStalePool(Ludo.StakeTier.Boss);
    }

    function testCleanupStalePoolRefundsAll() public {
        vm.prank(players[0]);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.prank(players[1]);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.warp(block.timestamp + 11 minutes);

        uint256 bal0 = players[0].balance;
        uint256 bal1 = players[1].balance;

        ludo.cleanupStalePool(Ludo.StakeTier.Standard);

        assertEq(players[0].balance - bal0, 0.1 ether);
        assertEq(players[1].balance - bal1, 0.1 ether);
        assertFalse(ludo.inWaitingPool(players[0]));
        assertFalse(ludo.inWaitingPool(players[1]));
    }

    function testCleanupContinuesOnRefundFailure() public {
        RejectEther rejecter = new RejectEther();
        address rejecterAddr = address(rejecter);
        vm.deal(rejecterAddr, 10 ether);

        vm.prank(rejecterAddr);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.prank(players[0]);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.warp(block.timestamp + 11 minutes);

        uint256 bal0 = players[0].balance;
        ludo.cleanupStalePool(Ludo.StakeTier.Standard);

        assertEq(players[0].balance - bal0, 0.1 ether);
        assertFalse(ludo.inWaitingPool(rejecterAddr));
        assertFalse(ludo.inWaitingPool(players[0]));
    }

    // ========== per-tier poolStartTimes ==========

    function testPerTierStartTimes() public {
        vm.prank(players[0]);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
        uint256 bossStart = ludo.poolStartTimes(Ludo.StakeTier.Boss);

        vm.warp(block.timestamp + 5 minutes);

        vm.prank(players[1]);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        uint256 standardStart = ludo.poolStartTimes(Ludo.StakeTier.Standard);

        assertGt(standardStart, bossStart);
    }

    // ========== joinGame error handling ==========

    function testJoinGameRevertsOnDuplicate() public {
        vm.startPrank(players[0]);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
        vm.expectRevert(Ludo.Ludo__AlreadyInGameOrWaiting.selector);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
        vm.stopPrank();
    }

    function testJoinGameRevertsOnWrongStake() public {
        vm.startPrank(players[0]);
        vm.expectRevert(Ludo.Ludo__StakeOutOfRange.selector);
        ludo.joinGame{value: 1 ether}(Ludo.StakeTier.Boss);
        vm.stopPrank();
    }

    function testJoinGameRevertsOnFullPool() public {
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(players[i]);
            ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
        }

        vm.prank(players[4]);
        vm.expectRevert(Ludo.Ludo__PoolFull.selector);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
    }
}
