// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {IFlashLoanSimpleReceiver} from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

// ShibaSwap Router Interface
interface IShibaSwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

// SushiSwap Router Interface
interface ISushiSwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract Flashb9 is ReentrancyGuard, IFlashLoanSimpleReceiver {
    using SafeERC20 for IERC20;

    address public immutable owner;
    ISwapRouter public immutable uniswapRouter;
    IQuoter public immutable uniswapQuoter;
    IShibaSwapRouter public immutable shibaSwapRouter;
    ISushiSwapRouter public immutable sushiSwapRouter;
    IPool public immutable aavePool;
    IPoolAddressesProvider public immutable addressesProvider;

    // Tokens
    IERC20 public immutable wethToken;
    IERC20 public immutable usdcToken;
    IERC20 public immutable usdtToken;
    IERC20 public immutable shibToken;
    IERC20 public immutable sushiToken;
    IERC20 public immutable daiToken;
    IERC20 public immutable wbtcToken;

    // Config
    uint256 public constant FLASH_LOAN_FEE_BPS = 9; // 0.09%
    uint256 public constant MIN_PROFIT = 100_000; // 0.1 USDC (6 decimals)
    uint24 public constant UNISWAP_POOL_FEE = 3000; // 0.3%
    uint256 public constant SLIPPAGE_TOLERANCE_BPS = 9900; // 1% slippage
    uint256 public constant ARB_DEADLINE = 300; // 5 minutes
    uint256 public constant SWEEP_COOLDOWN = 86400; // 24 hours
    uint256 public lastActive;

    // Enum for exchange protocols
    enum ExchangeProtocol { UniswapV3, ShibaSwap, SushiSwap }

    // Enum for trading paths
    enum TradingPath {
        USDC_USDT_USDC,
        USDC_SHIB_USDC,
        USDC_WETH_USDC,
        USDC_DAI_USDC,
        USDC_WBTC_USDC,
        USDC_SHIB_USDT_USDC
    }

    event ArbitrageExecuted(address indexed token, uint256 amount, uint256 profit, ExchangeProtocol protocol, TradingPath path);
    event ArbitrageFailed(string reason);
    event TokensWithdrawn(address indexed token, uint256 amount);
    event FlashLoanRequested(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _uniswapRouter,
        address _uniswapQuoter,
        address _shibaSwapRouter,
        address _sushiSwapRouter,
        address _aavePool,
        address _addressesProvider,
        address _wethToken,
        address _usdcToken,
        address _usdtToken,
        address _shibToken,
        address _sushiToken,
        address _daiToken,
        address _wbtcToken
    ) {
        owner = msg.sender;
        uniswapRouter = ISwapRouter(_uniswapRouter);
        uniswapQuoter = IQuoter(_uniswapQuoter);
        shibaSwapRouter = IShibaSwapRouter(_shibaSwapRouter);
        sushiSwapRouter = ISushiSwapRouter(_sushiSwapRouter);
        aavePool = IPool(_aavePool);
        addressesProvider = IPoolAddressesProvider(_addressesProvider);
        wethToken = IERC20(_wethToken);
        usdcToken = IERC20(_usdcToken);
        usdtToken = IERC20(_usdtToken);
        shibToken = IERC20(_shibToken);
        sushiToken = IERC20(_sushiToken);
        daiToken = IERC20(_daiToken);
        wbtcToken = IERC20(_wbtcToken);
        lastActive = block.timestamp;
    }

    // Fixed: Added 'view' to match interface
    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {
        return addressesProvider;
    }

    // Fixed: Added 'view' to match interface
    function POOL() external view override returns (IPool) {
        return aavePool;
    }

    /// @notice Initiate a flash loan from Aave
    function requestFlashLoan(address token, uint256 amount) external onlyOwner {
        require(token == address(usdcToken), "Only USDC supported");
        emit FlashLoanRequested(token, amount);
        aavePool.flashLoanSimple(address(this), token, amount, "", 0);
    }

