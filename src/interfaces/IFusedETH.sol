// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IWETH } from "./IWETH.sol";
import { IFusedETHStrategy } from "./aaveV3/IFusedETHStrategy.sol";

/**
 * The FusedETH token interface.
 */
interface IFusedETH {
    // Errors
    error AmountExceedsETHBalance();
    error UnableToSendETH();
    error CurrentStrategyHasBalance();
    error YieldReceiverIsZero();
    error RebalanceThresholdExceedsMax();

    /**
     * Makes a deposit into the contract, taking ETH and/or WETH and returning fusedETH.
     *
     * @dev This function can receive ETH and will give an amount of fusedETH equal to ETH + WETH.
     *
     * @param wethAmount The amount of WETH to transfer into the function
     */
    function deposit(uint256 wethAmount) external payable;

    /**
     * Rebalances our position against our strategy.
     */
    function rebalance() external;

    /**
     * Withdraw ETH by sending in fusedETH.
     *
     * @param amount The amount of fusedETH to burn for ETH
     */
    function withdraw(uint256 amount) external;

    /**
     * Harvest yield from the strategy and send it to our yield recipient
     */
    function harvest() external;

    /**
     * Helper function to find the amount of yield accumulated.
     *
     * @return uint Yield accumulated
     */
    function yieldAccumulated() external view returns (uint256);

    /**
     * Finds the amount of underlying ETH balance by finding current held amounts, as well as the
     * amount held in the strategy.
     *
     * @return uint The amount of underlying ETH held
     */
    function underlyingETHBalance() external view returns (uint256);

    /**
     * The owner of the contract that has {Ownable} permissions.
     *
     * @return address The owner address
     */
    function owner() external view returns (address);

    /**
     * Allows the `rebalanceThreshold` to be updated by the contract owner.
     *
     * @param rebalanceThreshold_ The new `rebalanceThreshold` value
     */
    function setRebalanceThreshold(uint256 rebalanceThreshold_) external;

    /**
     * Allows the `yieldReceiver` to be updated by the contract owner.
     *
     * @param yieldReceiver_ The new `yieldReceiver` address
     */
    function setYieldReceiver(address yieldReceiver_) external;

    /**
     * Allows the strategy to be updated. This validates that there is no ETH currently held in
     * the strategy to prevent loss of ETH.
     *
     * @param strategy_ The new {IFusedETHStrategy} strategy to be used
     */
    function changeStrategy(IFusedETHStrategy strategy_) external;

    /**
     * Allows potentially trapped ETH funds to be rescued from the contract.
     *
     * @param amount The amount of ETH to rescue
     */
    function emergencyRescue(uint256 amount) external;

    /**
     * @return The WETH token address
     */
    function weth() external view returns (IWETH);

    /**
     * @return The rebalance threshold percentage (in wei format)
     */
    function rebalanceThreshold() external view returns (uint256);

    /**
     * @return The current strategy contract being used
     */
    function strategy() external view returns (IFusedETHStrategy);

    /**
     * transfer FusedETH to the recipient
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
}
