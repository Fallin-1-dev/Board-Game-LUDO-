//SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

/*
* @title: A Web3 version of a Nigerian game called Ludo.
* Rules are simple: It consists of 4 players who would lock in a set amount on the contract.
* After lock, they Proceed to the game where two dice, which would be used for the entiriety of the game are rolled on a board.
* Game Begin: Player 1 begins by rolling both dice. If 1 of the dice lands on 6, and the other on any number,
* he moves a piece from his set of pieces.
* But if both dice land on 6, he has a chance to roll again. Which gives the player the choice or ability to be able to play--
* 2 pieces from his set of pieces.
* If none of the dice lands on 6 for player 1, dice is automatically passed to player 2 for the same action.
* If same thing happens to player 2, dice is moved to player 3. On it goes till the one person land a 6 on atleast 1 die.
* Game Continues: When 1 person piece lands on a 6, and any other number on the second die, he starts from his side ("house")
* by moving his piece according to the total number on the dice rolled, across the board.
* After rolling and moving his piece accordingly, same player rolls the dice again for a 6 and something else.
* If no die lands on 6, the dice is passed to the next player.
* On and On it goes till every piece is cleared from the board by the players either moving their pieces in circle successfully--
* from their "house" back to their "house" or they capture other players piece along the way then the piece that captured
* would leave the game, while the captured piece would start again from the "house".
* The Pieces: After the amount has been locked and everyone proceeds to the game, each person is allocated a side on a board
* where he is allocated a set of moveable piece (4)
*
* @author: Godwin Angel
* @notice: This contract relies on ALOT of probability/randomness
* @dev: Implements Chainlink VRFv2.5
 */

