// SPDX-License-Identifier: MIT
//GROKIFIED3
// last written 23/08/2025 17:15
// iMPROVED VERSION OF GROKMEVWPROTS

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


//PROTOCOLS AND TIKENS AREA
//METAMASK
//address constant OWNER = 0x551CD6C342B864359CfD4B0833C0ce8EeADC543C;
//COINBASE WALLET
//address constant OWNER = 0x2e81D6d536Fff3F16e6d03b3A31743B28767e25b;

//address constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
//address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
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

// PROTOCOL ROUTER ADDRESSES WITH ADDITIONAL PROTOCOLS
//address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant SushiSwap_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
address constant Balancer_ROUTER = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant Curve_ROUTER = 0x99a58482BD75cbab83b27EC03CA68fF489b5788f;
address constant PancakeSwap_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4;
//ADDITIONAL PROTOCOLS FROM PROTOCOLADRESSES.ODT
address constant Native = 0x0f9f2366C6157F2aCD3C2bFA45Cd9031c152D2Cf;
address constant PancakeSwapV3 = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
address constant tanX = 0x36B6972580dAB5116E2701DA06232FcBd66BEc71;
address constant Bunni = 0x000000C396558ffbAB5Ea628f39658Bdf61345b3;
address constant SolidlyV3 = 0x53cCe50D77f4E18C8Bb633Dd1C2fBE99e0fB71bE;
address constant BalancerV2 = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant Bancor = 0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C;
address constant  PancakeSwapV2 = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
address constant Loopring = 0x0BABA1Ad5bE3a5C0a66E7ac838a129Bf948f1eA4;
address constant DODO = 0x43Dfc4159D86F3A37A5A4B3D4580b888ad7d4DDd;
address constant FranxswapV2 = 0xC14d550632db8592D1243Edc8B95b0Ad06703867;
address constant Smardex = 0x5DE8ab7E27f6E7A1fFf3E5B337584Aa43961BEeF;
address constant DefiSwap = 0xCeB90E4C17d626BE0fACd78b79c9c87d7ca181b3;
address constant Orion = 0x8fB00FDeBb4E83f2C58b3bcD6732AC1B6A7b7221;
address constant Verse = 0x249cA82617eC3DfB2589c4c17ab7EC9765350a18;
address constant MaverickProtocol = 0x7448c7456a97769F6cD04F1E83A4a23cCdC46aBD;
address constant SushiswapV3 = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;






contract GrokifiedAndProtocols is ReentrancyGuard {
    address constant OWNER = 0x2e81D6d536Fff3F16e6d03b3A31743B28767e25b;
    address constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
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