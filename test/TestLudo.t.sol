//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2} from "forge-std/Test.sol";
import {TestBase} from "./utils/TestBase.sol";
import {Ludo} from "src/Ludo.sol";

contract RejectEther {
    receive() external payable {
        revert("no ETH");
    }
}

contract TestLudo is TestBase {
    constructor() {
        _setupPlayers();
    }

    function setUp() public {
        _deployLudo();
        _fundPlayers();
    }

    function testJoinGame() public {
        _joinPlayersToTier(0, 4, Ludo.StakeTier.Boss, 5 ether);
        console2.log("BossTierPool is full");

        _joinPlayersToTier(4, 4, Ludo.StakeTier.Giant, 3 ether);
        console2.log("GiantTierPool is full");

        _joinPlayersToTier(8, 4, Ludo.StakeTier.Heavy, 1 ether);
        console2.log("HeavyTierPool is full");

        _joinPlayersToTier(12, 4, Ludo.StakeTier.Pro, 0.7 ether);
        console2.log("ProTierPool is full");

        _joinPlayersToTier(16, 4, Ludo.StakeTier.Big, 0.5 ether);
        console2.log("BigTierPool is full");

        _joinPlayersToTier(20, 4, Ludo.StakeTier.Medium, 0.3 ether);
        console2.log("MediumTierPool is full");

        _joinPlayersToTier(24, 4, Ludo.StakeTier.Standard, 0.1 ether);
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
