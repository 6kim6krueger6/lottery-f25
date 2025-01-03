//SPDX-License-Identifier: MIT

// СКРИПТ ДЛЯ ДЕПЛОЯ КОНТРАКТА С ЛОТЕРЕЕЙ

pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription,FundSubscription,AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    
    function run() external returns (Raffle, HelperConfig) {
        vm.startBroadcast(); // Начинаем транзакции
        (Raffle raffle, HelperConfig helperConfig) = deployContract(); // Вызываем deployContract
        vm.stopBroadcast(); // Останавливаем транзакции
        return (raffle, helperConfig); // Возвращаем деплоенные контракты
    }

    function deployContract() public returns (Raffle,HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // создаем переменную типа NetworkConfig с помощью которой можем обращаться к полям структуры

    if(config.subId == 0) { //создаем подписку на Chainlink VRF, если ее нет
        CreateSubscription createSubscription = new CreateSubscription(); //создали подписку
        (config.subId,config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator, config.account); 
        // передали ID и VRF
        FundSubscription fundSubscription = new FundSubscription();// создали контракт для пополнения подписки
        fundSubscription.fundSubscription(config.vrfCoordinator,config.subId,config.link,config.account);
        // вызвали функцию fundSubscription, передали адрес VRF, ID подписки и адрес LINK
     }

        // Если подписка уже есть, то пропускаем этот блок
        vm.startBroadcast(config.account); //включаем транзакции
        Raffle raffle = new Raffle( //Деплоим Рафл
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.keyHash,
            config.subId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer(); // Добавляем потребителя
        addConsumer.addConsumer(config.vrfCoordinator,address(raffle),config.subId,config.account);
        //Передаем в функцию адрес VRF, адрес контракта Раффл и ID подписки
        return (raffle, helperConfig);
    }
}