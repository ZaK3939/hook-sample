// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IFusedETH } from "./interfaces/IFusedETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPoolAddressesProvider } from "./interfaces/aaveV3/IPoolAddressesProvider.sol";
import { IWrappedTokenGatewayV3 } from "./interfaces/aaveV3/IWrappedTokenGatewayV3.sol";
import { IPool } from "./interfaces/aaveV3/IPool.sol";
import { DataTypes } from "./libraries/aave/types/DataTypes.sol";

import { IFusedETHStrategy } from "./interfaces/aaveV3/IFusedETHStrategy.sol";

contract AaveV3Strategy is IFusedETHStrategy {
    address public immutable fusedETH;

    // AaveV3
    IPoolAddressesProvider private immutable addressesProvider;
    IWrappedTokenGatewayV3 private immutable wethGateway;
    IERC20 private immutable aWETH;

    bool public override isUnwinding;

    error CallerIsNotFusedETH();
    error CallerIsNotFusedETHOwner();

    constructor(
        address fusedETH_,
        IPoolAddressesProvider addressesProvider_,
        IWrappedTokenGatewayV3 wethGateway_,
        address weth_
    ) {
        fusedETH = fusedETH_;
        addressesProvider = addressesProvider_;
        wethGateway = wethGateway_;

        // fetch the aWETH address
        IPool aavePool = IPool(addressesProvider.getPool());
        DataTypes.ReserveData memory reserveData = aavePool.getReserveData(weth_);
        aWETH = IERC20(reserveData.aTokenAddress);
    }

    modifier isFusedETH() {
        if (msg.sender != fusedETH) revert CallerIsNotFusedETH();
        _;
    }

    modifier onlyFusedETHOwner() {
        if (msg.sender != IFusedETH(fusedETH).owner()) revert CallerIsNotFusedETHOwner();
        _;
    }

    /**
     * @notice Deposits incoming ETH into Aave V3 and mints aWETH. The aWETH remains in this contract.
     */
    function convertETHToLST() external payable override isFusedETH {
        address aavePool = addressesProvider.getPool();

        // deposit ETH into Aave
        wethGateway.depositETH{ value: msg.value }({ pool: aavePool, onBehalfOf: address(this), referralCode: 0 });
    }

    /**
     * @notice Withdraws ETH from this contract's aWETH balance and sends it to the recipient.
     *
     * @param amount Amount of ETH to withdraw
     * @param recipient Address to receive the ETH
     */
    function withdrawETH(uint256 amount, address recipient) external override isFusedETH {
        _withdrawFromAave(amount, recipient);
    }

    function balanceInETH() external view override returns (uint256) {
        return aWETH.balanceOf(address(this));
    }

    function setIsUnwinding(bool isUnwinding_) external override onlyFusedETHOwner {
        isUnwinding = isUnwinding_;
    }

    /**
     * @notice Allows the owner to unwind the strategy in small amounts into ETH (to avoid price impact)
     *
     * @param ethAmount Amount of ETH to unwind to
     */
    function unwindToETH(uint256 ethAmount) external override onlyFusedETHOwner {
        // withdraw ETH and send to the fusedETH contract
        _withdrawFromAave(ethAmount, fusedETH);
    }

    function emergencyRescue() external onlyFusedETHOwner {
        aWETH.transfer(msg.sender, aWETH.balanceOf(address(this)));
    }

    function _withdrawFromAave(uint256 amount, address receiver) internal {
        address aavePool = addressesProvider.getPool();

        // approve aWETH for withdrawal by the gateway
        aWETH.approve(address(wethGateway), amount);

        // withdraw ETH from Aave, and send to the receiver
        wethGateway.withdrawETH({ pool: aavePool, amount: amount, onBehalfOf: receiver });
    }
}
