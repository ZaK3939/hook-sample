// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { stdStorage, StdStorage } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { Deployers } from "@uniswap/v4-core/test/utils/Deployers.sol";
import { IPoolManager, PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { PoolModifyLiquidityTest } from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";

import { FusedETH } from "../src/FusedETH.sol";
import { PoolSwap } from "../src/zaps/PoolSwap.sol";
import { WETH9 } from "./tokens/WETH9.sol";

contract TestUtility is Deployers {
    using stdStorage for StdStorage;

    WETH9 internal WETH;

    address internal DEPLOYER = 0x6F0487c61e6CF1B6B00759888E37D8df38aCA4f0;

    constructor() { }

    /**
     * Sets up the logic to fork from a mainnet block, based on just an integer passed.
     *
     * @dev This should be applied to a constructor.
     */
    modifier forkBlock(uint256 blockNumber) {
        // Generate a mainnet fork
        uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));

        // Select our fork for the VM
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(blockNumber);

        // Confirm that our block number has set successfully
        require(block.number == blockNumber);
        _;
    }

    modifier forkBaseBlock(uint256 blockNumber) {
        // Generate a mainnet fork
        uint256 baseFork = vm.createFork(vm.rpcUrl("base"));

        // Select our fork for the VM
        vm.selectFork(baseFork);
        assertEq(vm.activeFork(), baseFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(blockNumber);

        // Confirm that our block number has set successfully
        require(block.number == blockNumber);
        _;
    }

    modifier forkBaseSepoliaBlock(uint256 blockNumber) {
        // Generate a mainnet fork
        uint256 baseSepoliaFork = vm.createFork(vm.rpcUrl("base_sepolia"));

        // Select our fork for the VM
        vm.selectFork(baseSepoliaFork);
        assertEq(vm.activeFork(), baseSepoliaFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(blockNumber);

        // Confirm that our block number has set successfully
        require(block.number == blockNumber);
        _;
    }

    function _assumeValidAddress(address _address) internal {
        // Ensure this is not a zero address
        vm.assume(_address != address(0));

        // Ensure that we don't match the test address
        vm.assume(_address != address(this));

        // Ensure that the address does not have known contract code attached
        vm.assume(_address != DEPLOYER);

        // Prevent the VM address from being referenced
        vm.assume(_address != 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // Finally, as a last resort, confirm that the target address is able
        // to receive ETH.
        vm.assume(payable(_address).send(0));
    }

    function _determineSqrtPrice(uint256 token0Amount, uint256 token1Amount) internal pure returns (uint160) {
        // Function to calculate sqrt price
        require(token0Amount > 0, "Token0 amount should be greater than zero");
        return uint160((token1Amount * (2 ** 96)) / token0Amount);
    }

    /**
     * Adds liquidity to a pool with the specified parameters
     *
     * @param poolModifyPosition The PoolModifyLiquidityTest instance to use for modifying liquidity
     * @param poolKey The pool key containing currency pair and other pool information
     * @param liquidityDelta The amount of liquidity to add (or remove if negative)
     */
    function _addLiquidityToPool(
        PoolModifyLiquidityTest poolModifyPosition,
        PoolKey memory poolKey,
        int256 liquidityDelta
    )
        internal
    {
        // Use a fixed amount for both tokens
        uint256 tokenAmount = 10e27;

        // Ensure we have enough tokens for liquidity and approve them for our {PoolManager}
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);

        // Handle token0 approvals
        if (token0 == address(0)) {
            // Handle native ETH case
            deal(address(WETH), address(this), tokenAmount);
            WETH.approve(address(poolModifyPosition), type(uint256).max);
        } else {
            deal(token0, address(this), tokenAmount);
            IERC20(token0).approve(address(poolModifyPosition), type(uint256).max);
        }

        // Handle token1 approvals
        if (token1 == address(0)) {
            // Handle native ETH case
            deal(address(WETH), address(this), tokenAmount);
            WETH.approve(address(poolModifyPosition), type(uint256).max);
        } else {
            deal(token1, address(this), tokenAmount);
            IERC20(token1).approve(address(poolModifyPosition), type(uint256).max);
        }

        // Modify our position with additional liquidity
        poolModifyPosition.modifyLiquidity(
            poolKey,
            IPoolManager.ModifyLiquidityParams({
                // Set our tick boundaries to full range
                tickLower: TickMath.minUsableTick(poolKey.tickSpacing),
                tickUpper: TickMath.maxUsableTick(poolKey.tickSpacing),
                liquidityDelta: liquidityDelta,
                salt: ""
            }),
            ""
        );

        // Advance time by 1 hour to simulate passage of time
        vm.warp(block.timestamp + 3600);
    }

    function _poolKeyZeroForOne(PoolKey memory poolKey) internal view returns (bool) {
        return Currency.unwrap(poolKey.currency0) == address(WETH);
    }

    function _normalizePoolKey(PoolKey memory poolKey) internal pure returns (PoolKey memory) {
        if (poolKey.currency0 >= poolKey.currency1) {
            (poolKey.currency0, poolKey.currency1) = (poolKey.currency1, poolKey.currency0);
        }
        return poolKey;
    }

    function _bypassFairLaunch() internal {
        vm.warp(block.timestamp + 365 days);
    }

    function _getSwapParams(int256 _amount) internal pure returns (IPoolManager.SwapParams memory) {
        return IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: _amount,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE
        });
    }
}
