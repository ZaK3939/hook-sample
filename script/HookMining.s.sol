// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { HookMiner } from "v4-periphery/src/utils/HookMiner.sol";

/// @dev Replace import with your own hook
import { FusedHooks } from "../src/FusedHooks.sol";
import { FusedETH } from "../src/FusedETH.sol";
import { IWETH } from "../src/interfaces/IWETH.sol";

/// @notice Mines the address and deploys the FusedHooks Hook contract
contract DeployHookScript is Script {
    address public deployer;

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant weth = 0x4200000000000000000000000000000000000006; // WETH on Base

    /// @dev Replace with the desired PoolManager on its corresponding chain
    IPoolManager constant POOLMANAGER = IPoolManager(address(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543));

    function setUp() public virtual {
        string memory mnemonic = vm.envString("MNEMONIC");
        (deployer,) = deriveRememberKey(mnemonic, 0);
        console.log("Deployer:", deployer);
    }

    function run() public {
        // hook contracts must have specific flags encoded in the address
        // FusedHooks implements these hooks:
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        vm.startBroadcast();

        // 1. First deploy the FusedETH token
        IWETH WETH = IWETH(weth);
        FusedETH fusedETHToken = new FusedETH(WETH, deployer);

        // 2. Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(address(POOLMANAGER), fusedETHToken);

        // 3. Find a hook address with the appropriate flags
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(FusedHooks).creationCode, constructorArgs);

        console.log("Computed Hook Address:", hookAddress);
        console.log("Salt:", vm.toString(salt));

        // 4. Deploy the hook using CREATE2
        // Use the salt value to deploy to a specific address
        FusedHooks hook = new FusedHooks{ salt: salt }(address(POOLMANAGER), fusedETHToken);

        // 5. Verify that the address matches
        require(address(hook) == hookAddress, "Hook address mismatch");

        console.log("Successfully deployed FusedHooks at:", address(hook));
        console.log("FusedETH token deployed at:", address(fusedETHToken));

        vm.stopBroadcast();
    }
}
