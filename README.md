## Overview

This repository aims to provide an educational demonstration of tokenizing real-world assets, specifically stocks, on the blockchain. The project incorporates various functionalities to ensure the proper handling and security of the token minting and redeeming processes. This repository contains the smart contract code for `dTSLA`, a decentralized token backed by Tesla stocks. The `dTSLA` contract utilizes Chainlink's Functions to interact with the Alpaca API for minting and redeeming tokens based on TSLA prices.

## Features

- **Minting and Redeeming**: Allows users to mint `dTSLA` tokens by sending a mint request, which interacts with the Alpaca API to verify the portfolio balance. Users can also redeem `dTSLA` tokens back to USD equivalent.
- **Chainlink Functions Integration**: Utilizes Chainlink's Functions to securely fetch and manage secrets for API interactions.
- **Price Feeds**: Integrates Chainlink's decentralized price feeds to fetch the current TSLA and USDC prices, ensuring accurate and up-to-date valuations.
- **Collateral Management**: Ensures that token minting is backed by sufficient collateral, maintaining a 200% collateral ratio to safeguard the value of `dTSLA` tokens.
- **Security**: Implements owner-only functions, pausing capabilities, and withdrawal mechanisms to protect users' funds and contract integrity.

## Contracts

- **dTSLA.sol**: The main contract implementing the minting and redeeming logic, price feed integration, and Chainlink Functions interactions.
- **Libraries**: Includes additional libraries for Oracle interactions and utility functions.

## Getting Started

To deploy and interact with the `dTSLA` contract:

1. Clone the repository.
2. Install dependencies and set up the environment variables as required.
3. Deploy the contract to your preferred blockchain network.
4. Use the provided scripts to upload secrets and interact with the contract functions.

## Requirements

- Solidity 0.8.25
- Chainlink Contracts
- OpenZeppelin Contracts
- Node.js for running scripts and interacting with the Chainlink Functions

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes.

## License

This project is licensed under the MIT License.
