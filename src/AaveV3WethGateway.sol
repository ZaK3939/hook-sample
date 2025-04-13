// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IWETH } from "./interfaces/IWETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPoolAddressesProvider } from "./interfaces/aaveV3/IPoolAddressesProvider.sol";
import { IPool } from "./interfaces/aaveV3/IPool.sol";
import { IWrappedTokenGatewayV3 } from "./interfaces/aaveV3/IWrappedTokenGatewayV3.sol";

/**
 * Modified from: https://vscode.blockscan.com/84532/0xF6Dac650dA5616Bc3206e969D7868e7c25805171 to handle off by 1 wei
 * reverts during withdraw.
 */
contract AaveV3WethGateway is IWrappedTokenGatewayV3 {
    IWETH public immutable WETH;
    IPool public immutable POOL;

    constructor(address weth_, IPoolAddressesProvider addressesProvider_) {
        WETH = IWETH(weth_);
        POOL = IPool(addressesProvider_.getPool());

        WETH.approve(address(POOL), type(uint256).max);
    }

    /**
     * @dev deposits WETH into the reserve, using native ETH. A corresponding amount of the overlying asset (aTokens)
     * is minted.
     * @param onBehalfOf address of the user who will receive the aTokens representing the deposit
     * @param referralCode integrators are assigned a referral code and can potentially receive rewards.
     *
     */
    function depositETH(
        address, // pool
        address onBehalfOf,
        uint16 referralCode
    )
        external
        payable
        override
    {
        WETH.deposit{ value: msg.value }();
        POOL.deposit(address(WETH), msg.value, onBehalfOf, referralCode);
    }

    /**
     * @dev withdraws the WETH _reserves of msg.sender.
     * @param amount amount of aWETH to withdraw and receive native ETH
     * @param to address of the user who will receive native ETH
     */
    function withdrawETH(
        address, // pool
        uint256 amount,
        address to
    )
        external
        override
    {
        IERC20 aWETH = IERC20(POOL.getReserveData(address(WETH)).aTokenAddress);

        // pull requested amount from caller
        aWETH.transferFrom(msg.sender, address(this), amount);

        // handling the edge case where the `userBalanace` calculated in the Pool logic is off by 1 wei.
        // So we pass `type(uint256).max` to withdraw the whole `userBalanace` calculated for this contract.
        uint256 amountWithdrawn = POOL.withdraw(
            address(WETH),
            type(uint256).max, // withdraw the whole balance of this contract
            address(this)
        );

        WETH.withdraw(amountWithdrawn);
        _safeTransferETH(to, amountWithdrawn);
    }

    /**
     * @dev transfer ETH to an address, revert if it fails.
     * @param to recipient of the transfer
     * @param value the amount to send
     */
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success,) = to.call{ value: value }(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }

    /**
     * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
     */
    receive() external payable {
        require(msg.sender == address(WETH), "Receive not allowed");
    }

    /**
     * @dev Revert fallback calls
     */
    fallback() external payable {
        revert("Fallback not allowed");
    }
}
