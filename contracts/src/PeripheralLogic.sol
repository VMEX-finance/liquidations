//SPDX License Identifier: MIT
pragma solidity >=0.8.0; 

import {ISwapRouter} from "./interfaces/ISwapRouter.sol"; import {IUniswapV3Factory} from "./interfaces/IFactory.sol"; 
import {IBeefyVault} from "./interfaces/IBeefyVault.sol"; 
import {ICurveFi} from "./interfaces/ICurveFi.sol"; 
import {IWETH} from "./interfaces/IWeth.sol"; 
import {IVeloPair} from "./interfaces/IVeloPair.sol"; 
import {IVeloRouter} from "./interfaces/IVeloRouter.sol"; 
import {IVault, IAsset} from "./interfaces/IBalancerVault.sol"; 
import {IYearnVault} from "./interfaces/IYearnVault.sol"; 
import {IBTokenMappings} from "./IBTokenMappings.sol"; 
import {IERC20} from "forge-std/interfaces/IERC20.sol"; 

import {FlashLoanLiquidation} from "./FlashLoanLiquidationV3.sol"; 

contract PeripheralLogic {

	enum Protocol {
		CURVE,
		VELODROME,
		BEETHOVEN,
		YEARN,
		NONE
	}

	struct Path {
		address tokenIn;
		uint24 fee; 
		bool isIBToken; //interest bearing, i.e. vault, lp, etc
		Protocol protocol;
	}

	struct SwapData {
		address to;
		address from;
		uint256 amount; 
		uint256 minOut;
		Path[] path; 
	}

	IBTokenMappings internal tokenMappings; 	
	FlashLoanLiquidation internal flashLoanLiquidation; 

	IVeloRouter internal constant veloRouter = 
		IVeloRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858); 

	address internal constant v2Factory = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a; 

	bytes32 internal constant SHAGHAI_SHAKEDOWN = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b; 
	
	ISwapRouter public swapRouter = 
		ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //same on ETH/OP/ARB/POLY

	IUniswapV3Factory internal factory =
		IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984); 

	IVault internal balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8); 


	constructor(IBTokenMappings _tokenMappings, FlashLoanLiquidation _flashLoanLiquidation) {
		tokenMappings = _tokenMappings; 	
		flashLoanLiquidation = _flashLoanLiquidation; 
	}

	//execute the swaps from the contract
	//assumes that optimal routes have already been processed
	//accepts the input token, swaps to the needed output token
	function _swap(SwapData memory swapData) external returns (uint256 amountOut) {
		uint256 swapLength = swapData.path.length; 
		IERC20(swapData.from).approve(address(swapRouter), swapData.amount); 
		if (swapLength == 1) {
			uint24 fee = swapData.path[0].fee; 
			ISwapRouter.ExactInputSingleParams memory params = 
				ISwapRouter.ExactInputSingleParams({
					tokenIn: swapData.from, //token we have from flashloan
					tokenOut: swapData.to, //debt asset we need
					fee: fee, 
					recipient: address(flashLoanLiquidation),
					deadline: block.timestamp,
					amountIn: swapData.amount,
					amountOutMinimum: swapData.minOut,
					sqrtPriceLimitX96: 0
			}); 

			amountOut = swapRouter.exactInputSingle(params); 
			return amountOut; 

		} else {
			bytes memory pre; 
			for (uint8 i = 0; i < swapData.path.length; i++) {
				bytes memory tokenAndFee = abi.encodePacked(
					swapData.path[i].tokenIn, 
					swapData.path[i].fee
				); 
				pre = abi.encodePacked(pre, tokenAndFee); 
			}

			bytes memory path = abi.encodePacked(pre, swapData.to); 

			ISwapRouter.ExactInputParams memory params = 
				ISwapRouter.ExactInputParams({
					path: path,
					recipient: address(flashLoanLiquidation),
					deadline: block.timestamp,
					amountIn: swapData.amount,
					amountOutMinimum: swapData.minOut	
				}); 	

			amountOut = swapRouter.exactInput(params); 
			return amountOut; 
		}
	}

	//unwraps a vault token if needed, can be curve, beefy, or beethoven
	function _unwrapIBToken(address collateralAsset, Protocol protocol) external returns (uint256, address) {
		if (protocol == Protocol.CURVE) { 
			//withdraw beefy LP
			address underlyingToSwapFor = tokenMappings.tokenMappings(collateralAsset); //WETH or USDC

			uint256 amountWithdrawnFromCurve =
			   	_unwrapCurveToken(collateralAsset, underlyingToSwapFor); 
			//curve now unwrapped to base USDC or WETH
			IERC20(underlyingToSwapFor).transfer(address(flashLoanLiquidation), amountWithdrawnFromCurve);
			return (amountWithdrawnFromCurve, underlyingToSwapFor);

		} else if (protocol == Protocol.VELODROME) { //velodrome
				
			address underlyingToSwapFor = tokenMappings.tokenMappings(collateralAsset); //WETH or USDC
			bool stable = tokenMappings.stable(collateralAsset); 
			uint256 amountLP = 
				IERC20(collateralAsset).balanceOf(address(this)); 	

			//underlying VELO lp
			(address token0, address token1) = IVeloPair(collateralAsset).tokens(); 
			_removeVeloLiquidity(collateralAsset, token0, token1, amountLP, stable); 

			//swap for underlying desired
			uint256 amountToSwap; 
			if (token0 == underlyingToSwapFor) { 
				amountToSwap = IERC20(token1).balanceOf(address(this)); 
				_swapVelo(token1, token0, amountToSwap, stable); 
			 } else {
				amountToSwap = IERC20(token0).balanceOf(address(this)); 
				_swapVelo(token0, token1, amountToSwap, stable); 
			 }
				return (IERC20(underlyingToSwapFor).balanceOf(address(flashLoanLiquidation)),
								underlyingToSwapFor);

		} else if (protocol == Protocol.YEARN) {
			//if collateral is any of these, we can attempt to flashloan any of these underlying
			//collat asset is vault 
			address underlyingToSwapFor = tokenMappings.tokenMappings(collateralAsset); //WETH or USDC
			IYearnVault yearnVault = IYearnVault(collateralAsset); 
			uint256 amountShares = 
				IERC20(collateralAsset).balanceOf(address(this)); 	
			uint256 amountWithdrawn = yearnVault.withdraw(amountShares, address(flashLoanLiquidation)); 
			return (amountWithdrawn, yearnVault.token()); 

		} else { //BPT withdraw
			//balancer API
			bytes32 poolId = tokenMappings.beetsLookup(collateralAsset); 
			(IERC20[] memory poolTokens, , ) = balancerVault.getPoolTokens(poolId); 

			uint256 exitTokenIndex; //WETH
			if (poolId == SHAGHAI_SHAKEDOWN) {
				exitTokenIndex = 1; 
			} else {
				exitTokenIndex = 0; 
			}

			_withdrawBeets(
				collateralAsset, 
				poolTokens[0], 
				poolTokens[1], 
				exitTokenIndex,
				poolId); 
			
			return (
						IERC20(tokenMappings.WETH()).balanceOf(address(flashLoanLiquidation)),
						tokenMappings.WETH()
					); 
		}
	}

	function _unwrapCurveToken(address collateralAsset, address underlyingToSwapFor) internal returns(uint256) {

		uint256 amountWithdrawnFromCurve; 	
		uint256 amountUnderlyingLP; 

		if (underlyingToSwapFor == tokenMappings.WETH()) {

			uint256 beefyShares = IERC20(collateralAsset).balanceOf(address(this)); 
			IBeefyVault beefyVault = IBeefyVault(collateralAsset); 
			beefyVault.withdraw(beefyShares); // --> receive underlying LP tokens

			//checking for ether
			uint256 beforeEthBalance = address(this).balance; 
			amountUnderlyingLP = 
				IERC20(tokenMappings.wstETH_CRV_LP()).balanceOf(address(this)); 
			ICurveFi curvePool = ICurveFi(tokenMappings.wstETH_CRV_POOL()); 

			//remove liquidity from curve, get ETH back
			//TODO approval needed?
			curvePool.remove_liquidity_one_coin(amountUnderlyingLP, 0, 1); //slippage @ 1 for now
			uint256 afterEthbalance = address(this).balance; 
			uint256 ethDif = afterEthbalance - beforeEthBalance; //leave some for gas
			IWETH(tokenMappings.WETH()).deposit{value: ethDif}(); 

			amountWithdrawnFromCurve = IERC20(tokenMappings.WETH()).balanceOf(address(this)); 

		} else {
			//USDC route//remove liquidity from sUSD pool, get 3crv tokens	
			amountUnderlyingLP = 
				IERC20(tokenMappings.sUSD_THREE_CRV()).balanceOf(address(this)); 
			ICurveFi curvePool = ICurveFi(tokenMappings.sUSD_THREE_CRV()); 
			curvePool.remove_liquidity_one_coin(amountUnderlyingLP, 1, 1);

			//now we can remove 3crv token liquidity and unwrap to USDC
			uint256 underlying3CrvAmount = 
					IERC20(tokenMappings.THREE_CRV()).balanceOf(address(this)); 
			ICurveFi crv3Pool = ICurveFi(tokenMappings.THREE_CRV()); 
			crv3Pool.remove_liquidity_one_coin(underlying3CrvAmount, 1, 1); 


			amountWithdrawnFromCurve = IERC20(tokenMappings.USDC()).balanceOf(address(this)); 
		}
		
		return amountWithdrawnFromCurve; 

	}

	function _removeVeloLiquidity(
		address lpToken,
		address token0, 
		address token1,
		uint256 amount, 
		bool stable
	) internal returns (uint256) {
			//get underlying VELO tokens via VeloPair
			
			//remove liquidity via router
			IERC20(lpToken).approve(address(veloRouter), amount); 
			veloRouter.removeLiquidity(	
				token0,
				token1,
				stable, 
				amount,
				0, //can use quote
				0, //can use quote
				address(this),
				block.timestamp
			); 
	}

	//swap using velo, easiest to do, maybe not the best liquidity(?)
	function _swapVelo(
		address from, 
		address to,
	  uint256 amountIn, 
		bool stable
	) internal returns (uint256[] memory) {
		IVeloRouter.Route[] memory route = new IVeloRouter.Route[](1); 
		route[0] = IVeloRouter.Route({
			from: from,
			to: to,
			stable: stable,
			factory: v2Factory
		}); 

		IERC20(from).approve(address(veloRouter), amountIn); 
		uint256[] memory amounts = veloRouter.swapExactTokensForTokens(
			amountIn,
			0,
			route,
			address(flashLoanLiquidation), 
			block.timestamp //deadline
		);
		
		return amounts;  	
	}

	function _withdrawBeets(
		address collateralAsset, 
		 IERC20 poolToken0, 
		 IERC20 poolToken1, 
		uint256 exitTokenIndex,
		bytes32 poolId
	) internal {

			uint256[] memory minAmountsOut = new uint256[](2);
			IERC20(collateralAsset).approve(
				address(balancerVault),
				IERC20(collateralAsset).balanceOf(address(this))
			); 

			bytes memory userData = abi.encode(
				IVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
				IERC20(collateralAsset).balanceOf(address(this)),
				exitTokenIndex	
			);

			IAsset[] memory assets = new IAsset[](2); 
				assets[0] = IAsset(address(poolToken0)); 
				assets[1] = IAsset(address(poolToken1)); 

			IVault.ExitPoolRequest memory exitPoolRequest = IVault.ExitPoolRequest({
				assets: assets,
				minAmountsOut: minAmountsOut,
				userData: userData,
				toInternalBalance: false //receive ERC20
			}); 

			//recieve WETH after exit
			balancerVault.exitPool(
				poolId, 
				address(this), //sender
				payable(address(flashLoanLiquidation)), //recipient
				exitPoolRequest
			); 

	}

	function addBytes(bytes memory base, bytes memory bytesToAdd) internal pure returns(bytes memory returnBytes) {
		returnBytes = abi.encodePacked(base, bytesToAdd); 
		return returnBytes; 
	}

	receive() external payable {} 

}
