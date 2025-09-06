// SPDX-License-Identifier: MIT
// Last written 21:39 06/09/2025
pragma solidity ^0.8.20;

import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract USDCFlashLoanArb4 is IFlashLoanSimpleReceiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable owner;
    IPool public immutable aavePool;
    IPoolAddressesProvider public immutable addressesProvider;
    ISwapRouter public immutable uniswapRouter;
    IERC20 public immutable usdcToken;
    IERC20 public immutable usdtToken;
    uint256 public constant FLASH_LOAN_FEE = 0.0009e4; // 0.09% fee
    uint256 public constant MIN_PROFIT = 0.1e6; // Minimum 0.1 USDC profit
    uint256 public constant SLIPPAGE_TOLERANCE = 99; // 1% slippage

    event FlashLoanExecuted(uint256 amount, uint256 profit);
    event FlashLoanFailed(string reason);
    event TokensWithdrawn(address token, uint256 amount);

    constructor(
        address _aavePool,
        address _addressesProvider,
        address _uniswapRouter,
        address _usdcToken,
        address _usdtToken
    ) {
        owner = msg.sender;
        aavePool = IPool(_aavePool);
        addressesProvider = IPoolAddressesProvider(_addressesProvider);
        uniswapRouter = ISwapRouter(_uniswapRouter);
        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
    }

    // REQUIRED BY IFlashLoanSimpleReceiver
    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) 
    {
        return addressesProvider;
    }

    // REQUIRED BY IFlashLoanSimpleReceiver
    function POOL() external view override returns (IPool) 
    {
        return aavePool;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata /* params */
    ) external override nonReentrant returns (bool) {
        // Validate caller and parameters
        require(msg.sender == address(aavePool), "Unauthorized");
        require(initiator == address(this), "Invalid initiator");
        require(asset == address(usdcToken), "Only USDC supported");

        // Check contract has sufficient balance
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance >= amount + fee, "Insufficient balance");

        // Safe approval for Uniswap (using safeIncreaseAllowance)
        usdcToken.safeIncreaseAllowance(address(uniswapRouter), amount);

        // Encode Uniswap V3 path with fee tiers (USDC -> USDT -> USDC)
        bytes memory encodedPath = abi.encodePacked(
            address(usdcToken),
            uint24(3000), // 0.3% fee tier for USDC/USDT
            address(usdtToken),
            uint24(3000), // 0.3% fee tier for USDT/USDC
            address(usdcToken)
        );

        // Calculate minimum output with slippage tolerance
        uint256 minAmountOut = (amount * SLIPPAGE_TOLERANCE) / 100;

        // Execute swap via Uniswap V3
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: encodedPath,
            recipient: address(this),
            deadline: block.timestamp + 300,
            amountIn: amount,
            amountOutMinimum: minAmountOut
        });

        uniswapRouter.exactInput(params);

        // Verify arbitrage profit
        uint256 newBalance = usdcToken.balanceOf(address(this));
        require(newBalance >= amount + fee, "Arbitrage failed");

        uint256 profit = newBalance - (amount + fee);
        require(profit >= MIN_PROFIT, "Profit below threshold");

        // Repay flash loan + fee
        usdcToken.safeTransfer(msg.sender, amount + fee);

        // Transfer profit to owner
        usdcToken.safeTransfer(owner, profit);
        emit FlashLoanExecuted(amount, profit);

        return true;
    }

    // Emergency withdrawal for stuck tokens
    function withdrawToken(address token) external onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(amount > 0, "No balance");
        IERC20(token).safeTransfer(owner, amount);
        emit TokensWithdrawn(token, amount);
    }

    // Prevent accidental ETH transfers
    receive() external payable {
        revert("ETH transfers not accepted");
    }

    //sweep function
    uint256 public lastActive;
function sweep(address token) external onlyOwner {
    require(block.timestamp - lastActive > 1 days, "Too soon");
    uint256 amount = IERC20(token).balanceOf(address(this));
    IERC20(token).safeTransfer(owner, amount);
}

    //

   
}//eof