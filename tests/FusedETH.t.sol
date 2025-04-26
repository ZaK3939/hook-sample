// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IHooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IPoolManager, PoolManager } from "@uniswap/v4-core/src/PoolManager.sol";
import { PoolId } from "@uniswap/v4-core/src/types/PoolId.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { PoolModifyLiquidityTest } from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";

import { HookMiner } from "v4-periphery/src/utils/HookMiner.sol";

import { AaveV3Strategy } from "../src/AaveV3Strategy.sol";
import { AaveV3WethGateway } from "../src/AaveV3WethGateway.sol";
import { FusedETH } from "../src/FusedETH.sol";
import { FusedHooks } from "../src/FusedHooks.sol";
import { IFusedETHStrategy } from "../src/interfaces/aaveV3/IFusedETHStrategy.sol";
import { IPool } from "../src/interfaces/aaveV3/IPool.sol";
import { IPoolAddressesProvider } from "../src/interfaces/aaveV3/IPoolAddressesProvider.sol";
import { IWrappedTokenGatewayV3 } from "../src/interfaces/aaveV3/IWrappedTokenGatewayV3.sol";
import { IWETH } from "../src/interfaces/IWETH.sol";
import { PoolSwap } from "../src/zaps/PoolSwap.sol";

import { TestUtility } from "./TestUtility.sol";

