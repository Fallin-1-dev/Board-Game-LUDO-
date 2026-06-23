//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {Ludo} from "src/Ludo.sol";

contract TestLudoCoverage is Test {
    Ludo public ludo;

    address public player1 = address(0x1);
    address public player2 = address(0x2);
    address public player3 = address(0x3);
    address public player4 = address(0x4);
    address public player5 = address(0x5);

    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        ludo = new Ludo();
        vm.deal(player1, STARTING_BALANCE);
        vm.deal(player2, STARTING_BALANCE);
        vm.deal(player3, STARTING_BALANCE);
        vm.deal(player4, STARTING_BALANCE);
        vm.deal(player5, STARTING_BALANCE);
    }

    // ========== CONSTRUCTOR & getStakeValue TESTS ==========

    function testConstructorInitializesTierStakes() public view {
        assertEq(ludo.getStakeValue(Ludo.StakeTier.Standard), 0.1 ether);
        assertEq(ludo.getStakeValue(Ludo.StakeTier.Medium), 0.3 ether);
        assertEq(ludo.getStakeValue(Ludo.StakeTier.Big), 0.5 ether);
        assertEq(ludo.getStakeValue(Ludo.StakeTier.Pro), 0.7 ether);
        assertEq(ludo.getStakeValue(Ludo.StakeTier.Heavy), 1 ether);
        assertEq(ludo.getStakeValue(Ludo.StakeTier.Giant), 3 ether);
        assertEq(ludo.getStakeValue(Ludo.StakeTier.Boss), 5 ether);
    }

    function testConstructorSetsPoolStartTime() public view {
        assertGt(ludo.poolStartTime(), 0);
    }

    function testMaxPlayersConstant() public view {
        assertEq(ludo.MAX_PLAYERS(), 4);
    }

    function testMinStakeConstant() public view {
        assertEq(ludo.MIN_STAKE(), 0.1 ether);
    }

    function testMaxStakeConstant() public view {
        assertEq(ludo.MAX_STAKE(), 5 ether);
    }

    function testStartDelayConstant() public view {
        assertEq(ludo.START_DELAY(), 5);
    }

    // ========== joinGame ERROR PATH TESTS ==========

    function testJoinGameRevertsIfAlreadyInPool() public {
        vm.startPrank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.expectRevert(Ludo.Ludo__AlreadyInGameOrWaiting.selector);
        ludo.joinGame{value: 0.3 ether}(Ludo.StakeTier.Medium);
        vm.stopPrank();
    }

    function testJoinGameRevertsIfPoolFull() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.prank(player2);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.prank(player3);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.prank(player4);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.prank(player5);
        vm.expectRevert(Ludo.Ludo__PoolFull.selector);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
    }

    function testJoinGameRevertsIfWrongStakeAmount() public {
        vm.prank(player1);
        vm.expectRevert(Ludo.Ludo__StakeOutOfRange.selector);
        ludo.joinGame{value: 0.2 ether}(Ludo.StakeTier.Standard);
    }

    function testJoinGameRevertsIfZeroStake() public {
        vm.prank(player1);
        vm.expectRevert(Ludo.Ludo__StakeOutOfRange.selector);
        ludo.joinGame{value: 0}(Ludo.StakeTier.Standard);
    }

    function testJoinGameSetsPoolStartTimeOnFirstPlayer() public {
        uint256 joinTime = 1000;
        vm.warp(joinTime);

        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        assertEq(ludo.poolStartTime(), joinTime);
    }

    function testJoinGameDoesNotResetPoolStartTimeForSubsequentPlayers() public {
        uint256 firstJoinTime = 1000;
        vm.warp(firstJoinTime);
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.warp(firstJoinTime + 100);
        vm.prank(player2);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        assertEq(ludo.poolStartTime(), firstJoinTime);
    }

    function testJoinGameEmitsPlayerJoinedEvent() public {
        vm.prank(player1);
        vm.expectEmit(true, false, false, true);
        emit Ludo.PlayerJoined(player1, 0.1 ether);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
    }

    function testJoinGameEmitsPoolLockedWhenFull() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.prank(player2);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.prank(player3);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.prank(player4);
        vm.expectEmit(false, false, false, true);
        emit Ludo.PoolLocked(Ludo.StakeTier.Standard);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
    }

    function testJoinGameSetsInWaitingPoolTrue() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        assertTrue(ludo.inWaitingPool(player1));
    }

    // ========== leaveGame TESTS ==========

    function testLeaveGameSuccess() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.5 ether}(Ludo.StakeTier.Big);
        vm.prank(player2);
        ludo.joinGame{value: 0.5 ether}(Ludo.StakeTier.Big);

        uint256 balanceBefore = player1.balance;

        vm.prank(player1);
        ludo.leaveGame(Ludo.StakeTier.Big);

        assertEq(player1.balance, balanceBefore + 0.5 ether);
        assertFalse(ludo.inWaitingPool(player1));
    }

    function testLeaveGameRevertsIfNotInWaitingPool() public {
        vm.prank(player1);
        vm.expectRevert(Ludo.Ludo__NotInWaitingPool.selector);
        ludo.leaveGame(Ludo.StakeTier.Standard);
    }

    function testLeaveGameRevertsIfOnlyOnePlayerInPool() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.prank(player1);
        vm.expectRevert("Cannot leave pool with only 1 player");
        ludo.leaveGame(Ludo.StakeTier.Standard);
    }

    function testLeaveGameEmitsPlayerLeftEvent() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.3 ether}(Ludo.StakeTier.Medium);
        vm.prank(player2);
        ludo.joinGame{value: 0.3 ether}(Ludo.StakeTier.Medium);

        vm.prank(player1);
        vm.expectEmit(true, false, false, true);
        emit Ludo.PlayerLeft(player1, 0.3 ether, true);
        ludo.leaveGame(Ludo.StakeTier.Medium);
    }

    function testLeaveGameLastPlayerInPoolCanLeave() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.7 ether}(Ludo.StakeTier.Pro);
        vm.prank(player2);
        ludo.joinGame{value: 0.7 ether}(Ludo.StakeTier.Pro);
        vm.prank(player3);
        ludo.joinGame{value: 0.7 ether}(Ludo.StakeTier.Pro);

        uint256 balanceBefore = player3.balance;

        vm.prank(player3);
        ludo.leaveGame(Ludo.StakeTier.Pro);

        assertEq(player3.balance, balanceBefore + 0.7 ether);
        assertFalse(ludo.inWaitingPool(player3));
    }

    function testLeaveGameMiddlePlayerCanLeave() public {
        vm.prank(player1);
        ludo.joinGame{value: 1 ether}(Ludo.StakeTier.Heavy);
        vm.prank(player2);
        ludo.joinGame{value: 1 ether}(Ludo.StakeTier.Heavy);
        vm.prank(player3);
        ludo.joinGame{value: 1 ether}(Ludo.StakeTier.Heavy);

        uint256 balanceBefore = player2.balance;

        vm.prank(player2);
        ludo.leaveGame(Ludo.StakeTier.Heavy);

        assertEq(player2.balance, balanceBefore + 1 ether);
        assertFalse(ludo.inWaitingPool(player2));
    }

    function testLeaveGamePlayerNotInSpecificTierReverts() public {
        // Player joins Standard tier but tries to leave Big tier
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        // Player2 also joins Big to have > 1 player in Big pool
        vm.prank(player2);
        ludo.joinGame{value: 0.5 ether}(Ludo.StakeTier.Big);
        vm.prank(player3);
        ludo.joinGame{value: 0.5 ether}(Ludo.StakeTier.Big);

        // Player1 is in waiting pool (Standard) but not in the Big pool
        // The function checks inWaitingPool first (passes) then iterates pool
        // Since player1 is not in Big pool, it should revert with PlayerNotInGame
        vm.prank(player1);
        vm.expectRevert(Ludo.Ludo__PlayerNotInGame.selector);
        ludo.leaveGame(Ludo.StakeTier.Big);
    }

    function testLeaveGameRefundFailureReverts() public {
        // Deploy a contract that rejects ETH to test refund failure
        RejectEther rejecter = new RejectEther();
        vm.deal(address(rejecter), STARTING_BALANCE);

        // Join with rejecter and another player
        vm.prank(address(rejecter));
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        // Now rejecter tries to leave - refund will fail
        vm.prank(address(rejecter));
        vm.expectRevert(Ludo.Ludo__RefundFailed.selector);
        ludo.leaveGame(Ludo.StakeTier.Standard);
    }

    // ========== cleanupStalePool TESTS ==========

    function testCleanupStalePoolReturnsEarlyIfEmpty() public {
        // Pool is empty, function should just return without reverting
        ludo.cleanupStalePool(Ludo.StakeTier.Standard);
        // No revert means it passed the empty check
    }

    function testCleanupStalePoolReturnsEarlyIfNotStaleYet() public {
        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        // Advance time but less than 10 minutes
        vm.warp(block.timestamp + 5 minutes);

        ludo.cleanupStalePool(Ludo.StakeTier.Standard);
        // Pool should still exist - player still in waiting
        assertTrue(ludo.inWaitingPool(player1));
    }

    function testCleanupStalePoolRefundsAfter10Minutes() public {
        vm.warp(1000);

        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        uint256 balanceBefore = player1.balance;

        // Advance time past 10 minutes
        vm.warp(1000 + 11 minutes);

        ludo.cleanupStalePool(Ludo.StakeTier.Standard);

        assertEq(player1.balance, balanceBefore + 0.1 ether);
        assertFalse(ludo.inWaitingPool(player1));
    }

    function testCleanupStalePoolRefundsMultiplePlayers() public {
        vm.warp(1000);

        vm.prank(player1);
        ludo.joinGame{value: 3 ether}(Ludo.StakeTier.Giant);
        vm.prank(player2);
        ludo.joinGame{value: 3 ether}(Ludo.StakeTier.Giant);
        vm.prank(player3);
        ludo.joinGame{value: 3 ether}(Ludo.StakeTier.Giant);

        uint256 balance1Before = player1.balance;
        uint256 balance2Before = player2.balance;
        uint256 balance3Before = player3.balance;

        vm.warp(1000 + 11 minutes);

        ludo.cleanupStalePool(Ludo.StakeTier.Giant);

        assertEq(player1.balance, balance1Before + 3 ether);
        assertEq(player2.balance, balance2Before + 3 ether);
        assertEq(player3.balance, balance3Before + 3 ether);
        assertFalse(ludo.inWaitingPool(player1));
        assertFalse(ludo.inWaitingPool(player2));
        assertFalse(ludo.inWaitingPool(player3));
    }

    function testCleanupStalePoolResetsPoolStartTime() public {
        vm.warp(1000);

        vm.prank(player1);
        ludo.joinGame{value: 0.5 ether}(Ludo.StakeTier.Big);

        vm.warp(1000 + 11 minutes);

        ludo.cleanupStalePool(Ludo.StakeTier.Big);

        assertEq(ludo.poolStartTime(), 0);
    }

    function testCleanupStalePoolEmitsPlayerLeftEvent() public {
        vm.warp(1000);

        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.warp(1000 + 11 minutes);

        vm.expectEmit(true, false, false, true);
        emit Ludo.PlayerLeft(player1, 0.1 ether, true);
        ludo.cleanupStalePool(Ludo.StakeTier.Standard);
    }

    function testCleanupStalePoolRevertsIfRefundFails() public {
        RejectEther rejecter = new RejectEther();
        vm.deal(address(rejecter), STARTING_BALANCE);

        vm.warp(1000);

        vm.prank(address(rejecter));
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        vm.warp(1000 + 11 minutes);

        vm.expectRevert(Ludo.Ludo__RefundFailed.selector);
        ludo.cleanupStalePool(Ludo.StakeTier.Standard);
    }

    function testCleanupStalePoolExactly10MinutesDoesClear() public {
        vm.warp(1000);

        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        // Exactly 10 minutes: condition is `< start + 10 minutes`, so at 10 min it passes
        vm.warp(1000 + 10 minutes);

        ludo.cleanupStalePool(Ludo.StakeTier.Standard);
        assertFalse(ludo.inWaitingPool(player1));
    }

    function testCleanupStalePoolJustBefore10MinutesDoesNotClean() public {
        vm.warp(1000);

        vm.prank(player1);
        ludo.joinGame{value: 0.1 ether}(Ludo.StakeTier.Standard);

        // 1 second before 10 minutes - should NOT clean
        vm.warp(1000 + 10 minutes - 1);

        ludo.cleanupStalePool(Ludo.StakeTier.Standard);
        assertTrue(ludo.inWaitingPool(player1));
    }

    function testCleanupStalePoolDeletesWaitingPool() public {
        vm.warp(1000);

        vm.prank(player1);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
        vm.prank(player2);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);

        vm.warp(1000 + 11 minutes);

        ludo.cleanupStalePool(Ludo.StakeTier.Boss);

        // After cleanup, a new player should be able to join
        vm.prank(player3);
        ludo.joinGame{value: 5 ether}(Ludo.StakeTier.Boss);
        assertTrue(ludo.inWaitingPool(player3));
    }
}

// Helper contract that rejects ETH transfers (for testing refund failures)
contract RejectEther {
    receive() external payable {
        revert("I reject ether");
    }

    fallback() external payable {
        revert("I reject ether");
    }
}
