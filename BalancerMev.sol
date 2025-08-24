// SPDX-License-Identifier: MIT
// GROKIFIED-BALANCER
// last written 24/08/2025 22:10
// Rigged for Coinbase and REAL money
// Improved version of GROKMEVWPROTS

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Interface for Balancer's flash loan
interface IBalancerFlashLoan {
    function flashLoan(
        address receiver,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData
    ) external;
}

interface IUniswapV2Router {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn, uint amountOutMin,
        address[] calldata path, address to, uint deadline
    ) external returns (uint[] memory amounts);
}

contract GrokifiedAndProtocols is ReentrancyGuard {
    // Coinbase wallet
    address constant OWNER = 0x2e81D6d536Fff3F16e6d03b3A31743B28767e25b;

    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer Vault address
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address[] public assets = [USDT];
    address[] public routers = [UNISWAP_ROUTER];

    struct ArbOpportunity {
        address router;
        address assetOut;
        uint256 profit;
    }

    event ArbitrageExecuted(address indexed router, address indexed assetOut, uint256 profit);
    event FlashLoanRepaid(uint256 amount, uint256 premium);
    event ProfitSentToOwner(uint256 profit);

    function huntArb() external nonReentrant {
        address[] memory flashAssets = new address[](1);
        flashAssets[0] = USDT;
        uint256[] memory flashAmounts = new uint256[](1);
        flashAmounts[0] = 1000e6; // USDT has 6 decimals

        IBalancerFlashLoan(BALANCER_VAULT).flashLoan(
            address(this),
            flashAssets,
            flashAmounts,
            ""
        );
    }

    function findBestArb(
        address inputAsset,
        uint256 amountIn,
        address[] memory availableAssets,
        address[] memory availableRouters
    ) internal view returns (ArbOpportunity memory) {
        ArbOpportunity memory best;
        address[] memory path = new address[](2);
        path[0] = inputAsset;

        for (uint i = 0; i < availableRouters.length; i++) {
            for (uint j = 0; j < availableAssets.length; j++) {
                if (availableAssets[j] == inputAsset) continue;

                path[1] = availableAssets[j];
                uint[] memory out1 = IUniswapV2Router(availableRouters[i]).getAmountsOut(amountIn, path);
                if (out1.length < 2) continue;

                path[0] = availableAssets[j];
                path[1] = inputAsset;
                uint[] memory out2 = IUniswapV2Router(availableRouters[i]).getAmountsOut(out1[1], path);
                if (out2.length < 2) continue;

                uint256 profit = out2[1] > amountIn ? out2[1] - amountIn : 0;
                if (profit > best.profit) {
                    best.profit = profit;
                    best.router = availableRouters[i];
                    best.assetOut = availableAssets[j];
                }
            }
        }
        return best;
    }

    function executeArb(
        address router,
        address assetIn,
        address assetOut,
        uint256 amountIn
    ) internal nonReentrant {
        address[] memory path1 = new address[](2);
        path1[0] = assetIn;
        path1[1] = assetOut;
        IERC20(assetIn).approve(router, amountIn);
        IUniswapV2Router(router).swapExactTokensForTokens(
            amountIn,
            1,
            path1,
            address(this),
            block.timestamp
        );

        uint256 amountOut = IERC20(assetOut).balanceOf(address(this));
        address[] memory path2 = new address[](2);
        path2[0] = assetOut;
        path2[1] = assetIn;
        IERC20(assetOut).approve(router, amountOut);
        IUniswapV2Router(router).swapExactTokensForTokens(
            amountOut,
            1,
            path2,
            address(this),
            block.timestamp
        );

        emit ArbitrageExecuted(router, assetOut, amountOut - amountIn);
    }

    function executeOperation(
        address[] calldata flashLoanAssets,
        uint256[] calldata amounts
        //bytes calldata userData
    ) external nonReentrant returns (bool) {
        require(msg.sender == BALANCER_VAULT, "Caller must be Balancer Vault");
        require(flashLoanAssets.length == amounts.length, "Invalid input lengths");

        ArbOpportunity memory opportunity = findBestArb(flashLoanAssets[0], amounts[0], assets, routers);

        if (opportunity.profit > 0) {
            executeArb(opportunity.router, flashLoanAssets[0], opportunity.assetOut, amounts[0]);
        }

        for (uint i = 0; i < flashLoanAssets.length; i++) {
            uint256 amount = amounts[i];
            IERC20(flashLoanAssets[i]).approve(BALANCER_VAULT, amount);
        }

        uint256 profitFinal = IERC20(flashLoanAssets[0]).balanceOf(address(this)) - amounts[0];
        if (profitFinal > 0) {
            IERC20(flashLoanAssets[0]).transfer(OWNER, profitFinal);
            emit ProfitSentToOwner(profitFinal);
        }

        return true;
    }

    receive() external payable {}
}