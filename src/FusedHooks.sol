// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IFusedETH } from "./interfaces/IFusedETH.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { BeforeSwapDelta, toBeforeSwapDelta } from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { Hooks, IHooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseHook } from "v4-periphery/src/utils/BaseHook.sol";

/**
 * Handles the 1:1 swapping of ETH:fusedEth, as well as handling the strategy interactions.
 */
contract FusedHooks is BaseHook {
    /// Thrown when trying to add liquidity directly to the pool
    error CannotAddLiquidity();

    /// We only accept swapping between fusedEth and ETH
    error InvalidTokenPair();

    /// This pool only has a fee of 0
    error FeeMustBeZero();

    /// The fusedEth token contract, that wraps ETH 1:1
    IFusedETH public immutable fusedEth;

    /**
     * Sets our immutable {PoolManager} contract reference, used to initialise the BaseHook,
     * and also validates that the contract implementing this adheres to the hook address
     * validation.
     *
     * The hook address is validated in the {BaseHook} constructor.
     *
     * @param _poolManager The Uniswap V4 {PoolManager} contract address
     * @param _fusedEth The {fusedEth} contract address
     */
    constructor(address _poolManager, IFusedETH _fusedEth) BaseHook(IPoolManager(_poolManager)) {
        // Set the fusedEth token contract
        fusedEth = _fusedEth;
    }

    /**
     * This function defines the hooks that are required, and also importantly those which are
     * not, by our contract. This output determines the contract address that the deployment
     * must conform to and is validated in the constructor of this contract.
     */
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * Ensures that we only allow fusedEth/ETH pools to use the hook.
     *
     * @param key The `PoolKey` being initialized
     */
    function _beforeInitialize(
        address,
        PoolKey calldata key, // memory から calldata に変更
        uint160
    )
        internal
        view
        override
        returns (bytes4)
    {
        // As ETH will always be token0, we can check for specific tokens
        if (Currency.unwrap(key.currency0) != address(0) || Currency.unwrap(key.currency1) != address(fusedEth)) {
            revert InvalidTokenPair();
        }

        // Ensure that our fee is zero
        if (key.fee != 0) revert FeeMustBeZero();

        return BaseHook.beforeInitialize.selector;
    }

    /**
     * This 'custom curve' is a line, 1-1. We take the full input amount, and give the full
     * output amount.
     *
     * @param key The `PoolKey` being swapped against
     * @param params The swap parameters passed by the caller
     */
    function _beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    )
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (Currency inputCurrency, Currency outputCurrency, uint256 amount) = _getInputOutputAndAmount(key, params);

        // Take the amount from the {PoolManager}
        poolManager.take(inputCurrency, address(this), amount);

        // Convert inputCurrency to outputCurrency
        if (Currency.unwrap(inputCurrency) == address(0)) {
            fusedEth.deposit{ value: amount }(0);
        } else {
            fusedEth.withdraw(amount);
        }

        // Settle the output currenct
        poolManager.sync(outputCurrency);
        if (Currency.unwrap(outputCurrency) == address(0)) {
            poolManager.settle{ value: amount }();
        } else {
            IERC20(address(fusedEth)).transfer(address(poolManager), amount);
            poolManager.settle();
        }

        // Return -amountSpecified as specified to no-op the concentrated liquidity swap
        BeforeSwapDelta hookDelta = toBeforeSwapDelta(int128(-params.amountSpecified), int128(params.amountSpecified));

        return (BaseHook.beforeSwap.selector, hookDelta, 0);
    }

    /**
     * Prevent liquidity being added to the pool.
     */
    function _beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    )
        internal
        pure
        override
        returns (bytes4)
    {
        revert CannotAddLiquidity();
    }

    /**
     * Determines the input and output amounts, as well as token positions.
     *
     * @param key The `PoolKey` being swapped against
     * @param params The swap parameters passed by the caller
     *
     * @return input The token being swapped in
     * @return output The token being swapped out
     * @return amount The amount of input token being swapped in
     */
    function _getInputOutputAndAmount(
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params
    )
        internal
        pure
        returns (Currency input, Currency output, uint256 amount)
    {
        (input, output) = params.zeroForOne ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        amount = params.amountSpecified < 0 ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
    }

    /**
     * To receive ETH from fusedEth & poolManager contracts.
     */
    receive() external payable { }
}
