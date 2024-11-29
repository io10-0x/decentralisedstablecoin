//SDPX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "../src/test/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethtokenaddress;
        address wbtcaddress;
        address wethpricefeedaddress;
        address wbtcpricefeedaddress;
    }
    NetworkConfig public activeConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeConfig = getsepoliaconfig();
        } else if (block.chainid == 31337) {
            activeConfig = getanvilconfig();
        }
    }

    function getsepoliaconfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig(
                0x16EFdA168bDe70E05CA6D349A690749d622F95e0,
                0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
                0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                0x694AA1769357215DE4FAC081bf1f309aDC325306
            );
    }

    function getanvilconfig() public returns (NetworkConfig memory) {
        uint8 decimals = 8;
        int256 wbtcinitialPrice = 9000000000000;
        int256 wethinitialPrice = 200000000000;
        vm.startBroadcast(
            0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        );
        MockV3Aggregator wbtcmockV3Aggregator = new MockV3Aggregator(
            decimals,
            wbtcinitialPrice
        );
        ERC20Mock wbtc = new ERC20Mock();
        MockV3Aggregator wethmockV3Aggregator = new MockV3Aggregator(
            decimals,
            wethinitialPrice
        );
        ERC20Mock weth = new ERC20Mock();
        vm.stopBroadcast();
        return
            NetworkConfig(
                address(weth),
                address(wbtc),
                address(wethmockV3Aggregator),
                address(wbtcmockV3Aggregator)
            );
    }
}
