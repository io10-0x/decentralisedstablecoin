//SDPX-License-Identifier: MIT

//Invariants: 1. The total collateral value must be greater than the total DSC value
// 2. All getter functions should never revert
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSCEnginexDecentralisedstablecoin} from "../../script/DeployDSCEnginexDecentralisedstablecoin.s.sol";
import {MintableERC20} from "../../src/MintableERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Decentralisedstablecoin} from "../../src/Decentralisedstablecoin.sol";
import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../../src/test/MockV3Aggregator.sol";

contract Handlers is Test {
    address dscengine;
    address dsc;
    uint96 constant UPPERBOUND = type(uint96).max;
    address collateraladdy;
    address[] userswithdepositedcollateral;

    constructor(address dsce, address dscaddress) {
        dscengine = dsce;
        dscaddress = dsc;
    }

    function depositcollateral(uint256 collateralseed, uint256 amount) public {
        collateraladdy = _getcollateraladdyfromseed(collateralseed);
        amount = bound(amount, 1, UPPERBOUND);
        vm.startPrank(msg.sender);
        if (block.chainid == 31337) {
            ERC20Mock(collateraladdy).mint(msg.sender, amount);
            ERC20Mock(collateraladdy).approve(
                address(dscengine),
                type(uint256).max
            );
        }

        DSCEngine(dscengine).depositCollateral(collateraladdy, amount);
        vm.stopPrank();
        userswithdepositedcollateral.push(msg.sender);
    }

    function _getcollateraladdyfromseed(
        uint256 collateralseed
    ) public view returns (address) {
        address[] memory tokens = DSCEngine(dscengine)
            .getallowedtokencollateral();
        if (collateralseed % 2 == 0) {
            return tokens[0];
        } else {
            return tokens[1];
        }
    }

    function redeemcollateral(
        uint256 collateralseed,
        uint256 amount,
        uint256 sendernumber
    ) public {
        collateraladdy = _getcollateraladdyfromseed(collateralseed);
        if (userswithdepositedcollateral.length == 0) {
            return;
        }
        address sender = userswithdepositedcollateral[
            sendernumber % userswithdepositedcollateral.length
        ];
        vm.startPrank(sender);
        uint256 usercollateral = DSCEngine(dscengine).getusercollateralbalance(
            msg.sender,
            collateraladdy
        );
        amount = bound(amount, 0, usercollateral);
        if (amount == 0) {
            return;
        }
        DSCEngine(dscengine).redeemcollateral(collateraladdy, amount);
        vm.stopPrank();
    }

    function mintdsc(uint256 amount, uint256 sendernumber) public {
        if (userswithdepositedcollateral.length == 0) {
            return;
        }
        address sender = userswithdepositedcollateral[
            sendernumber % userswithdepositedcollateral.length
        ];
        amount = bound(amount, 1, UPPERBOUND);
        vm.startPrank(sender);
        DSCEngine(dscengine).mintDSC(amount);
        vm.stopPrank();
    }

    /* This function will break our protocol because if the price of the collateral tanks very quickly in a short period, the user will be undercollateralized in that period and the protocol will be at risk.
   Need to think of a fix to this issue.
   function updateprice(uint256 answer) public {
        if (collateraladdy == address(0)) {
            return;
        }
        answer = bound(answer, 1, UPPERBOUND);
        address pricefeedaddy = DSCEngine(dscengine).getpricefeedaddress(
            collateraladdy
        );
        MockV3Aggregator(pricefeedaddy).updateAnswer(int256(answer));
    } */
}
