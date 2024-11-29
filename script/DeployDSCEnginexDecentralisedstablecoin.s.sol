//SDPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {Decentralisedstablecoin} from "../src/Decentralisedstablecoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSCEnginexDecentralisedstablecoin is Script {
    Decentralisedstablecoin private s_dsc;
    DSCEngine private s_dscengine;
    HelperConfig private helperconfig;

    function run() public returns (DSCEngine) {
        helperconfig = new HelperConfig();
        (
            address wethtokenaddress,
            address wbtctokenaddress,
            address wethpricefeedaddress,
            address wbtcpriceaddress
        ) = (helperconfig.activeConfig());
        address[] memory tokenaddresses = new address[](2);
        address[] memory pricefeedaddresses = new address[](2);
        tokenaddresses[0] = wethtokenaddress;
        tokenaddresses[1] = wbtctokenaddress;

        pricefeedaddresses[0] = wethpricefeedaddress;
        pricefeedaddresses[1] = wbtcpriceaddress;
        vm.startBroadcast();
        s_dsc = new Decentralisedstablecoin();
        s_dscengine = new DSCEngine(tokenaddresses, pricefeedaddresses, s_dsc);
        s_dsc.transferOwnership(address(s_dscengine));
        vm.stopBroadcast();
        return s_dscengine;
    }

    function getdscaddress() public view returns (address) {
        return address(s_dsc);
    }

    function getactiveconfig()
        public
        view
        returns (address, address, address, address)
    {
        (
            address wethtokenaddress,
            address wbtctokenaddress,
            address wethpricefeedaddress,
            address wbtcpriceaddress
        ) = (helperconfig.activeConfig());
        return (
            wethtokenaddress,
            wbtctokenaddress,
            wethpricefeedaddress,
            wbtcpriceaddress
        );
    }
}
