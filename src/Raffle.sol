//SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
pragma solidity ^0.8.0;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from"@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();
    error Raffle__TransferFailed();
    error Raffle__NotEnoughTimePassed();

    enum RaffleState { //состояния лотереи
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1; //количество чисел в запросе
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint256 private immutable i_subId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    RaffleState private s_raffleState;
    address private s_recentWinner;

    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = _keyHash;
        i_subId = _subId;
        i_callbackGasLimit = _callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) revert Raffle__SendMoreToEnterRaffle();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();

        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */ ) //проверка на соответствие требованиям
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

        if (block.timestamp - s_lastTimeStamp < i_interval) revert Raffle__NotEnoughTimePassed();
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) revert Raffle__TransferFailed();
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index]; 
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
    
     function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

}


