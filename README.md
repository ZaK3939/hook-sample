# Uniswap V4 Hooks Implementation Example

This is for the explanation of the flaunch and rehypothecasion.

This repository serves as a practical demonstration of Uniswap V4 hooks implementation It showcases how to build aave
integrations

## Uniswap V4 Hooks Showcase

The core focus of this project is to demonstrate the power and flexibility of Uniswap V4 hooks. The `FusedHooks`
contract illustrates:

- Hook implementation with multiple hook points (BEFORE_INITIALIZE, BEFORE_ADD_LIQUIDITY, BEFORE_SWAP)
- Integration with external protocols (Aave V3) through a hook interface
- Custom pool behavior with hooks that modify the standard AMM experience
- CREATE2 deployment pattern for hooks with correct flags

## Overview

FusedETH demonstrates a yield-generating ETH wrapper that leverages Uniswap V4 hooks and Aave V3. Key features include:

1. Deposit ETH to receive fusedETH tokens (1:1 ratio)
2. Underlying ETH is deployed to Aave V3 to generate yield
3. Custom hook logic ensures seamless swapping between ETH and fusedETH
4. Yield harvesting mechanics with distribution to designated receivers

```sh
$ bun install # install Solhint, Prettier, and other Node.js deps
$ forge install
$ forge re
$ forge script script/HookMining.s.sol:DeployHookScript --rpc-url sepolia --broadcast --verify --ffi
```

## Key Components

- **FusedHooks**: The central showcase of this repo - demonstrates Uniswap V4 hook implementation
- **FusedETH**: ERC20 token that wraps ETH with yield capabilities
- **AaveV3Strategy**: Strategy for yield generation through Aave
- **AaveV3WethGateway**: Custom gateway for Aave interaction

## Hook Implementation Details

The `FusedHooks` contract demonstrates:

- Proper hook initialization and flag configuration
- Complex hook logic across multiple hook points
- State management via hooks
- Integration with external protocols in hook callbacks

## Development and Testing

The project includes comprehensive integration tests that show the hooks in action:

```bash
forge test
```
