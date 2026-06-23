//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console2} from "forge-std/Script.sol";

contract TestLudoHelper is Script {
    address[] public Players;

    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant NUM_PLAYERS = 4;

    function generatePlayers() public returns (address[] memory) {
        for (uint256 i = 0; i < NUM_PLAYERS; i++) {
            address newPlayer = _generateAddress(i);
            Players.push(newPlayer);
        }
        return Players;
    }

    function _generateAddress(uint256 seed) internal view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(seed, block.timestamp)))));
    }

    function getPlayers() external view returns (address[] memory) {
        return Players;
    }
}
