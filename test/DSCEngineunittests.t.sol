//SDPX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DeployDSCEnginexDecentralisedstablecoin} from "../script/DeployDSCEnginexDecentralisedstablecoin.s.sol";
import {MintableERC20} from "../src/MintableERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Decentralisedstablecoin} from "../src/Decentralisedstablecoin.sol";
import {MockV3Aggregator} from "../src/test/MockV3Aggregator.sol";

contract DSCEngineunittests is Test {
    DSCEngine private dscengine;
    DeployDSCEnginexDecentralisedstablecoin private deploydscengine;
    MintableERC20 private wbtc;
    ERC20Mock private wbtcanvil;
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
        if (block.chainid == 31337) {
            wbtcanvil = ERC20Mock(wbtctokenaddress);
        } else {
            wbtc = MintableERC20(wbtctokenaddress);
        }
    }

    function test_RevertIf_arraysdonthaveequallength() public {
        address[] memory tokens = new address[](1);
        address[] memory pricefeedaddresses = new address[](2);
        tokens[0] = wethtokenaddress;
        pricefeedaddresses[0] = wethpricefeedaddress;
        pricefeedaddresses[1] = wbtcpriceaddress;
        address dscaddy = deploydscengine.getdscaddress();
        vm.expectRevert(DSCEngine__InvalidInputLength.selector);
        new DSCEngine(
            tokens,
            pricefeedaddresses,
            Decentralisedstablecoin(dscaddy)
        );
    }

    function test_RevertIf_userenterstokennotusedforcollateral() public {
        address user1 = vm.addr(1);
        vm.startPrank(user1);
        vm.expectRevert(DSCEngine__tokennotsupported.selector);
        dscengine.depositCollateral(
            0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f,
            100 ether
        );
        vm.stopPrank();
    }

    function test_RevertIf_userdepositszerocollateral() public {
        address user1 = vm.addr(1);
        vm.startPrank(user1);
        vm.expectRevert(DSCEngine__Amountmustbegreaterthanzero.selector);
        dscengine.depositCollateral(wbtctokenaddress, 0);
        vm.stopPrank();
    }

    modifier depositcollateral() {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        if (block.chainid == 31337) {
            wbtcanvil.mint(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                100 ether
            );
            wbtcanvil.approve(address(dscengine), type(uint256).max);
        } else {
            wbtc.mint(100 ether);
            wbtc.approve(address(dscengine), type(uint256).max);
        }

        dscengine.depositCollateral(wbtctokenaddress, 1 ether);

        _;
    }

    function test_depositcollateralworkssuccessfully() public {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        if (block.chainid == 31337) {
            wbtcanvil.mint(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                100 ether
            );
            wbtcanvil.approve(address(dscengine), 100 ether);
        } else {
            wbtc.mint(100 ether);
            wbtc.approve(address(dscengine), 100 ether);
        }
        dscengine.depositCollateral(wbtctokenaddress, 100 ether);
        vm.stopPrank();
        assertEq(
            dscengine.getusercollateralbalance(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                wbtctokenaddress
            ),
            100 ether
        );
    }

    function test_depositcollateraleventemits() public {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        if (block.chainid == 31337) {
            wbtcanvil.mint(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                100 ether
            );
            wbtcanvil.approve(address(dscengine), 100 ether);
        } else {
            wbtc.mint(100 ether);
            wbtc.approve(address(dscengine), 100 ether);
        }
        vm.expectEmit();
        emit CollateralDeposited(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            wbtctokenaddress,
            100 ether
        );

        dscengine.depositCollateral(wbtctokenaddress, 100 ether);
        vm.stopPrank();
    }

    function test_getuseraccountdatafunction() public depositcollateral {
        vm.startPrank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        dscengine.mintDSC(30 ether);
        (uint256 actualmintedDSC, uint256 actualcollateralvalusd) = dscengine
            .getuseraccountdata(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        uint256 expectedmintedDSC = 30 ether;
        uint256 expectedcollateralvalusd = 90000 ether;

        assertEq(expectedmintedDSC, actualmintedDSC);
        assertEq(expectedcollateralvalusd, actualcollateralvalusd);
    }

    function test_redeemcollateralfunction() public depositcollateral {
        console.log(
            "Allowance before redeem:",
            wbtcanvil.allowance(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                address(dscengine)
            )
        );
        dscengine.redeemcollateral(wbtctokenaddress, 0.5 ether);
        vm.stopPrank();
        assertEq(
            dscengine.getusercollateralbalance(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                wbtctokenaddress
            ),
            0.5 ether
        );
    }

    function test_usercanburndsc() public depositcollateral {
        dscengine.mintDSC(30 ether);
        address dscaddy = deploydscengine.getdscaddress();
        Decentralisedstablecoin dsc = Decentralisedstablecoin(dscaddy);
        dsc.approve(address(dscengine), 30 ether);
        dscengine.burnDSC(10 ether);
        vm.stopPrank();
        (uint256 mintedDSC, ) = dscengine.getuseraccountdata(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        );
        assertEq(mintedDSC, 20 ether);
    }

    function test_getusdvalueofcollateral() public view {
        uint256 expectedval = 90000e18;
        uint256 actualval = dscengine.getusdvalueofcollateral(
            wbtctokenaddress,
            1 ether
        );

        assertEq(expectedval, actualval);
    }

    function test_badusercanbeliquidated() public depositcollateral {
        dscengine.mintDSC(30000 ether);
        uint256 healthfactor = dscengine.gethealthfactor(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        );
        console.log("Health factor before liquidation:", healthfactor);

        vm.stopPrank();
        address user1 = vm.addr(1);
        vm.startPrank(user1);
        if (block.chainid == 31337) {
            wbtcanvil.mint(user1, 100000 ether);
            wbtcanvil.approve(address(dscengine), type(uint256).max);
        } else {
            wbtc.mint(100 ether);
            wbtc.approve(address(dscengine), type(uint256).max);
        }
        address dscaddy = deploydscengine.getdscaddress();
        Decentralisedstablecoin dsc = Decentralisedstablecoin(dscaddy);
        dsc.approve(address(dscengine), 30000 ether);
        dscengine.depositCollateral(wbtctokenaddress, 1000 ether);
        dscengine.mintDSC(30000 ether);
        MockV3Aggregator(wbtcpriceaddress).updateAnswer(100000000000);
        dscengine.liquidate(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            wbtctokenaddress,
            1000 ether
        );
        vm.stopPrank();
        (uint256 user1mintedDSC, ) = dscengine.getuseraccountdata(user1);
        (uint256 account1mintedDSC, ) = dscengine.getuseraccountdata(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        );
        uint256 expecteduser1dsc = 29000 ether;
        uint256 expectedaccount1dsc = 29000 ether;
        assertEq(user1mintedDSC, expecteduser1dsc);
        assertEq(account1mintedDSC, expectedaccount1dsc);
    }
}