contract Ludo {
    // ========== ERRORS ==========
    error Ludo__StakeOutOfRange();
    error Ludo__AlreadyInGameOrWaiting();
    error Ludo__NotInWaitingPool();
    error Ludo__RefundFailed();
    error Ludo__PlayerNotInGame();
    error Ludo__CannotLeaveAfterCountdown();
    error Ludo__NotInAnyStakePool();
    error Ludo__GameNotFound();
    error Ludo__PoolFull();
    error Ludo__PoolEmpty();
    error Ludo__PoolNotStale();
    error Ludo__WrongTier();
    error Ludo__PartialRefundFailure(address player, uint256 amount);
    error Ludo__ReentrantCall();

    // ========== ENUMS ==========
    enum StakeTier {
        Standard, // 0.1 ether
        Medium, // 0.3 ether
        Big, // 0.5 ether
        Pro, // 0.7 ether
        Heavy, // 1 ether
        Giant, // 3 ether
        Boss // 5 ether
    }
    // ========== STATE VARIABLES ==========
    address[] public players;
    bool private _locked;

    // ========== CONSTANTS ==========
    uint8 public constant MAX_PLAYERS = 4;
    uint256 public constant MIN_STAKE = 0.1 ether;
    uint256 public constant MAX_STAKE = 5 ether;
    uint256 public constant START_DELAY = 5; // seconds before game starts

    // ========== MODIFIERS ==========
    modifier nonReentrant() {
        if (_locked) revert Ludo__ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    // ========== MAPPINGS ==========

    mapping(StakeTier => uint256) public tierStakes; // tier => stake amount
    mapping(StakeTier => address[]) public waitingPools; // tier => waiting players
    mapping(address => bool) public inWaitingPool; // player => is waiting
    mapping(address => StakeTier) public playerTier; // player => tier they joined
    mapping(StakeTier => uint256) public poolStartTimes; // tier => pool start time

    // ========== EVENTS ==========
    event PlayerJoined(address indexed player, uint256 stake);
    event PlayerLeft(address indexed player, uint256 stake, bool refunded);
    event PoolLocked(StakeTier tier);
    event RefundFailed(address indexed player, uint256 amount);

    // ========== CONSTRUCTOR ==========
    constructor() {
        tierStakes[StakeTier.Standard] = 0.1 ether;
        tierStakes[StakeTier.Medium] = 0.3 ether;
        tierStakes[StakeTier.Big] = 0.5 ether;
        tierStakes[StakeTier.Pro] = 0.7 ether;
        tierStakes[StakeTier.Heavy] = 1 ether;
        tierStakes[StakeTier.Giant] = 3 ether;
        tierStakes[StakeTier.Boss] = 5 ether;
    }

    function getStakeValue(StakeTier tier) public view returns (uint256) {
        return tierStakes[tier];
    }

    // ========== JOIN GAME LOGIC ==========

    function joinGame(StakeTier tier) external payable nonReentrant {
        if (inWaitingPool[msg.sender]) revert Ludo__AlreadyInGameOrWaiting();

        if (waitingPools[tier].length >= MAX_PLAYERS) revert Ludo__PoolFull();

        uint256 stake = getStakeValue(tier);
        if (msg.value != stake) revert Ludo__StakeOutOfRange();

        waitingPools[tier].push(msg.sender);
        inWaitingPool[msg.sender] = true;
        playerTier[msg.sender] = tier;

        if (waitingPools[tier].length == 1) {
            poolStartTimes[tier] = block.timestamp;
        }
        emit PlayerJoined(msg.sender, stake);

        if (waitingPools[tier].length == MAX_PLAYERS) {
            emit PoolLocked(tier);
        }
    }

    // ========== LEAVE GAME OR POOL ==========

    function leaveGame(StakeTier tier) external nonReentrant {
        if (!inWaitingPool[msg.sender]) revert Ludo__NotInWaitingPool();
        if (playerTier[msg.sender] != tier) revert Ludo__WrongTier();

        address[] storage pool = waitingPools[tier];
        uint256 refundAmount = tierStakes[tier];
        bool found = false;

        for (uint256 i = 0; i < pool.length; i++) {
            if (pool[i] == msg.sender) {
                pool[i] = pool[pool.length - 1];
                pool.pop();
                found = true;
                break;
            }
        }

        if (!found) revert Ludo__PlayerNotInGame();

        inWaitingPool[msg.sender] = false;

        if (pool.length == 0) {
            poolStartTimes[tier] = 0;
        }

        (bool success,) = msg.sender.call{value: refundAmount}("");
        if (!success) revert Ludo__RefundFailed();

        emit PlayerLeft(msg.sender, refundAmount, true);
    }

    // ========== CLEANUP STALEPOOLS ==========
    function cleanupStalePool(StakeTier tier) external nonReentrant {
        address[] storage pool = waitingPools[tier];
        uint256 start = poolStartTimes[tier];

        if (pool.length == 0) revert Ludo__PoolEmpty();
        if (block.timestamp < start + 10 minutes) revert Ludo__PoolNotStale();

        uint256 stakeAmount = getStakeValue(tier);
        uint256 poolLen = pool.length;
        address[] memory playersToRefund = new address[](poolLen);
        for (uint256 i = 0; i < poolLen; i++) {
            playersToRefund[i] = pool[i];
            inWaitingPool[pool[i]] = false;
        }

        delete waitingPools[tier];
        poolStartTimes[tier] = 0;

        for (uint256 i = 0; i < poolLen; i++) {
            (bool success,) = playersToRefund[i].call{value: stakeAmount}("");
            if (success) {
                emit PlayerLeft(playersToRefund[i], stakeAmount, true);
            } else {
                emit RefundFailed(playersToRefund[i], stakeAmount);
            }
        }
    }

    // ========== INTERNAL UTILITIES ==========

    function _refundPlayer(address player, uint256 amount) internal {
        (bool success,) = player.call{value: amount}("");
        if (!success) revert Ludo__RefundFailed();
    }

    function _removeFromPool(address[] storage pool, address player) internal {
        for (uint256 i = 0; i < pool.length; i++) {
            if (pool[i] == player) {
                pool[i] = pool[pool.length - 1];
                pool.pop();
                inWaitingPool[player] = false;
                return;
            }
        }
        revert Ludo__PlayerNotInGame();
    }

    // ========== VIEW HELPERS ==========

    /// note: Refactor the block.timestamp
    /// Implement Interface function
}
