# USDC.g Bridge Service

## Overview
The USDC.g Bridge Service Contract is a smart contract designed to facilitate the cross-chain bridging of Native Polygon USDC (<a href="https://polygonscan.com/token/0x3c499c542cef5e3811e1192ce70d8cc03d5c3359" target="_blank">0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359</a>) into Bridged USDC.g on the Gauss Chain. 

## Features
Cross-Chain Bridging: The contract facilitates the minting and burning of USDC.g for the Gauss Ecosystem, allowing users to move USDC.g between the Polygon Chain and the Gauss Chain.

Express Mode: Users can enable express mode for faster transactions with minimal fees.

Configurable Parameters: The contract allows the contract owner to configure key parameters such as the bridge address, fee token, fee amount, and the number of confirmations required before validating a transaction.

Security: Built with security in mind, the contract utilizes industry best practices, including access control and reentrancy protection.

## Chain Configuration
The contract is intended to be deployed to the same address on both the Polygon Chain and the Gauss Chain. The chain itself determines the direction of the bridging process.

## Usage
Users can interact with the NobleSwap USDC.g Bridge Service Contract through the NobleSwap platform. The steps involved in bridging USDC.g are as follows:

Initiate Bridging: Users send their Native Polygon USDC to the contract address on the Polygon Chain or Native Gauss USDC to the contract address on the Gauss Chain, depending on the desired direction.

Transaction Confirmation: The contract confirms the receipt of funds and initiates the corresponding minting or burning process based on the direction.

Cross-Chain Transfer: The minted USDC.g is transferred to the user's address on the destination chain.

Express Mode (Optional): Users can enable express mode for faster transactions with minimal fees.

## Configuration
The contract owner can configure the following parameters:

Bridge Address: Update the Paper Bridge address to approve the new bridge for Fee Token transfers.

Fee Token: Update the Fee Token and approve the bridge for the new Token.

Fee Amount: Adjust the fee amount for minimum gas/tx fee payment.

Confirmations: Set the number of confirmations required before validating a transaction.

## Security Measures
Access Control: The contract includes access control mechanisms to ensure only authorized parties, such as the bridge, can interact with certain functions.

Reentrancy Protection: The contract uses the ReentrancyGuard library to prevent reentrancy attacks.

## Support and Recovery
In case of accidental token transfers, the contract owner can withdraw ERC20 tokens or recover accidentally sent native currency.

For support or assistance, users can reach out to the NobleSwap support team.

Note: Interacting with unsafe tokens or smart contracts can result in potential risks. Users are advised to use this contract with trusted tokens and contracts only.!