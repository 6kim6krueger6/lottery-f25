//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig,Constants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script {

    function createSubscriptionUsingConfig() public returns (uint256,address) {
        HelperConfig helperConfig = new HelperConfig(); // создали контракт HelperConfig
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; 
        // передали в переменную адрес VRFCoordinator
        address account = helperConfig.getConfig().account; // передали в переменную адрес аккаунта
        (uint256 subId,) = createSubscription(vrfCoordinator, account ); 
        // вызвали функцию createSubscription, куда передали адрес VRFCoordinator, вернули ID подписки
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256,address) {
        console.log("Creating subscription on chainID: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();// получили ID подписки
        vm.stopBroadcast();
        console.log("Subscription ID: ", subId);
        console.log("Please update the subscription ID in HelperConfig.s.sol");
        return (subId, vrfCoordinator);
    }

    function run() public{
        createSubscriptionUsingConfig(); // задеплоили контракт
    }

}

contract FundSubscription is Script, Constants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig(); //новый контракт HelperConfig
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;//получили адрес VRFCoordinator
        uint256 subId = helperConfig.getConfig().subId;// получили ID подписки
        address  linkToken = helperConfig.getConfig().link;// получили адрес LINK
        address account = helperConfig.getConfig().account; // получили адрес аккаунта
        fundSubscription(vrfCoordinator,subId,linkToken, account);//"запихнули" данные в функцию fundSubscription
    }

    function fundSubscription(address vrfCoordinator,uint256 subId,address linkToken, address account) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("Using CHAIN ID: ", block.chainid);

        if(block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId,FUND_AMOUNT);
            // Вызвали мок контракт, т.к мы на локальной сети
            vm.stopBroadcast();
        }else{
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subId));
            // Если нет, то вызываем функцию transferAndCall, которая переводит LINK на адрес VRFCoordinator
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address vrfCoordinator,address contractToAddToVRF,uint256 subId, address account) public {
        console.log("Adding consumer contract: ", contractToAddToVRF);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("Using CHAIN ID: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId,contractToAddToVRF);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subID = helperConfig.getConfig().subId; // получили ID подписки
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; // получили адрес VRFCoordinator
        address account = helperConfig.getConfig().account; // получили адрес аккаунта
        addConsumer(vrfCoordinator,mostRecentlyDeployed,subID,account); // передали данные в функцию addConsumer
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        // получили адрес самого последнего контракта Raffle
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}