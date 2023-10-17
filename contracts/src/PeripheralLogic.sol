//SPDX License Identifier: MIT
pragma solidity >=0.8.0; 

import {ISwapRouter} from "./interfaces/ISwapRouter.sol"; import {IUniswapV3Factory} from "./interfaces/IFactory.sol"; 
import {ICurveFi} from "./interfaces/ICurveFi.sol"; 
import {IWETH} from "./interfaces/IWeth.sol"; 
import {ICamelotRouter} from "./interfaces/ICamelotRouter.sol"; 
import {ICamelotPair} from "./interfaces/ICamelotPair.sol"; 
import {IVault, IAsset} from "./interfaces/IBalancerVault.sol"; 
import {IBTokenMappings} from "./IBTokenMappings.sol"; 
import {IERC20} from "forge-std/interfaces/IERC20.sol"; 
import {FlashLoanLiquidation} from "./FlashLoanLiquidationV3.sol"; 


import "forge-std/Test.sol";

contract PeripheralLogic is Test {

	enum Protocol {
		CURVE,
        BALANCER,
        CAMELOT,
        CHRONOS, //for later
        GMX, //for later
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
       
    //v2 seems to have more liquidity rn, so we'll wrap that 
    ICamelotRouter internal camelotRouter = 
        ICamelotRouter(0xc873fEcbd354f5A56E00E710B90EF4201db2448d); 

	address internal constant camelotv2Factory = 0x6EcCab422D763aC031210895C81787E87B43A652; 

	bytes32 internal constant SHAGHAI_SHAKEDOWN = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b; 
    
    //univ3
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

	//unwraps any vault or lp token to a base token, either USDC.e or WETH
	function _unwrapIBToken(address collateralAsset, Protocol protocol) external returns (uint256, address) {
		if (protocol == Protocol.CURVE) { 
			address underlyingToSwapFor = tokenMappings.tokenMappings(collateralAsset); //WETH or USDC

			uint256 amountWithdrawnFromCurve =
			   	_unwrapCurveToken(collateralAsset, underlyingToSwapFor); 
			//curve now unwrapped to base USDC or WETH
			IERC20(underlyingToSwapFor).transfer(address(flashLoanLiquidation), amountWithdrawnFromCurve);
			return (amountWithdrawnFromCurve, underlyingToSwapFor);

		} else if (protocol == Protocol.CAMELOT) {
				
			address underlyingToSwapFor = tokenMappings.tokenMappings(collateralAsset); //WETH or USDC
			uint256 amountLP = 
				IERC20(collateralAsset).balanceOf(address(this)); 	

			//underlying Camelot lp
            address token0 = ICamelotPair(collateralAsset).token0(); 
            address token1 = ICamelotPair(collateralAsset).token1(); 
			console.log("token0", token0); 
			console.log("token1", token1); 
			console.log("amount lp", amountLP); 

			_removeCamelotLiquidity(collateralAsset, token0, token1, amountLP); 

			//swap for underlying desired
			uint256 amountToSwap; 
			if (token0 == underlyingToSwapFor) { 
				amountToSwap = IERC20(token1).balanceOf(address(this)); 
				_swapCamelot(token1, token0, amountToSwap); 
			 } else {
				amountToSwap = IERC20(token0).balanceOf(address(this)); 
				_swapCamelot(token0, token1, amountToSwap); 
			 }
				return (IERC20(underlyingToSwapFor).balanceOf(address(flashLoanLiquidation)),
								underlyingToSwapFor);

		} else if (protocol == Protocol.BALANCER) { //BPT withdraw
			//balancer API
			bytes32 poolId = tokenMappings.balancerLookup(collateralAsset); 
			console.logBytes32(poolId); 
			(IERC20[] memory poolTokens, , ) = balancerVault.getPoolTokens(poolId); 


			uint256 exitTokenIndex; //WETH
			if (poolId == SHAGHAI_SHAKEDOWN) {
				exitTokenIndex = 1; 
			} else {
				exitTokenIndex = 0; 
			}

			_withdrawBalancer(
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
    
    //TODO: redo for current curve tokens
	function _unwrapCurveToken(address collateralAsset, address underlyingToSwapFor) internal returns(uint256) {

		uint256 amountWithdrawnFromCurve; 	
		uint256 amountUnderlyingLP; 

		if (underlyingToSwapFor == tokenMappings.WETH()) {

			//checking for ether
			uint256 beforeEthBalance = address(this).balance; 
			amountUnderlyingLP = 
				IERC20(tokenMappings.wstETH_CRV_LP()).balanceOf(address(this)); 
			ICurveFi curvePool = ICurveFi(tokenMappings.wstETH_CRV_POOL()); 

			//remove liquidity from curve, get ETH back
			curvePool.remove_liquidity_one_coin(amountUnderlyingLP, 0, 1); //slippage @ 1 for now
			uint256 afterEthbalance = address(this).balance; 
			uint256 ethDif = afterEthbalance - beforeEthBalance;
			IWETH(tokenMappings.WETH()).deposit{value: ethDif}(); 

			amountWithdrawnFromCurve = IERC20(tokenMappings.WETH()).balanceOf(address(this)); 

		} else {
			if (collateralAsset == tokenMappings.CRV_USDCE_USDT()) {
			amountUnderlyingLP = 
				IERC20(tokenMappings.CRV_USDCE_USDT()).balanceOf(address(this)); 
			ICurveFi curvePool = ICurveFi(tokenMappings.CRV_USDCE_USDT()); 
			curvePool.remove_liquidity_one_coin(amountUnderlyingLP, 0, 1);
			} else {
			amountUnderlyingLP = 
				IERC20(tokenMappings.CRV_FRAX_USDCE()).balanceOf(address(this)); 
			ICurveFi curvePool = ICurveFi(tokenMappings.CRV_FRAX_USDCE()); 
			curvePool.remove_liquidity_one_coin(amountUnderlyingLP, 1, 1);
			}

			amountWithdrawnFromCurve =
				IERC20(tokenMappings.USDC()).balanceOf(address(this)); 
		}
		
		return amountWithdrawnFromCurve; 

	}

	function _removeCamelotLiquidity(
		address lpToken,
		address token0, 
		address token1,
		uint256 amount
	) internal returns (uint256) {
			
			//remove liquidity via router
			IERC20(lpToken).approve(address(camelotRouter), amount); 
			camelotRouter.removeLiquidity(	
				token0,
				token1,
				amount,
				0, //can use quote
				0, //can use quote
				address(this),
				block.timestamp
			); 
	}

	//swap using velo, easiest to do, maybe not the best liquidity(?)
	function _swapCamelot(
		address from, 
		address to,
	    uint256 amountIn
	) internal returns (uint256[] memory) {

        address[] memory path = new address[](2); 
        path[0] = from; 
        path[1] = to; 

		IERC20(from).approve(address(camelotRouter), amountIn); 
		camelotRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
			amountIn,
			0,
			path,
			address(flashLoanLiquidation), 
			address(0), //ref
			block.timestamp //deadline
		);
	}
    
    //TODO: tweak this for all balancer pools
	function _withdrawBalancer(
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
