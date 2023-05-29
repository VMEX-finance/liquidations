// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

//actual aave implementations
import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol"; 
//vmex lending pool
import {ILendingPool} from "./interfaces/ILendingPool.sol"; 
import {IERC20} from "forge-std/interfaces/IERC20.sol"; 
import {ISwapRouter} from "./interfaces/ISwapRouter.sol"; 
import {IUniswapV3Factory} from "./interfaces/IFactory.sol"; 
import {IBTokenMappings} from "./IBTokenMappings.sol"; 
import {IBeefyVault} from "./interfaces/IBeefyVault.sol"; 
import {ICurveFi} from "./interfaces/ICurveFi.sol"; 
import {IWETH} from "./interfaces/IWeth.sol"; 
import {IVeloPair} from "./interfaces/IVeloPair.sol"; 
import {IVeloRouter} from "./interfaces/IVeloRouter.sol"; 
import {IVault, IAsset} from "./interfaces/IBalancerVault.sol"; 

contract FlashLoanLiquidation is FlashLoanSimpleReceiverBase { 

	ILendingPool internal lendingPool; //vmex 
	IPoolAddressesProvider internal constant aaveAddressesProvider = 
		IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e); 

	IVeloRouter internal constant veloRouter = 
		IVeloRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f); 

	IBTokenMappings tokenMappings; 
	
	ISwapRouter internal swapRouter = 
		ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //same on ETH/OP/ARB/POLY
	IUniswapV3Factory internal factory =
		IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984); 

	IVault internal balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8); 
	

	struct Path {
		address tokenIn;
		uint24 fee; 
		bool isIBToken; //interest bearing, i.e. vault, lp, etc
		bool isStable; 
		uint8 protocol; //0 = curve, 1 = beefy, 2 = beethoven
		
	}

	struct SwapData {
		address to;
		address from;
		uint256 amount; 
		uint256 minOut;
		Path[] path; 
	}

	struct FlashLoanData {
		address collateralAsset;  
		address debtAsset;
		uint64 trancheId; 
		address user;
		uint256 debtAmount; 		
		SwapData swapData;
		Path[] reswapPath;
	}


	//NOTE: this is aave's address provider, not ours
	constructor(IBTokenMappings _tokenMappings)
		FlashLoanSimpleReceiverBase(aaveAddressesProvider) { 
			tokenMappings = _tokenMappings; 
	}

	//called automatically by AAVE lending pool
	function executeOperation(
    	address asset,
    	uint256 amount,
    	uint256 premium,
    	address initiator,
    	bytes calldata params
	) external override returns (bool){
	
	
	//TODO check if borrowed asset is what we need, do swaps as necessary
	FlashLoanData memory decodedParams = abi.decode(params, (FlashLoanData)); 
	
	//if we need to swap, this will contain the necessary tokens to swap to. If we do not need to swap, the tokens to and from will be the same. 
	//if not the same, then we swap to the appropriate token using sushi (it's deployed on all chains, easiest imo)
	//this will already be set by the node script, including amountsOut
	//
	//
	//reswap path is included due to the collateral potentially being a vault token, or some other interest bearing token 
	//where extra steps are needed to repay the flashloan
	
	//initial swap
	uint256 amountOut; 
	SwapData memory swapData = decodedParams.swapData; 
	if (swapData.to != swapData.from) { 
		amountOut = _swap(decodedParams.swapData); 
	}
		
	//vmex liquidation			
	lendingPool.liquidationCall(
		decodedParams.collateralAsset,
		decodedParams.debtAsset,
		decodedParams.trancheId,
		decodedParams.user,
		decodedParams.debtAmount,
		false //no vToken
	); 

	//after liquidation, receive a single asset of collateral of amount (debtAmount + liquidation bonus)	
	uint256 afterLiquidationBalance = 
		IERC20(decodedParams.collateralAsset).balanceOf(address(this)); 

	//unwrap if necessary -> swap back to floashloaned token
	//TODO: do unwraps
		//if vault -> we use the underlying token
	
	if (decodedParams.reswapPath[0].isIBToken == true) {
		_unwrapIBToken(
			decodedParams.collateralAsset, 
			decodedParams.reswapPath[0].protocol
		); 
	}
	
	//NOTE: may no longer need this, as we are unwrapping directly to the asset we flashloaned	
	SwapData memory reswapData = SwapData({
		to: swapData.from, 
		from: swapData.to,
		amount: afterLiquidationBalance, 
		minOut: 0, 
		path: decodedParams.reswapPath 
	}); 	

	uint256 amountAfterReswap = _swap(reswapData); 
	uint amountOwing = amount + premium; 

	//if not profitable, we will revert
	require(amountAfterReswap >= amountOwing); 


    IERC20(asset).approve(address(POOL), amountOwing);

	return true; 
  }
	
	//bot passes these params in
	function flashLoanCall(
		address collateralAsset, 
		address debtAsset,
		uint256 amountDebt,
		uint64 trancheId, 
		address user,
		SwapData memory swapData,
		Path[] memory reswapPath) public {


		bytes memory params = abi.encode(FlashLoanData({
			collateralAsset: collateralAsset,
			debtAsset: debtAsset,
			trancheId: trancheId,
			user: user,
			debtAmount: amountDebt,
			swapData: swapData,
			reswapPath: reswapPath})
		); 
		
		//TODO: 
		//ensure that USDC or WETH only is used to flashloan

		//flashloans will only ever be in USDC or WETH
		POOL.flashLoanSimple(
			address(this), //receiver
			debtAsset,
			amountDebt, 
			params, 
			0 //referral code
		); 
  }
	
	//execute the swaps from the contract
	//assumes that optimal routes have already been processed
	//accepts the input token, swaps to the needed output token
	function _swap(SwapData memory swapData) internal returns (uint256 amountOut) {
		uint256 swapLength = swapData.path.length; 
		IERC20(swapData.from).approve(address(swapRouter), swapData.amount); 

		if (swapLength == 1) {
			uint24 fee = swapData.path[0].fee; 

			ISwapRouter.ExactInputSingleParams memory params = 
				ISwapRouter.ExactInputSingleParams({
					tokenIn: swapData.from,
					tokenOut: swapData.to,
					fee: fee,
					recipient: address(this),
					deadline: block.timestamp,
					amountIn: swapData.amount,
					amountOutMinimum: swapData.minOut,
					sqrtPriceLimitX96: 0
			}); 

			amountOut = swapRouter.exactInputSingle(params); 
			return amountOut; 

		} else {

			bytes memory path = abi.encodePacked(
				swapData.path[0].tokenIn,
				swapData.path[0].fee,
				swapData.path[1].tokenIn, //WETH (probably)
				swapData.path[1].fee,
				swapData.to
			); 
			ISwapRouter.ExactInputParams memory params = 
				ISwapRouter.ExactInputParams({
					path: path,
					recipient: address(this),
					deadline: block.timestamp,
					amountIn: swapData.amount,
					amountOutMinimum: swapData.minOut	
				}); 	

			amountOut = swapRouter.exactInput(params); 
			return amountOut; 
		}
	}

	//unwraps a vault token if needed, can be curve, beefy, or beethoven
	function _unwrapIBToken(
		address collateralAsset, uint8 protocol) internal returns (uint256) {
		if (protocol == 0) { //curve
			//withdraw beefy LP
			address underlyingToSwapFor = tokenMappings.tokenMappings(collateralAsset); //WETH or USDC
			uint256 beefyShares = IERC20(collateralAsset).balanceOf(address(this)); 
			IBeefyVault beefyVault = IBeefyVault(collateralAsset); // --> receive underlying LP tokens
			beefyVault.withdraw(beefyShares); 
			uint256 amountWithdrawnFromCurve; 	
			uint256 amountUnderlyingLP; 
			if (underlyingToSwapFor == tokenMappings.WETH()) {
				//amount of curve tokens
				uint256 beforeEthBalance = address(this).balance; 

				amountUnderlyingLP = 
					IERC20(0xEfDE221f306152971D8e9f181bFe998447975810).balanceOf(address(this)); 
				ICurveFi curvePool = ICurveFi(0xB90B9B1F91a01Ea22A182CD84C1E22222e39B415); 

				//remove liquidity from curve, get ETH back
				curvePool.remove_liquidity_one_coin(amountUnderlyingLP, 0, 1); //slippage @ 1 for now
				uint256 afterEthbalance = address(this).balance; 
				uint256 ethDif = afterEthbalance - beforeEthBalance; //so we don't wrap all gas
				IWETH(tokenMappings.WETH()).deposit{value: ethDif}(); 

				amountWithdrawnFromCurve = IERC20(tokenMappings.WETH()).balanceOf(address(this)); 
			} else {
				amountUnderlyingLP = 
					IERC20(0x061b87122Ed14b9526A813209C8a59a633257bAb).balanceOf(address(this)); 
				ICurveFi curvePool = ICurveFi(0x061b87122Ed14b9526A813209C8a59a633257bAb); 
				
				//remove liquidity from sUSD pool, get 3crv tokens	
				curvePool.remove_liquidity_one_coin(amountUnderlyingLP, 1, 1);
				uint256 underlying3Crv = 
					IERC20(0x1337BedC9D22ecbe766dF105c9623922A27963EC).balanceOf(address(this)); 

				//now we can remove 3crv token liquidity and unwrap to USDC
				ICurveFi crv3Pool = ICurveFi(0x1337BedC9D22ecbe766dF105c9623922A27963EC); 
				crv3Pool.remove_liquidity_one_coin(underlying3Crv, 1, 1); 

				amountWithdrawnFromCurve = IERC20(tokenMappings.USDC()).balanceOf(address(this)); 
			}

			//curve now unwrapped to base USDC or WETH
			
			return amountWithdrawnFromCurve; 

		} else if (protocol == 1) { //velodrome

			address underlyingToSwapFor = tokenMappings.tokenMappings(collateralAsset); //WETH or USDC
			bool stable = tokenMappings.stable(collateralAsset); 
			uint256 beefyShares = IERC20(collateralAsset).balanceOf(address(this)); 
			IBeefyVault beefyVault = IBeefyVault(collateralAsset); // --> receive underlying LP tokens
			address underlyingLP = beefyVault.want(); 

			beefyVault.withdraw(beefyShares); 
			
			//underlying VELO lp
			uint256 amountUnderlyingLP = IERC20(underlyingLP).balanceOf(address(this)); 

			//get underlying VELO tokens via VeloPair
			(address token0, address token1) = IVeloPair(underlyingLP).tokens(); 
			
			//remove liquidity via router
			veloRouter.removeLiquidity(	
				token0,
				token1,
				false,
				amountUnderlyingLP,
				0, //can use quote
				0, //can use quote
				address(this),
				block.timestamp
			); 

			//swap for underlying desired

			uint256 amountToSwap; 
			if (token0 == underlyingToSwapFor) { 
				amountToSwap = IERC20(token1).balanceOf(address(this)); 
				_swapVelo(token1, token0, amountToSwap, stable); 
			 } else {
				amountToSwap = IERC20(token0).balanceOf(address(this)); 
				_swapVelo(token0, token1, amountToSwap, stable); 
			 }

		} else { //BPT withdraw
			//beethoven withdraw needed
			//balancer API
			//this is the only beets pool we support atm
			//TODO: implement actual Balancer Vault ABI and interfaces 
			bytes32 poolId = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b;
			(IERC20[] memory poolTokens, , )= balancerVault.getPoolTokens(poolId); 
			uint256[] memory minAmountsOut = new uint256[](2);
			bytes memory userData = abi.encodePacked(
				IVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT
			); 

			IAsset[] memory assets = new IAsset[](2); 
				assets[0] = IAsset(address(poolTokens[0])); 
				assets[1] = IAsset(address(poolTokens[1])); 

			IVault.ExitPoolRequest memory exitPoolRequest = IVault.ExitPoolRequest(
				assets,
				minAmountsOut,
				userData,
				false //receive ERC20
			); 

			balancerVault.exitPool(
				poolId, 
				address(this), 
				payable(address(this)), 
				exitPoolRequest
			); 
			//recieve WETH after exit
		}
	}
	
	//swap using velo, easiest to do, maybe not the best liquidity(?)
	function _swapVelo(address from, address to, uint256 amountIn, bool stable) internal returns (uint256) {

		address[] memory veloPath = new address[](2); 
		veloRouter.swapExactTokensForTokensSimple(
			amountIn,
			0,
			from,
			to,
			stable,
			address(this), //send tokens here
			block.timestamp //deadline
		); 			
	}

	receive() external payable {} 
}