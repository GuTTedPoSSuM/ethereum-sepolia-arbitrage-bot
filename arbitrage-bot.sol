// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ArbitrageBot is ReentrancyGuard {
    address public owner;
    ISwapRouter public uniswapRouter;
    IPoolAddressesProvider public provider;
    IPool public pool;
    AggregatorV3Interface public priceFeed;
    address public anotherTokenAddress;
    uint256 public maxSlippage;

    event FlashLoanInitiated(address indexed asset, uint256 amount);
    event TradeExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event FlashLoanRepaid(address indexed asset, uint256 amount);

    constructor(
        address _uniswapRouter,
        address _poolAddressesProvider,
        address _priceFeedAddress,
        address _anotherTokenAddress,
        uint256 _maxSlippage
    ) {
        owner = msg.sender;
        uniswapRouter = ISwapRouter(_uniswapRouter);
        provider = IPoolAddressesProvider(_poolAddressesProvider);
        pool = IPool(provider.getPool());
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
        anotherTokenAddress = _anotherTokenAddress;
        maxSlippage = _maxSlippage;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function executeArbitrageOpportunity(
        address asset,
        uint256 amount,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOutMinimum
    ) external onlyOwner {
        if (!isArbitrageProfitable(asset, amount, tokenIn, tokenOut, fee, amountOutMinimum)) {
            revert("Arbitrage not profitable");
        }
        
        executeFlashLoan(asset, amount);
        executeTrade(tokenIn, tokenOut, fee, amount, amountOutMinimum);
    }

    function isArbitrageProfitable(
        address asset,
        uint256 amount,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOutMinimum
    ) internal view returns (bool) {
        // TODO: Implement real profitability check
        uint256 expectedOut = amount * getTokenPrice(tokenIn) / getTokenPrice(tokenOut);
        return expectedOut > amountOutMinimum;
    }

    function getTokenPrice(address token) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function executeFlashLoan(
        address asset,
        uint256 amount
    ) internal {
        address receiverAddress = address(this);
        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256 mode = 0; // 0 for single asset flash loan
        bytes memory params = "";
        uint16 referralCode = 0;

        pool.flashLoanSimple(receiverAddress, asset, amount, params, referralCode);
        emit FlashLoanInitiated(asset, amount);
    }

    function executeTrade(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) internal returns (uint256 profit) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOutExpected = amountIn * getTokenPrice(tokenIn) / getTokenPrice(tokenOut);
        uint256 slippage = ((amountOutExpected - amountOutMinimum) * 10000) / amountOutExpected;
        
        require(slippage <= maxSlippage, "Slippage exceeds maximum");

        // Transfer tokens to this contract if they aren't already here
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);
        uint256 amountOut = uniswapRouter.exactInputSingle(params);
        
        emit TradeExecuted(tokenIn, tokenOut, amountIn, amountOut);

        // Simplified profit calculation
        profit = amountOut - amountIn;  
    }

    function flashLoanCallback(
        address asset,
        uint256 amount,
        uint256 premium,
        bytes calldata params
    ) external nonReentrant {
        require(msg.sender == address(pool), "Only the pool can trigger this callback");

        // Execute the arbitrage strategy here
        uint256 profit = executeTrade(asset, anotherTokenAddress, 3000, amount, 0);

        // Repay the flash loan
        uint256 totalToRepay = amount + premium;
        IERC20(asset).approve(address(pool), totalToRepay);
        pool.flashLoanSimple(address(this), asset, totalToRepay, params, 0);

        emit FlashLoanRepaid(asset, totalToRepay);
    }

    // Function to update max slippage
    function setMaxSlippage(uint256 _maxSlippage) external onlyOwner {
        maxSlippage = _maxSlippage;
    }
}