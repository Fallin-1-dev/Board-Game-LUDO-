//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";

contract TestLudoHelper is Script {
<<<<<<< HEAD
    address[] public Players;

    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant NUM_PLAYERS = 4;
=======
    address [] public Players;

    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant NUM_PLAYERS = 4;
   
>>>>>>> 70ac6495ca8ee117d2650cd82ea1600c944a0852

    // Creates and labels new unique addresses

    function generatePlayers() public {
        for (uint256 i = 0; i < 8; i++) {
            address newPlayer = address(uint160(uint256(keccak256(abi.encodePacked(i, block.timestamp)))));
            Players.push(newPlayer);
        }
    }

    function getPlayers() external view returns (address[] memory) {
        return Players;
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> 70ac6495ca8ee117d2650cd82ea1600c944a0852