    /// @notice Aave flash loan callback
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata /* params */
    ) external override nonReentrant returns (bool) {
        require(msg.sender == address(aavePool), "Unauthorized");
        require(initiator == address(this), "Invalid initiator");
        require(token == address(usdcToken), "Only USDC supported");

        uint256 totalRepay = amount + fee;
        (uint256 profit, ExchangeProtocol protocol, TradingPath path) = _simulateArbitrage(token, amount, totalRepay);

        if (profit < MIN_PROFIT) {
            emit ArbitrageFailed("No profitable arbitrage");
            revert("No profitable arbitrage");
        }

        if (protocol == ExchangeProtocol.UniswapV3) {
            _executeUniswapV3Arb(token, amount, totalRepay, path);
        } else if (protocol == ExchangeProtocol.ShibaSwap) {
            _executeShibaSwapArb(token, amount, totalRepay, path);
        } else if (protocol == ExchangeProtocol.SushiSwap) {
            _executeSushiSwapArb(token, amount, totalRepay, path);
        }

        // Approve Aave for repayment
        _approveTokenIfNeeded(usdcToken, address(aavePool), totalRepay);

        // Ensure we have enough to repay
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance >= totalRepay, "Insufficient balance for repayment");

        // Transfer profit to owner
        uint256 finalProfit = balance - totalRepay;
        if (finalProfit > 0) {
            usdcToken.safeTransfer(owner, finalProfit);
        }

        emit ArbitrageExecuted(token, amount, finalProfit, protocol, path);
        return true;
    }

    /// @notice Execute arbitrage manually (for testing)
    function executeArbitrage(
        address token,
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(token == address(usdcToken), "Only USDC supported");
        uint256 balance = usdcToken.balanceOf(address(this));
        require(balance >= amount, "Insufficient USDC balance");

        uint256 totalRepay = amount; // No fee for manual execution
        (uint256 profit, ExchangeProtocol bestProtocol, TradingPath bestPath) = _simulateArbitrage(token, amount, totalRepay);
        if (profit < MIN_PROFIT) {
            emit ArbitrageFailed("No profitable arbitrage");
            revert("No profitable arbitrage");
        }

        if (bestProtocol == ExchangeProtocol.UniswapV3) {
            _executeUniswapV3Arb(token, amount, totalRepay, bestPath);
        } else if (bestProtocol == ExchangeProtocol.ShibaSwap) {
            _executeShibaSwapArb(token, amount, totalRepay, bestPath);
        } else if (bestProtocol == ExchangeProtocol.SushiSwap) {
            _executeSushiSwapArb(token, amount, totalRepay, bestPath);
        }

        // Transfer profit to owner
        uint256 finalBalance = usdcToken.balanceOf(address(this));
        uint256 finalProfit = finalBalance - amount;
        if (finalProfit > 0) {
            usdcToken.safeTransfer(owner, finalProfit);
        }

        emit ArbitrageExecuted(token, amount, finalProfit, bestProtocol, bestPath);
    }

    /// @dev Simulate arbitrage
    function _simulateArbitrage(
        address token,
        uint256 amount,
        uint256 totalRepay
    ) internal returns (uint256 profit, ExchangeProtocol bestProtocol, TradingPath bestPath) {
        if (token != address(usdcToken)) {
            return (0, ExchangeProtocol.UniswapV3, TradingPath.USDC_USDT_USDC);
        }

        // Simulate UniswapV3 paths
        uint256 uniswapProfit1 = _simulateUniswapV3Arb(token, amount, totalRepay, TradingPath.USDC_USDT_USDC);
        uint256 uniswapProfit2 = _simulateUniswapV3Arb(token, amount, totalRepay, TradingPath.USDC_WETH_USDC);
        uint256 uniswapProfit3 = _simulateUniswapV3Arb(token, amount, totalRepay, TradingPath.USDC_DAI_USDC);
        uint256 uniswapProfit4 = _simulateUniswapV3Arb(token, amount, totalRepay, TradingPath.USDC_WBTC_USDC);

        // Simulate ShibaSwap paths
        uint256 shibaProfit1 = _simulateShibaSwapArb(token, amount, totalRepay, TradingPath.USDC_SHIB_USDC);
        uint256 shibaProfit2 = _simulateShibaSwapArb(token, amount, totalRepay, TradingPath.USDC_SHIB_USDT_USDC);

        // Simulate SushiSwap paths
        uint256 sushiProfit1 = _simulateSushiSwapArb(token, amount, totalRepay, TradingPath.USDC_USDT_USDC);
        uint256 sushiProfit2 = _simulateSushiSwapArb(token, amount, totalRepay, TradingPath.USDC_WETH_USDC);

        // Find the best profit across all options
        uint256 bestProfit = 0;

        // Check UniswapV3 paths
        if (uniswapProfit1 > bestProfit) {
            bestProfit = uniswapProfit1;
            bestProtocol = ExchangeProtocol.UniswapV3;
            bestPath = TradingPath.USDC_USDT_USDC;
        }
        if (uniswapProfit2 > bestProfit) {
            bestProfit = uniswapProfit2;
            bestProtocol = ExchangeProtocol.UniswapV3;
            bestPath = TradingPath.USDC_WETH_USDC;
        }
        if (uniswapProfit3 > bestProfit) {
            bestProfit = uniswapProfit3;
            bestProtocol = ExchangeProtocol.UniswapV3;
            bestPath = TradingPath.USDC_DAI_USDC;
        }
        if (uniswapProfit4 > bestProfit) {
            bestProfit = uniswapProfit4;
            bestProtocol = ExchangeProtocol.UniswapV3;
            bestPath = TradingPath.USDC_WBTC_USDC;
        }

        // Check ShibaSwap paths
        if (shibaProfit1 > bestProfit) {
            bestProfit = shibaProfit1;
            bestProtocol = ExchangeProtocol.ShibaSwap;
            bestPath = TradingPath.USDC_SHIB_USDC;
        }
        if (shibaProfit2 > bestProfit) {
            bestProfit = shibaProfit2;
            bestProtocol = ExchangeProtocol.ShibaSwap;
            bestPath = TradingPath.USDC_SHIB_USDT_USDC;
        }

        // Check SushiSwap paths
        if (sushiProfit1 > bestProfit) {
            bestProfit = sushiProfit1;
            bestProtocol = ExchangeProtocol.SushiSwap;
            bestPath = TradingPath.USDC_USDT_USDC;
        }
        if (sushiProfit2 > bestProfit) {
            bestProfit = sushiProfit2;
            bestProtocol = ExchangeProtocol.SushiSwap;
            bestPath = TradingPath.USDC_WETH_USDC;
        }

        return (bestProfit, bestProtocol, bestPath);
    }

    /// @dev Simulate Uniswap V3 arbitrage
    function _simulateUniswapV3Arb(
        address token,
        uint256 amount,
        uint256 totalRepay,
        TradingPath path
    ) internal returns  (uint256) {
        if (token != address(usdcToken)) return 0;

        bytes memory uniswapPath;

        if (path == TradingPath.USDC_USDT_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(usdtToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else if (path == TradingPath.USDC_WETH_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(wethToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else if (path == TradingPath.USDC_DAI_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(daiToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else if (path == TradingPath.USDC_WBTC_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(wbtcToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else {
            return 0;
        }

        try uniswapQuoter.quoteExactInput(uniswapPath, amount) returns (uint256 amountOut) {
            return amountOut > totalRepay ? amountOut - totalRepay : 0;
        } catch {
            return 0;
        }
    }
//*****************************************************
    /// @dev Simulate ShibaSwap arbitrage (now marked as `view`)
function _simulateShibaSwapArb(
    address token,
    uint256 amount,
    uint256 totalRepay,
    TradingPath path
) internal view returns (uint256) {  // <-- Added `view`
    if (token != address(usdcToken)) return 0;

    address[] memory shibaPath;
    if (path == TradingPath.USDC_SHIB_USDC) {
        shibaPath = new address[](3);
        shibaPath[0] = address(usdcToken);
        shibaPath[1] = address(shibToken);
        shibaPath[2] = address(usdcToken);
    } else if (path == TradingPath.USDC_SHIB_USDT_USDC) {
        shibaPath = new address[](4);
        shibaPath[0] = address(usdcToken);
        shibaPath[1] = address(shibToken);
        shibaPath[2] = address(usdtToken);
        shibaPath[3] = address(usdcToken);
    } else {
        return 0;
    }

    try shibaSwapRouter.getAmountsOut(amount, shibaPath) returns (uint256[] memory amounts) {
        uint256 amountOut = amounts[amounts.length - 1];
        return amountOut > totalRepay ? amountOut - totalRepay : 0;
    } catch {
        return 0;
    }
}


//////////////////////////////////////////////////////////////////
    /// @dev Simulate SushiSwap arbitrage
    function _simulateSushiSwapArb(
        address token,
        uint256 amount,
        uint256 totalRepay,
        TradingPath path
    ) internal view returns (uint256) {
        if (token != address(usdcToken)) return 0;

        address[] memory sushiPath;
        if (path == TradingPath.USDC_USDT_USDC) {
            sushiPath = new address[](3);
            sushiPath[0] = address(usdcToken);
            sushiPath[1] = address(usdtToken);
            sushiPath[2] = address(usdcToken);
        } else if (path == TradingPath.USDC_WETH_USDC) {
            sushiPath = new address[](3);
            sushiPath[0] = address(usdcToken);
            sushiPath[1] = address(wethToken);
            sushiPath[2] = address(usdcToken);
        } else {
            return 0;
        }

        try sushiSwapRouter.getAmountsOut(amount, sushiPath) returns (uint256[] memory amounts) {
            uint256 amountOut = amounts[amounts.length - 1];
            return amountOut > totalRepay ? amountOut - totalRepay : 0;
        } catch {
            return 0;
        }
    }

    /// @dev Execute Uniswap V3 arbitrage
    function _executeUniswapV3Arb(
        address token,
        uint256 amount,
        uint256 totalRepay,
        TradingPath path
    ) internal {
        require(token == address(usdcToken), "Only USDC supported");

        bytes memory uniswapPath;

        if (path == TradingPath.USDC_USDT_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(usdtToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else if (path == TradingPath.USDC_WETH_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(wethToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else if (path == TradingPath.USDC_DAI_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(daiToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else if (path == TradingPath.USDC_WBTC_USDC) {
            uniswapPath = abi.encodePacked(
                address(usdcToken),
                UNISWAP_POOL_FEE,
                address(wbtcToken),
                UNISWAP_POOL_FEE,
                address(usdcToken)
            );
        } else {
            revert("Invalid Uniswap path");
        }

        // Approve Uniswap router
        _approveTokenIfNeeded(usdcToken, address(uniswapRouter), amount);

        uint256 minOut = (totalRepay * SLIPPAGE_TOLERANCE_BPS) / 10000;
        uint256 amountOut = uniswapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: uniswapPath,
                recipient: address(this),
                deadline: block.timestamp + ARB_DEADLINE,
                amountIn: amount,
                amountOutMinimum: minOut
            })
        );
        require(amountOut >= totalRepay, "Insufficient output");
    }

    /// @dev Execute ShibaSwap arbitrage
    function _executeShibaSwapArb(
        address token,
        uint256 amount,
        uint256 totalRepay,
        TradingPath path
    ) internal {
        require(token == address(usdcToken), "Only USDC supported");
        require(
            path == TradingPath.USDC_SHIB_USDC || path == TradingPath.USDC_SHIB_USDT_USDC,
            "Invalid ShibaSwap path"
        );

        address[] memory shibaPath;
        if (path == TradingPath.USDC_SHIB_USDC) {
            shibaPath = new address[](3);
            shibaPath[0] = address(usdcToken);
            shibaPath[1] = address(shibToken);
            shibaPath[2] = address(usdcToken);
        } else {
            shibaPath = new address[](4);
            shibaPath[0] = address(usdcToken);
            shibaPath[1] = address(shibToken);
            shibaPath[2] = address(usdtToken);
            shibaPath[3] = address(usdcToken);
        }

        // Approve ShibaSwap router
        _approveTokenIfNeeded(usdcToken, address(shibaSwapRouter), amount);

        uint256 minOut = (totalRepay * SLIPPAGE_TOLERANCE_BPS) / 10000;
        uint256[] memory amounts = shibaSwapRouter.swapExactTokensForTokens(
            amount,
            minOut,
            shibaPath,
            address(this),
            block.timestamp + ARB_DEADLINE
        );

        require(amounts[amounts.length - 1] >= totalRepay, "Insufficient output");
    }

    /// @dev Execute SushiSwap arbitrage
    function _executeSushiSwapArb(
        address token,
        uint256 amount,
        uint256 totalRepay,
        TradingPath path
    ) internal {
        require(token == address(usdcToken), "Only USDC supported");
        require(
            path == TradingPath.USDC_USDT_USDC || path == TradingPath.USDC_WETH_USDC,
            "Invalid SushiSwap path"
        );

        address[] memory sushiPath;
        if (path == TradingPath.USDC_USDT_USDC) {
            sushiPath = new address[](3);
            sushiPath[0] = address(usdcToken);
            sushiPath[1] = address(usdtToken);
            sushiPath[2] = address(usdcToken);
        } else {
            sushiPath = new address[](3);
            sushiPath[0] = address(usdcToken);
            sushiPath[1] = address(wethToken);
            sushiPath[2] = address(usdcToken);
        }

        // Approve SushiSwap router
        _approveTokenIfNeeded(usdcToken, address(sushiSwapRouter), amount);

        uint256 minOut = (totalRepay * SLIPPAGE_TOLERANCE_BPS) / 10000;
        uint256[] memory amounts = sushiSwapRouter.swapExactTokensForTokens(
            amount,
            minOut,
            sushiPath,
            address(this),
            block.timestamp + ARB_DEADLINE
        );

        require(amounts[amounts.length - 1] >= totalRepay, "Insufficient output");
    }

    /// @dev Approve token if needed
    function _approveTokenIfNeeded(IERC20 token, address spender, uint256 amount) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < amount) {
            token.safeIncreaseAllowance(spender, amount - currentAllowance);
        }
    }

    /// @notice Withdraw tokens
    function withdrawTokens(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(token).safeTransfer(owner, balance);
        emit TokensWithdrawn(token, balance);
    }

    /// @notice Sweep function with cooldown
    function sweep(address token) external onlyOwner {
        require(block.timestamp - lastActive > SWEEP_COOLDOWN, "Too soon");
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(amount > 0, "No balance to sweep");
        IERC20(token).safeTransfer(owner, amount);
        lastActive = block.timestamp;
        emit TokensWithdrawn(token, amount);
    }

    // Prevent accidental ETH transfers
    receive() external payable {
        revert("ETH transfers not accepted");
    }
}