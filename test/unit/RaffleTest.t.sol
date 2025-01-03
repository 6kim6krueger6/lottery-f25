//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Constants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, Constants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {//настройка среды тестирования
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        subId = config.subId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);//изменение времени для перехода в состояние CALCULATING
        vm.roll(block.number + 1);// менеям блок, чтобы сработала функция performUpkeep
        raffle.performUpkeep("");// переход в состояние CALCULATING

        //пытаемся войти в раффл, происходит реверт т.к состояние CALCULATING
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    //testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed
    //testCheckUpkeepReturnsTrueWhenParametersAreGood

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);

    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance+=entranceFee;
        numPlayers++;

        vm.expectRevert(abi.encodeWithSelector(
            Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState
            ));
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if(block.chainid != LOCAL_CHAIN_ID) return;
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed{
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // получаем логи в массив 
        bytes32 requestId = entries[1].topics[1]; // получаем requestId из логов

        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(rState) == 1 );
        assert(uint256(requestId) > 0);
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public 
    raffleEnteredAndTimePassed{
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork{
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++){
            address player = address(uint160(i));
            hoax(player, 1 ether); //дает 1 эфир игроку
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // получаем логи в массив
        bytes32 requestId = entries[1].topics[1]; // получаем requestId из логов
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState rState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(rState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimestamp);
    }
}
