//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
//import {TestLudoHelper} from "../script/TestLudoHelper.s.sol";
import {Ludo} from "../src/Ludo.sol";

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
        vm.startPrank (players[i]);
        ludo.joinGame {value: 5 ether}(Ludo.StakeTier.Boss);
        vm.stopPrank ();
    }

        console2.log ("BossTierPool is full");

    for (uint256 i = 4; i < 8; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 3 ether}(Ludo.StakeTier.Giant);
        vm.stopPrank ();
    }
   
        console2.log ("GiantTierPool is full");

    for (uint256 i = 8; i < 12; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 1 ether}(Ludo.StakeTier.Heavy);
        vm.stopPrank ();
    }

        console2.log ("HeavyTierPool is full");

    for (uint256 i = 12; i < 16; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.7 ether}(Ludo.StakeTier.Pro);
        vm.stopPrank ();
    }

        console2.log ("ProTierPool is full");

    for (uint256 i = 16; i < 20; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.5 ether}(Ludo.StakeTier.Big);
        vm.stopPrank ();
    }

        console2.log ("BigTierPool is full");

    for (uint256 i = 20; i < 24; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.3 ether}(Ludo.StakeTier.Medium);
        vm.stopPrank ();
    }

        console2.log ("MediumTierPool is full");

    for (uint256 i = 24; i < 28; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.1 ether}(Ludo.StakeTier.Standard);
        vm.stopPrank ();
    }

        console2.log ("StandardTierPool is full");

    for (uint256 i = 28; i < 32; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.07 ether}(Ludo.StakeTier.Plus);
        vm.stopPrank ();
    }

        console2.log ("PlusTierPool is full");

    for (uint256 i = 32; i < 36; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.05 ether}(Ludo.StakeTier.Normal);
        vm.stopPrank ();
    }

        console2.log ("NormalTierPool is full");

    for (uint256 i = 36; i < 40; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.03 ether}(Ludo.StakeTier.Small);
        vm.stopPrank ();
    }

        console2.log ("SmallTierPool is full");

    for (uint256 i = 40; i < 44; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.01 ether}(Ludo.StakeTier.Tiny);
        vm.stopPrank ();
    }

        console2.log ("TinyTierPool is full");

    for (uint256 i = 44; i < 48; i++) {
        vm.startPrank (players[i]);
        ludo.joinGame {value: 0.01 ether}(Ludo.StakeTier.Tiny);
        vm.stopPrank ();
    }

        console2.log ("TinyTierPool is full");
}


}


