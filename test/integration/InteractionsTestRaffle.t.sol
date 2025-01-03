//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription,FundSubscription,AddConsumer} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract InteractionsTestRaffle is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;


    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        helperConfig = new HelperConfig();
        (raffle, helperConfig ) = deployRaffle.run();
        config = helperConfig.getConfig();
    }

    function testCreateSubscription() public {
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId,) = createSubscription.createSubscription(config.vrfCoordinator, config.account);
        assert(subId > 0);
    }

    // function testFundSubscription() public {
    //     FundSubscription fundSubscription = new FundSubscription();
    // }
}