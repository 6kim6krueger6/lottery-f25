//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract Constants {
    uint96 public constant BASE_FEE = 0.25 ether;// стоимость каждого запроса случайного числа
    uint96 public constant GAS_PRICE_LINK = 1e9;// стоимость газа в LINK
    int256 public constant WEI_PER_UNIT_LINK = 1e18;// LINK в WEI

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Constants, Script {
    error NetworkConfigNotFound();
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }
    
    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainID => NetworkConfig) public networkConfig;

    constructor() {
        networkConfig[SEPOLIA_CHAIN_ID] = getSepoliaNetworkConfig();
    }

    function getConfigByChainId(uint256 chainID) public returns (NetworkConfig memory) {
        if(networkConfig[chainID].vrfCoordinator != address(0)) return networkConfig[chainID];
        else if (chainID == LOCAL_CHAIN_ID) return getLocalNetworkConfig();
        else revert NetworkConfigNotFound();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaNetworkConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator:0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subId: 100989143403752757787427797522328206917911361128080942187540010049546367787741,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xd149B96b9CD54F9e961E9Ab585696B7898a5b1e1
        });
    }

    function getLocalNetworkConfig() public returns (NetworkConfig memory) {
        if(localNetworkConfig.vrfCoordinator != address(0)) return localNetworkConfig;
        //Функция завершит выполнение если значения уже даны, если нет,то->
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
        BASE_FEE,
        GAS_PRICE_LINK,
        WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator:address(vrfCoordinatorMock),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
}

}