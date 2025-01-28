# Ethereum Sepolia Testnet Arbitrage Bot

## Overview
This smart contract implements an arbitrage strategy on the Ethereum Sepolia test network. It uses flash loans from Aave to exploit price differences between tokens on Uniswap V3.

## Contract Details

- **Solidity Version:** ^0.8.0
- **License:** MIT

### Dependencies:
- **Uniswap V3 Periphery:** For swap operations.
- **Aave V3:** For flash loans.
- **OpenZeppelin:** For security features like `ReentrancyGuard`.
- **Chainlink:** For price feeds.

### Key Features:
- **Flash Loan Integration:** Utilizes Aave's flash loan mechanism to initiate arbitrage.
- **Price Oracle:** Uses Chainlink's `AggregatorV3Interface` to fetch token prices.
- **Slippage Protection:** Implements maximum slippage to avoid unprofitable trades due to price changes.
- **Security:** Includes `ReentrancyGuard` to prevent reentrancy attacks.

## Contract Functions

### Constructor
- Sets up contract addresses and configurations:
  - `_uniswapRouter`: Address of Uniswap V3's SwapRouter.
  - `_poolAddressesProvider`: Address of Aave's pool address provider.
  - `_priceFeedAddress`: Address of Chainlink's price feed.
  - `_anotherTokenAddress`: Address of the secondary token for trading.
  - `_maxSlippage`: Maximum allowed slippage in basis points.

### Public Functions

- **`executeArbitrageOpportunity`**: Executes an arbitrage opportunity if profitable:
  - Parameters: `asset`, `amount`, `tokenIn`, `tokenOut`, `fee`, `amountOutMinimum`.
  - Only the contract owner can call this function.

- **`setMaxSlippage`**: Allows the owner to update the maximum slippage allowed.

### Internal Functions

- **`isArbitrageProfitable`**: Checks if the arbitrage would be profitable based on current prices.
- **`getTokenPrice`**: Retrieves the price of a token from Chainlink oracles.
- **`executeFlashLoan`**: Initiates a flash loan from Aave.
- **`executeTrade`**: Executes a swap on Uniswap V3.
- **`flashLoanCallback`**: Callback function for handling flash loan lifecycle.

## Setup

1. **Deployment:**
   - Deploy the contract on Sepolia testnet with necessary addresses for Uniswap, Aave, and Chainlink.

2. **Funding:**
   - Ensure the contract has enough ETH or tokens to pay for gas fees and initial flash loan premiums.

3. **Testing:**
   - Test the arbitrage function with various token pairs and amounts to ensure profitability and functionality.

## Security Considerations

- **Reentrancy Protection:** Use `ReentrancyGuard` to avoid reentrancy attacks.
- **Slippage Control:** Always check for slippage before executing trades.
- **Price Oracle Manipulation:** Be cautious of oracle price manipulations; consider using multiple oracles.

## Known Issues or TODOs

- **Profitability Check**: The `isArbitrageProfitable` function needs more sophisticated logic for real-world scenarios.
- **Error Handling**: Improve error messages and revert reasons for better debugging.

## License
This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
