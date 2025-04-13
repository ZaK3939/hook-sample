// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IPoolAddressesProvider } from "./IPoolAddressesProvider.sol";
import { IWrappedTokenGatewayV3 } from "./IWrappedTokenGatewayV3.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFusedETHStrategy {
    /**
     * @notice Deposits incoming ETH into Aave V3 and mints aWETH. The aWETH remains in this contract.
     */
    function convertETHToLST() external payable;

    /**
     * @notice Withdraws ETH from this contract's aWETH balance and sends it to the recipient.
     *
     * @param amount Amount of ETH to withdraw
     * @param recipient Address to receive the ETH
     */
    function withdrawETH(uint256 amount, address recipient) external;

    /**
     * @notice Returns the total ETH balance represented by the aWETH held by this contract
     */
    function balanceInETH() external view returns (uint256);

    /**
     * @notice Sets whether the strategy is currently unwinding
     *
     * @param isUnwinding_ New unwinding status
     */
    function setIsUnwinding(bool isUnwinding_) external;

    /**
     * @notice Allows the owner to unwind the strategy in small amounts into ETH (to avoid price impact)
     *
     * @param ethAmount Amount of ETH to unwind to
     */
    function unwindToETH(uint256 ethAmount) external;

    /**
     * @notice Emergency function to rescue trapped assets
     */
    function emergencyRescue() external;

    /**
     * @notice Returns the address of the fusedETH token
     */
    function fusedETH() external view returns (address);

    // /**
    //  * @notice Returns the addresses provider for Aave V3
    //  */
    // function addressesProvider() external view returns (IPoolAddressesProvider);

    // /**
    //  * @notice Returns the WETH gateway for Aave V3
    //  */
    // function wethGateway() external view returns (IWrappedTokenGatewayV3);

    // /**
    //  * @notice Returns the aWETH token address
    //  */
    // function aWETH() external view returns (IERC20);

    /**
     * @notice Returns whether the strategy is currently unwinding
     */
    function isUnwinding() external view returns (bool);
}
