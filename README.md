Decentralised Stablecoin Project: README

## Overview

This repository contains the implementation of a decentralised stablecoin pegged to the US Dollar (1 DSC = 1 USD). The project demonstrates key concepts in DeFi, including minting, burning, collateralisation, algorithmic stability mechanisms, and security through testing. The stablecoin is built to accept ERC20 tokens like WETH and WBTC as collateral.

## Features

- **Collateralisation:** Users deposit WETH or WBTC as collateral to mint DSC.
- **Algorithmic Stability:** Automated minting and burning ensure DSC remains pegged to the dollar.
- **Overcollateralisation:** Users must always maintain collateral above their borrowed DSC to prevent undercollateralisation.
- **Modular Code Design:** Utilises inheritance, custom errors, and OpenZeppelin standards.
- **Security:** Includes reentrancy protections, health factor enforcement, and invariant testing.

---

## Contracts

### 1. `Decentralisedstablecoin.sol`

A simple ERC20 token contract implementing the decentralised stablecoin (DSC) with minting and burning functionality.

#### Key Points

- **Inherits From:**
  - `ERC20` (OpenZeppelin)
  - `ERC20Burnable` (OpenZeppelin)
  - `Ownable` (OpenZeppelin)
- **Super Keyword Usage:** Demonstrates overriding `ERC20Burnable`'s `burn` function with additional checks.
- **Constructor:** Mints an initial supply of 1,000,000 DSC to the deployer.
- **Custom Errors:**
  - Prevent zero-amount minting or burning.
  - Ensure burning does not exceed the user's balance.

---

### 2. `DSCEngine.sol`

The core contract responsible for the stability mechanism of DSC.

#### Key Points

- **Constructor:**
  - Accepts collateral tokens and their respective price feeds.
  - Maps tokens to price feeds for collateral valuation.
- **Key Functions:**
  - `depositCollateral`: Allows users to deposit collateral.
  - `mintDSC`: Mints DSC based on deposited collateral, ensuring a healthy health factor.
  - `redeemCollateral`: Lets users withdraw their collateral.
  - `liquidate`: Allows users to liquidate undercollateralised positions.
- **Health Factor:** Enforces a minimum health factor (collateral-to-debt ratio) to ensure overcollateralisation.
- **Security Features:**
  - Reentrancy protection via `nonReentrant`.
  - Custom checks for edge cases like zero-value transactions.

---

### 3. `OracleLib.sol`

A library for validating the timeliness of price feed data using Chainlink oracles.

#### Key Points

- **Timeout Check:** Ensures price feeds are updated within a 3-hour window.
- **Integration:** Refactors `latestRoundData` to include stale data checks.

---

## Testing

### Unit Testing

- Each function is tested for:
  - Correct execution.
  - Error handling using custom errors.
  - Security features like reentrancy protection.

### Invariant Testing

Invariant tests ensure the protocol maintains its key properties under various conditions.

#### Invariants

1. **Collateral Value ≥ Minted DSC:** Ensures overcollateralisation at all times.
2. **No Getter Function Reverts:** Ensures all getter functions operate correctly under stress.

#### Testing Methods

- **Stateless Fuzz Testing:** Random inputs test individual functions without relying on previous state.
- **Stateful Fuzz Testing:** Ensures function calls respect the protocol's internal state.
- **Handler-Based Testing:** Guides the sequence of function calls to avoid unnecessary reverts.

---

## Known Issues and Enhancements

- **Oracle Price Drops:** Rapid collateral price drops can lead to temporary undercollateralisation.
- **Breaking CEI Methodology:** Some checks are performed post-external calls due to necessity.
- **Future Improvement:** Introduce additional mechanisms to manage rapid price fluctuations in collateral.

---

## Usage

1. Clone the repository and initialise a Foundry project:

   ```bash
   git clone <repository-url>
   cd foundry-defi-stablecoin

   ```

2. ## Compile Contracts

   ```bash
   forge build

   ```

3. ## Run Tests

   ```bash
   forge test

   ```

4. ## Deploy Contracts
   Use the provided deployment scripts for deployment.

## Tools and Libraries

- **Foundry:** For smart contract development and testing.
- **OpenZeppelin Contracts:** Prebuilt ERC20 and security modules.
- **Chainlink Oracles:** For price data integration.
- **Forge-Std:** Testing utilities.

## License

- **This project is licensed under the MIT License.**
