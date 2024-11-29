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
import {Handlers} from "./Handlers.t.sol";

contract InvariantTests is Test {
    DSCEngine private dscengine;
    DeployDSCEnginexDecentralisedstablecoin private deploydscengine;
    MintableERC20 private wbtc;
    ERC20Mock private wbtcanvil;
    Handlers private handlers;
    address wethtokenaddress;
    address wbtctokenaddress;
    address wethpricefeedaddress;
    address wbtcpriceaddress;
    error DSCEngine__Amountmustbegreaterthanzero();
    error DSCEngine__InvalidInputLength();
    error DSCEngine__tokennotsupported();
    error DSCEngine__depositcollateralfailed();
    error DSCEngine__healthfactorbelowhealthyamount();
    error DSCEngine__transferfailed();
    error DSCEngine__usercannotbeliquidated();
    error DSCEngine__healthfactorofbasusermustimprove();

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );
    event MintedDSC(address indexed user, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    function setUp() public {
        deploydscengine = new DeployDSCEnginexDecentralisedstablecoin();
        dscengine = deploydscengine.run();
        (
            wethtokenaddress,
            wbtctokenaddress,
            wethpricefeedaddress,
            wbtcpriceaddress
        ) = deploydscengine.getactiveconfig();
        address dscaddy = deploydscengine.getdscaddress();

        handlers = new Handlers(address(dscengine), dscaddy);
        targetContract(address(handlers));
    }

    function invariant_testinvariant1() public view {
        uint256 wethbalance;
        uint256 wbtcbalance;
        if (block.chainid == 31337) {
            wethbalance = ERC20Mock(wethtokenaddress).balanceOf(
                address(dscengine)
            );
            wbtcbalance = ERC20Mock(wbtctokenaddress).balanceOf(
                address(dscengine)
            );
        } else {
            wethbalance = MintableERC20(wethtokenaddress).balanceOf(
                address(dscengine)
            );
            wbtcbalance = MintableERC20(wbtctokenaddress).balanceOf(
                address(dscengine)
            );
        }

        address dscaddy = deploydscengine.getdscaddress();
        Decentralisedstablecoin dsc = Decentralisedstablecoin(dscaddy);
        uint256 totaldscsupply = dsc.totalSupply();

        uint256 wethbalanceusd = dscengine.getusdvalueofcollateral(
            wethtokenaddress,
            wethbalance
        );
        uint256 wbtcbalanceusd = dscengine.getusdvalueofcollateral(
            wbtctokenaddress,
            wbtcbalance
        );
        console.log("Total DSC supply: ", totaldscsupply);
        console.log("WETH balance usd: ", wethbalanceusd);
        console.log("WBTC balance usd: ", wbtcbalanceusd);
        assert(totaldscsupply <= wethbalanceusd + wbtcbalanceusd);
    }

    function invariant_testinvariant2() public view {
        dscengine.getallowedtokencollateral();
        dscengine.gethealthfactor(msg.sender);
        dscengine.getusdvalueofcollateral(wethtokenaddress, 1);
        dscengine.getuseraccountdata(msg.sender);
        dscengine.getusercollateralbalance(msg.sender, wethtokenaddress);
    }
}
