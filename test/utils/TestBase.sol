//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {Ludo} from "src/Ludo.sol";

/// @title Shared test utilities for Ludo tests
abstract contract TestBase is Test {
    Ludo public ludo;
    address[] public players;

    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant NUM_PLAYERS = 100;

    function _setupPlayers() internal {
        players = new address[](NUM_PLAYERS);
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            players[i] = address(uint160(i + 1));
        }
    }

    function _fundPlayers() internal {
        for (uint256 i = 0; i < players.length; i++) {
            vm.deal(players[i], STARTING_BALANCE);
        }
    }

    function _deployLudo() internal {
        ludo = new Ludo();
    }

    /// @notice Joins a batch of players to a specific tier pool
    function _joinPlayersToTier(uint256 startIdx, uint256 count, Ludo.StakeTier tier, uint256 value) internal {
        for (uint256 i = startIdx; i < startIdx + count; i++) {
            vm.startPrank(players[i]);
            ludo.joinGame{value: value}(tier);
            vm.stopPrank();
        }
    }
}
