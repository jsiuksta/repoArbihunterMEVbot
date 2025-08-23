// SPDX-License-Identifier: MIT
//GROKIFIED
// last written 23/08/2025 11:16
pragma solidity ^0.8.21;

// Interfaces (unchanged for brevity)
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
}

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

// CONFIG (unchanged)
//METAMASK
//address constant OWNER = 0x551CD6C342B864359CfD4B0833C0ce8EeADC543C;
//COINBASE WALLET
address constant OWNER = 0x2e81D6d536Fff3F16e6d03b3A31743B28767e25b;

address constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant ETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant VMINT = 0xD7B2C1a7F3c67fB0EA57a7ef29bC1F18D7bE3195;
address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
address constant USDL = 0xbdC7c08592Ee4aa51D06C27Ee23D5087D65aDbcD;
address constant TREAT = 0xa02C49Da76A085e4E1EE60A6b920dDbC8db599F4;
address constant SSLP = 0x413075439B544CB6F580dFA56272ed13fdD8d90e;
address constant LEO = 0x2AF5D2aD76741191D15Dfe7bF6aC92d4Bd912Ca3;
address constant BGB = 0x54D2252757e1672EEaD234D27B1270728fF90581;
address constant SPX = 0xE0f63A424a4439cBE457D80E4f4b51aD25b2c56C;
address constant VIRTUAL = 0x44ff8620b8cA30902395A7bD3F2407e1A091BF73;
address constant UBEX = 0x6704B673c70dE9bF74C8fBa4b4bd748F0e2190E1;
address constant BLOCK = 0xCaB84bc21F9092167fCFe0ea60f5CE053ab39a1E;
address constant PLSPAD = 0x8a74BC8c372bC7f0E9cA3f6Ac0df51BE15aEC47A;
address constant BUSY = 0x5CB3ce6D081fB00d5f6677d196f2d70010EA3f4a;
address constant MANYU = 0x95AF4aF910c28E8EcE4512BFE46F1F33687424ce;
address constant TrueGBP = 0x00000000441378008EA67F4284A57932B1c000a5;
address constant GYEN = 0xC08512927D12348F6620a698105e1BAac6EcD911;
address constant EURC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
address constant XYO = 0x55296f69f40Ea6d20E478533C15A6B08B654E758;
address constant OKB = 0x75231F58b43240C9718Dd58B4967c5114342a86c;
address constant BAO = 0xCe391315b414D4c7555956120461D21808A69F3A;
address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
address constant SHIB = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
address constant PAXG = 0x45804880De22913dAFE09f4980848ECE6EcbAf78;
address constant GRT = 0xc944e90C64b2C2c7ea1aFF5E0Df0fF9C3b1e07f0;
address constant FET = 0xaEa46A603C19e2Fa1a8FbdEc44a5a5e887e90367;
address constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
address constant NEXO = 0xB62132e35a6Ca7Efe0CA0E4c6c3B9E8Ab5b3AE6a;
address constant ENS = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;
address constant PEPE = 0x6982508145454Ce325dDbE47a25d4ec3d2311933;
address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

// PROTOCOL ROUTER ADDRESSES (unchanged)
address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant SushiSwap_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
address constant Balancer_ROUTER = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant Curve_ROUTER = 0x99a58482BD75cbab83b27EC03CA68fF489b5788f;
address constant PancakeSwap_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;

contract ArbHunterGitCopilotMEVBot {
    // Asset and router lists
    address[] public assets = [
        USDT, USDC, ETH, WETH, VMINT, sUSDS, USDL, TREAT, SSLP, LEO, BGB, SPX, VIRTUAL, UBEX, BLOCK, PLSPAD, BUSY, MANYU, TrueGBP, GYEN, EURC, XYO, OKB, BAO, STETH, WBTC, DAI, LINK, SHIB, PAXG, GRT, FET, LDO, NEXO, ENS, PEPE, CRV
    ];
    address[] public routers = [
        UNISWAP_ROUTER, SushiSwap_ROUTER, Balancer_ROUTER, Curve_ROUTER, PancakeSwap_ROUTER
    ];

    // Struct to store arbitrage opportunity
    struct ArbOpportunity {
        address router;
        address assetOut;
        uint256 profit;
    }

    // Entry point: Find and execute arbitrage via flash loan
    function huntArb() external {
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

    // Helper function to find the best arbitrage opportunity
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

    // Helper function to execute arbitrage
    function executeArb(
        address router,
        address assetIn,
        address assetOut,
        uint256 amountIn
    ) internal {
        // First swap: assetIn -> assetOut
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

        // Second swap: assetOut -> assetIn
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
    }

    // AAVE flash loan callback
    function executeOperation(
        address[] calldata flashLoanAssets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator
        //bytes calldata params
    ) external returns (bool) {
        require(msg.sender == AAVE_POOL, "Caller must be AAVE");
        require(initiator == address(this), "Invalid initiator");

        // Find best arbitrage opportunity
        ArbOpportunity memory opportunity = findBestArb(flashLoanAssets[0], amounts[0], assets, routers);

        // Execute arbitrage if profitable
        if (opportunity.profit > 0) {
            executeArb(opportunity.router, assets[0], opportunity.assetOut, amounts[0]);
        }

        // Repay flash loan
        uint256 totalDebt = amounts[0] + premiums[0];
        IERC20(flashLoanAssets[0]).approve(AAVE_POOL, totalDebt);

        // Send profit to OWNER
        uint256 profitFinal = IERC20(flashLoanAssets[0]).balanceOf(address(this)) - totalDebt;
        if (profitFinal > 0) {
            IERC20(flashLoanAssets[0]).transfer(OWNER, profitFinal);
        }

        return true;
    }

    // Allow contract to receive ETH
    receive() external payable {}
}