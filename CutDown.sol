// SPDX-License-Identifier: MIT
// GrokifiedCutDown
// last written 23/08/20205 22:00
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IAaveFlashLoan {
    function flashLoan(
        address receiver,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IUniswapV2Router {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn, uint amountOutMin,
        address[] calldata path, address to, uint deadline
    ) external returns (uint[] memory amounts);
}

contract GrokifiedCutDown is ReentrancyGuard {
    address constant OWNER = 0x2e81D6d536Fff3F16e6d03b3A31743B28767e25b;
    address constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant  UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

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
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // No debt, flash loan

        IAaveFlashLoan(AAVE_POOL).flashLoan(
            address(this),
            flashAssets,
            flashAmounts,
            modes,
            address(this),
            "",
            0
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
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator
    ) external nonReentrant returns (bool) {
        require(msg.sender == AAVE_POOL, "Caller must be AAVE");
        require(initiator == address(this), "Invalid initiator");

        ArbOpportunity memory opportunity = findBestArb(flashLoanAssets[0], amounts[0], assets, routers);

        if (opportunity.profit > 0) {
            executeArb(opportunity.router, flashLoanAssets[0], opportunity.assetOut, amounts[0]);
        }

        uint256 totalDebt = amounts[0] + premiums[0];
        IERC20(flashLoanAssets[0]).approve(AAVE_POOL, totalDebt);

        emit FlashLoanRepaid(amounts[0], premiums[0]);

        uint256 profitFinal = IERC20(flashLoanAssets[0]).balanceOf(address(this)) - totalDebt;
        if (profitFinal > 0) {
            IERC20(flashLoanAssets[0]).transfer(OWNER, profitFinal);
            emit ProfitSentToOwner(profitFinal);
        }

        return true;
    }

    receive() external payable {}
}