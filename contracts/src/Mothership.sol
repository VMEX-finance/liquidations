 //SPDX License Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol"; 
import {FlashLoanRouter} from "./Router.sol"; 
import {IUniswapV3Factory} from "./interfaces/IFactory.sol"; 
import {ISwapRouter} from "./interfaces/ISwapRouter.sol"; 


 contract Mothership {
	
	FlashLoanRouter public router;
	address public owner; 
	address public holdingAccount; //external team wallet

	IUniswapV3Factory internal constant v3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984); 
	ISwapRouter internal constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); 

	address internal constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; 

	constructor(FlashLoanRouter _router, address _holdingAccount) {
		router = _router; 
		owner = msg.sender; 
		holdingAccount = _holdingAccount; 
		IERC20(weth).approve(address(swapRouter), type(uint256).max); 
	}	

	modifier onlyOwner() {
		require(msg.sender == owner);
		_; 
	}

	modifier onlyFlashLoanContract() {
		require(msg.sender == router.FlashLoanLiquidator()); 
		_; 
	}

	function request(address token, uint256 amount) external onlyFlashLoanContract {
		address flashLoanContract = router.FlashLoanLiquidator(); 
		uint256 balanceOfToken = IERC20(token).balanceOf(address(this)); 
		if (balanceOfToken < amount) {
			if (token != weth) {
				uint24 fee = _getLowestPoolFee(token); 
				_swap(token, amount, fee); 
			}
		}
		
		IERC20(token).transfer(flashLoanContract, amount);  
	}

	function sweep(address token) external onlyOwner {
		uint256 balance = IERC20(token).balanceOf(address(this)); 
		IERC20(token).transfer(holdingAccount, balance); 	
	}	

	function setOwner(address newOwner) external onlyOwner {
		owner = newOwner; 
	}

	function setHoldingAccount(address newHoldingAccount) external onlyOwner {
		holdingAccount = newHoldingAccount; 
	}

	receive() external payable {

	}

	function _swap(address token, uint256 amount, uint24 fee) internal {
		uint256 totalUsdc = IERC20(weth).balanceOf(address(this)); 	
		ISwapRouter.ExactOutputSingleParams memory params = 
			ISwapRouter.ExactOutputSingleParams({
				tokenIn: weth,
       			tokenOut: token,
       			fee: fee,
       			recipient: address(this),
       			deadline: block.timestamp,
       			amountOut: amount,
       			amountInMaximum: totalUsdc,
       			sqrtPriceLimitX96: 0
			}); 

		swapRouter.exactOutputSingle(params);
	}

	//exclude 0.01% fee tier cuz of low liquidity for cbETH/WETH pair
	function _getLowestPoolFee(address token) internal view returns (uint24 fee) { 
		uint24[4] memory fees = [ uint24(100), uint24(500), uint24(3000), uint24(10000) ]; 	
		for (uint8 i = 0; i < fees.length; i++) {
			address pool = v3Factory.getPool(token, weth, fees[i]); 	
			if (pool != address(0)) {
				fee = fees[i]; 
			} else {
				revert("pool not found for token pair"); 
			}
		}
		return fee; 
	}

}
