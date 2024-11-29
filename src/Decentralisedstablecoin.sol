//SDPX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DSCEngine} from "./DSCEngine.sol";

/**
 * @title Decentralisedstablecoin
 * @dev Implementation of the Decentralisedstablecoin
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Decentralised
 * Relative Stability: 1 DSC = 1 USD
 */

contract Decentralisedstablecoin is ERC20, ERC20Burnable, Ownable {
    error Decentralisedstablecoin__cannotburnmorethanbalance();
    error Decentralisedstablecoin__cannotburnzeroamount();
    error Decentralisedstablecoin__cannotsendtozeroaddress();
    error Decentralisedstablecoin__cannotmintzeroamount();

    constructor() ERC20("Decentralisedstablecoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 amount) public override {
        uint256 balance = balanceOf(msg.sender);
        if (amount > balance) {
            revert Decentralisedstablecoin__cannotburnmorethanbalance();
        }
        if (amount <= 0) {
            revert Decentralisedstablecoin__cannotburnzeroamount();
        }
        super.burn(amount);
    }

    function mint(address account, uint256 amount) public onlyOwner {
        if (account == address(0)) {
            revert Decentralisedstablecoin__cannotsendtozeroaddress();
        }
        if (amount <= 0) {
            revert Decentralisedstablecoin__cannotmintzeroamount();
        }
        _mint(account, amount);
    }
}