contract FusedETHIntegrationTest is TestUtility {
    // Contracts
    PoolManager internal poolManager;
    PoolModifyLiquidityTest internal poolModifyPosition;
    PoolSwap internal poolSwap;
    FusedETH public fusedETHToken;
    FusedHooks public fusedHooks;
    AaveV3Strategy public strategy;
    AaveV3WethGateway public wethGateway;

    // Contract addresses on Base
    address constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
    address constant AAVE_ADDRESSES_PROVIDER = 0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D;
    address constant AWETH_ADDRESS = 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7;
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // Test addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public yieldReceiver = makeAddr("yieldReceiver");

    // Pool key
    PoolKey public poolKey;
    PoolId public poolId;

    // Constants for testing
    // lib/v4-core/src/libraries/TickMath.sol
    uint160 constant MAX_SQRT_RATIO = TickMath.MAX_SQRT_PRICE;
    uint160 constant MIN_SQRT_RATIO = TickMath.MIN_SQRT_PRICE;

    function setUp() public forkBaseBlock(5_000_000) {
        // Deploy the Uniswap V4 {PoolManager}
        deployFreshManager();
        poolSwap = new PoolSwap(manager);
        poolModifyPosition = new PoolModifyLiquidityTest(manager);

        // Get WETH from address
        IWETH weth = IWETH(WETH_ADDRESS);

        // Deploy custom WETH Gateway

        wethGateway = new AaveV3WethGateway(WETH_ADDRESS, IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER));

        // Deploy FusedETH
        fusedETHToken = new FusedETH(weth, yieldReceiver);

        // Deploy AaveV3Strategy (using self-deployed gateway)
        strategy = new AaveV3Strategy(
            address(fusedETHToken),
            IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER),
            IWrappedTokenGatewayV3(address(wethGateway)),
            WETH_ADDRESS
        );

        // Deploy FusedHooks with proper CREATE2 approach
        // Define the hooks flags based on the permissions your hook needs
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(address(manager), fusedETHToken);

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(FusedHooks).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.startBroadcast();
        fusedHooks = new FusedHooks{ salt: salt }(address(manager), fusedETHToken);
        vm.stopBroadcast();

        require(address(fusedHooks) == hookAddress, "Hook address mismatch");

        // Configure PoolKey

        poolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO, // ETH
            currency1: Currency.wrap(address(fusedETHToken)), // fusedETH
            fee: 0, // fee
            tickSpacing: 1,
            hooks: IHooks(address(fusedHooks))
        });

        manager.initialize(poolKey, SQRT_PRICE_1_1);

        // Set strategy for fusedETH
        fusedETHToken.changeStrategy(IFusedETHStrategy(address(strategy)));

        // Distribute ETH for testing

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(address(this), 100 ether);

        // Supply ETH to WETH gateway (for testing)
        vm.deal(address(wethGateway), 10 ether);
    }

    function test_Deposit_Integration() public {
        // Alice deposits 1 ETH
        vm.prank(alice);
        fusedETHToken.deposit{ value: 1 ether }(0);

        // Verify that 1 fusedETH has been minted
        assertEq(fusedETHToken.balanceOf(alice), 1 ether);

        // Verify balance transfer to strategy (based on rebalanceThreshold)
        uint256 ethThreshold = (fusedETHToken.rebalanceThreshold() * fusedETHToken.totalSupply()) / 1 ether;

        // Keep the difference between actual ETH balance and threshold within acceptable range
        uint256 actualBalance = address(fusedETHToken).balance;
        assertApproxEqAbs(actualBalance, ethThreshold, 1e15); // Allow error of 0.001 ETH
    }

    function test_Withdraw_Integration() public {
        // Prerequisite: Alice deposits 1 ETH
        vm.prank(alice);
        fusedETHToken.deposit{ value: 1 ether }(0);

        // Alice withdraws 0.5 ETH
        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        fusedETHToken.withdraw(0.5 ether);

        // Verify that fusedETH was burned and ETH was transferred
        assertEq(fusedETHToken.balanceOf(alice), 0.5 ether);

        // Check approximate value since it won't match exactly due to gas costs
        assertApproxEqAbs(alice.balance - aliceBalanceBefore, 0.5 ether, 1e15);
    }

    function test_SwapEthToFusedEth_Integration() public {
        // Swap ETH to fusedETH
        vm.prank(alice);

        vm.deal(address(manager), 5 ether);
        // console.log("Using poolKey with currency1:", ));

        poolSwap.swap{ value: 1 ether }(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -1 ether, // Exact input amount
                sqrtPriceLimitX96: MAX_SQRT_RATIO - 1
            })
        );

        // Verify swap result
        assertGt(fusedETHToken.balanceOf(alice), 0.99 ether); // May be slightly less due to fees
    }

    function test_SwapFusedEthToEth_Integration() public {
        // Prepare 5 fusedETH tokens for PoolManager
        deal(address(fusedETHToken), address(manager), 5 ether);

        // Prepare 1 fusedETH token for Alice, simulating her initial balance
        deal(address(fusedETHToken), alice, 1 ether);

        // Provide ETH balance to FusedETH contract so it can successfully send ETH upon withdrawal
        vm.deal(address(fusedETHToken), 5 ether);

        // Mock the AaveV3Strategy's withdrawETH call (no actual logic, just prevents revert)
        vm.mockCall(address(strategy), abi.encodeWithSelector(AaveV3Strategy.withdrawETH.selector), abi.encode());

        // Alice approves PoolSwap to spend her fusedETH tokens
        vm.prank(alice);
        fusedETHToken.approve(address(poolSwap), 1 ether);

        // Record Alice's ETH balance before performing the swap
        uint256 aliceBalanceBefore = alice.balance;

        // Alice executes the swap: exchanging 1 fusedETH for ETH
        vm.prank(alice);
        poolSwap.swap(
            poolKey,
            IPoolManager.SwapParams({
                zeroForOne: false, // false indicates swap direction is fusedETH (token1) → ETH (token0)
                amountSpecified: -1 ether, // Negative indicates exact input amount (1 fusedETH)
                sqrtPriceLimitX96: MIN_SQRT_RATIO + 1 // Minimal limit, allows full swap range
             })
        );

        // Verify that Alice's ETH balance increased correctly (close to 1 ether, accounting for any minor deductions)
        assertGt(alice.balance - aliceBalanceBefore, 0.9 ether, "Alice's ETH balance did not increase sufficiently");

        // Verify that Alice's fusedETH balance is now zero, indicating successful swap completion
        assertEq(fusedETHToken.balanceOf(alice), 0, "Alice's fusedETH balance was not reduced to zero");
    }

    // Integration test with Aave (using custom gateway)
    function test_AaveWethGateway_Integration() public {
        // Mock: Simulate aWETH token behavior
        // In reality, we would need to get the aWETH token address from the Aave pool
        // and simulate operations on that token

        // Mock setup: Configure strategy to work with Aave
        address aavePool = IPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER).getPool();

        // Mock calls to Pool for WETH deposits
        vm.mockCall(
            aavePool,
            abi.encodeWithSelector(IPool.deposit.selector, WETH_ADDRESS, 0.9 ether, address(strategy), 0),
            abi.encode()
        );

        // Mock for aWETH token balance check
        vm.mockCall(
            AWETH_ADDRESS, abi.encodeWithSelector(IERC20.balanceOf.selector, address(strategy)), abi.encode(0.9 ether)
        );

        // Alice deposits 1 ETH
        vm.prank(alice);
        fusedETHToken.deposit{ value: 1 ether }(0);

        // Verify that strategy has aWETH after rebalancing
        assertEq(strategy.balanceInETH(), 0.9 ether);

        // Simulate time passing
        vm.roll(block.number + 1000);
        vm.warp(block.timestamp + 7 days);

        // Simulate yield by increasing aWETH balance
        vm.mockCall(
            AWETH_ADDRESS, abi.encodeWithSelector(IERC20.balanceOf.selector, address(strategy)), abi.encode(1.0 ether)
        );

        // Verify that yield has accumulated
        assertEq(fusedETHToken.yieldAccumulated(), 0.1 ether);

        // Simulate harvesting
        // Mock withdrawETH call
        vm.mockCall(
            AWETH_ADDRESS,
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(strategy), address(wethGateway), 0.1 ether),
            abi.encode(true)
        );

        vm.mockCall(
            aavePool,
            abi.encodeWithSelector(IPool.withdraw.selector, WETH_ADDRESS, type(uint256).max, address(wethGateway)),
            abi.encode(0.1 ether)
        );

        // Record yieldReceiver's balance before harvest
        uint256 receiverBalanceBefore = yieldReceiver.balance;

        // Execute harvest
        fusedETHToken.harvest();

        // Verify that ETH was sent to yieldReceiver after harvest
        assertEq(yieldReceiver.balance - receiverBalanceBefore, 0.1 ether);
    }
}
