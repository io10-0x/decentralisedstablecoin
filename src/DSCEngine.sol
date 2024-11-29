//SDPX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Decentralisedstablecoin} from "./Decentralisedstablecoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/*
 * @title DSCEngine
 * @author Ivan Otono
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__InvalidInputLength();
    error DSCEngine__Amountmustbegreaterthanzero();
    error DSCEngine__tokennotsupported();
    error DSCEngine__depositcollateralfailed();
    error DSCEngine__healthfactorbelowhealthyamount();
    error DSCEngine__transferfailed();
    error DSCEngine__usercannotbeliquidated();
    error DSCEngine__healthfactorofbadusermustimprove();

    using OracleLib for AggregatorV3Interface;

    mapping(address tokenaddress => address pricefeedaddress)
        private s_tokentopricefeedmap;
    mapping(address user => mapping(address token => uint256 amount))
        private s_usercollateralbalance;
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
    mapping(address user => uint256 dscminted) private s_usermintedDSC;
    address[] private s_tokens;
    uint256 private constant FORMATAMOUNT = 1e10;
    uint256 private constant EXTRA18DECIMALS = 1e18;
    uint256 private constant LIQUIDATIONTHRESHOLD = 50; //user must be 200% overcollateralized
    uint256 private constant LIQUIDATIONPRECISION = 100;
    uint256 private constant HEALTHYAMOUNT = 1e18;
    uint256 private constant LIQUIDATIONBONUS = 10;
    Decentralisedstablecoin private s_dsc;

    constructor(
        address[] memory tokenaddresses,
        address[] memory pricefeedaddresses,
        Decentralisedstablecoin dscaddress
    ) {
        if (tokenaddresses.length != pricefeedaddresses.length) {
            revert DSCEngine__InvalidInputLength();
        }
        for (uint256 i = 0; i < tokenaddresses.length; i++) {
            s_tokentopricefeedmap[tokenaddresses[i]] = pricefeedaddresses[i];
            s_tokens.push(tokenaddresses[i]);
        }
        s_dsc = dscaddress;
    }

    modifier Nonzero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__Amountmustbegreaterthanzero();
        }
        _;
    }

    modifier ValidToken(address tokenaddress) {
        if (s_tokentopricefeedmap[tokenaddress] == address(0)) {
            revert DSCEngine__tokennotsupported();
        }
        _;
    }

    /*
     * @param tokenaddress: The ERC20 token address of the collateral you're depositing
     * @param amount: The amount of collateral you're depositing
     */
    function depositCollateral(
        address tokenaddress,
        uint256 amount
    ) public Nonzero(amount) ValidToken(tokenaddress) nonReentrant {
        s_usercollateralbalance[msg.sender][tokenaddress] += amount;
        emit CollateralDeposited(msg.sender, tokenaddress, amount);
        bool success = IERC20(tokenaddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) {
            revert DSCEngine__depositcollateralfailed();
        }
    }

    /*
     * @param amount: The amount of DSC you want to mint
     * You can only mint DSC if you have enough collateral
     */

    function mintDSC(uint256 amount) public Nonzero(amount) nonReentrant {
        _revertIfhealthfactorbelowhealthyamount(msg.sender, amount);
        s_usermintedDSC[msg.sender] += amount;
        emit MintedDSC(msg.sender, amount);
        s_dsc.mint(msg.sender, amount);
    }

    /*
     * @param tokenaddress: The ERC20 token address of the collateral you're depositing
     * @param depositamount: The amount of collateral you're depositing
     * @param mintamount: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */

    function depositandMintcollateral(
        address tokenaddress,
        uint256 depositamount,
        uint256 mintamount
    )
        public
        Nonzero(depositamount)
        Nonzero(mintamount)
        ValidToken(tokenaddress)
        nonReentrant
    {
        depositCollateral(tokenaddress, depositamount);
        mintDSC(mintamount);
    }

    /*
     * @param tokenaddress: The ERC20 token address of the collateral you're redeeming
     * @param amount: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
     */
    function redeemcollateral(
        address tokenaddress,
        uint256 amount
    ) public Nonzero(amount) ValidToken(tokenaddress) nonReentrant {
        _redeemcollateral(msg.sender, tokenaddress, amount);
        _revertIfhealthfactorbelowhealthyamount(msg.sender, 1);
    }

    /*
     * @notice careful! You'll burn your DSC here! Make sure you want to do this...
     * @dev you might want to use this if you're nervous you might get liquidated and want to just burn
     * your DSC but keep your collateral in.
     */
    function burnDSC(uint256 amount) public Nonzero(amount) nonReentrant {
        _burnDSC(msg.sender, amount);
    }

    /*
     * @param tokenaddress: The ERC20 token address of the collateral you're withdrawing
     * @param amount: The amount of collateral you're withdrawing
     * @param burnamount: The amount of DSC you want to burn
     * @notice This function will withdraw your collateral and burn DSC in one transaction
     */
    function redeemcollateralandburnDSC(
        address tokenaddress,
        uint256 amount,
        uint256 burnamount
    )
        public
        Nonzero(amount)
        Nonzero(burnamount)
        ValidToken(tokenaddress)
        nonReentrant
    {
        burnDSC(burnamount);
        redeemcollateral(tokenaddress, amount);
    }

    function liquidate(
        address user,
        address tokenaddress,
        uint256 dscamount
    ) public Nonzero(dscamount) nonReentrant {
        uint256 startinghealthfactor = _gethealthfactor(user, 0);
        if (startinghealthfactor > HEALTHYAMOUNT) {
            revert DSCEngine__usercannotbeliquidated();
        }
        uint256 dscamounttocollateral = changedscamounttocollateralval(
            dscamount,
            tokenaddress
        );

        uint256 bonus = (LIQUIDATIONBONUS / LIQUIDATIONPRECISION) *
            dscamounttocollateral;
        uint256 totalcollateral = dscamounttocollateral + bonus;

        _redeemcollateral(user, tokenaddress, totalcollateral);
        _burnDSC(user, dscamount);

        uint256 endinghealthfactor = _gethealthfactor(user, 0);
        if (endinghealthfactor == startinghealthfactor) {
            revert DSCEngine__healthfactorofbadusermustimprove();
        }
        _revertIfhealthfactorbelowhealthyamount(msg.sender, 0);
    }

    function _gettotalmintedDSC(address user) private view returns (uint256) {
        return s_usermintedDSC[user];
    }

    function _revertIfhealthfactorbelowhealthyamount(
        address user,
        uint256 expectedmintamount
    ) private view {
        uint256 healthfactor = _gethealthfactor(user, expectedmintamount);
        if (healthfactor < HEALTHYAMOUNT) {
            revert DSCEngine__healthfactorbelowhealthyamount();
        }
    }

    function _gethealthfactor(
        address user,
        uint256 expectedmintamount
    ) private view returns (uint256) {
        uint256 healthfactor;
        (
            uint256 mintedDSC,
            uint256 totalcollateralvalueUSD
        ) = getuseraccountdata(user);
        uint256 adjustedcollateralusdvalue = (totalcollateralvalueUSD *
            LIQUIDATIONTHRESHOLD) / LIQUIDATIONPRECISION;
        if (mintedDSC == 0) {
            healthfactor =
                (adjustedcollateralusdvalue * EXTRA18DECIMALS) /
                expectedmintamount;
        } else {
            healthfactor =
                (adjustedcollateralusdvalue * EXTRA18DECIMALS) /
                (mintedDSC + expectedmintamount);
        }
        console.log("Minted DSC:", mintedDSC);
        console.log("expectedmintamount:", expectedmintamount);
        console.log("adjustedcollateralusdvalue:", adjustedcollateralusdvalue);
        console.log("Health factor:", healthfactor);
        return healthfactor;
    }

    function _redeemcollateral(
        address to,
        address tokenaddress,
        uint256 amount
    ) private {
        console.log(to, s_usercollateralbalance[to][tokenaddress], amount);
        s_usercollateralbalance[to][tokenaddress] -= amount;
        emit CollateralRedeemed(to, tokenaddress, amount);
        bool success = IERC20(tokenaddress).transfer(to, amount);
        if (!success) {
            revert DSCEngine__transferfailed();
        }
    }

    function _burnDSC(address user, uint256 amount) public Nonzero(amount) {
        s_usermintedDSC[user] -= amount;
        if (msg.sender != user) {
            s_usermintedDSC[msg.sender] -= amount;
        }

        bool success = IERC20(s_dsc).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) {
            revert DSCEngine__transferfailed();
        }
        s_dsc.burn(amount);
    }

    function getuseraccountdata(
        address user
    ) public view returns (uint256, uint256) {
        uint256 mintedDSC = _gettotalmintedDSC(user);
        uint256 collateralvalusd = _gettotalcollateralvalueUSD(user);
        return (mintedDSC, collateralvalusd);
    }

    function _gettotalcollateralvalueUSD(
        address user
    ) private view returns (uint256) {
        uint256 totalcollateralvalueUSD = 0;
        for (uint256 i = 0; i < s_tokens.length; i++) {
            address token = s_tokens[i];
            uint256 collateralbalance = s_usercollateralbalance[user][token];
            uint256 collateralbalanceusd = getusdvalueofcollateral(
                token,
                collateralbalance
            );
            totalcollateralvalueUSD += collateralbalanceusd;
        }
        return totalcollateralvalueUSD;
    }

    function getusdvalueofcollateral(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface pricefeed = AggregatorV3Interface(
            s_tokentopricefeedmap[token]
        );
        (, int256 price, , , ) = pricefeed.stalechecklatestrounddata();
        uint256 formattedprice = uint256(price) * FORMATAMOUNT;
        return (formattedprice * amount) / EXTRA18DECIMALS;
    }

    function changedscamounttocollateralval(
        uint256 dscamount,
        address token
    ) public view returns (uint256) {
        AggregatorV3Interface pricefeed = AggregatorV3Interface(
            s_tokentopricefeedmap[token]
        );
        (, int256 price, , , ) = pricefeed.stalechecklatestrounddata();
        uint256 formattedprice = uint256(price) * FORMATAMOUNT;
        return ((dscamount * EXTRA18DECIMALS) / formattedprice);
    }

    function getusercollateralbalance(
        address user,
        address token
    ) external view returns (uint256) {
        return s_usercollateralbalance[user][token];
    }

    function gethealthfactor(address user) external view returns (uint256) {
        return _gethealthfactor(user, 1); //to avoid divvy by zero, i set amount to 1 so if minteddsc ==0, it will still work
    }

    function getallowedtokencollateral()
        external
        view
        returns (address[] memory)
    {
        return s_tokens;
    }

    function getpricefeedaddress(
        address token
    ) external view returns (address) {
        return s_tokentopricefeedmap[token];
    }
}
