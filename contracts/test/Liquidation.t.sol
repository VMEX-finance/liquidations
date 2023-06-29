// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../src/FlashLoanLiquidationV3.sol"; 
import "../src/IBTokenMappings.sol"; 
import "../src/PeripheralLogic.sol"; 
import "forge-std/interfaces/IERC20.sol"; 

contract LiquidationTest is Test {
	IBTokenMappings internal tokenMappings; 
	FlashLoanLiquidation internal flashLoanLiquidation; 
	PeripheralLogic internal peripheralLogic; 

	//all tokens are OP addresses
	address internal WETH = 0x4200000000000000000000000000000000000006; 
	address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
	address internal USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; 


	//test curve unwraps
	address internal constant CRV_wstETH_ETH = 0x0892a178c363b4739e5Ac89E9155B9c30214C0c0; //beefy
	address internal constant CRV_sUSD_3CRV = 0x061b87122Ed14b9526A813209C8a59a633257bAb; //crv

	//test velo unwraps
	address internal constant VELO_wstETH_ETH = 0xca39e63E3b798D5A3f44CA56A123E3FCc29ad598; 

	//test beets unwraps
	address internal constant SHANGAI_SHAKEDOWN = 0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2; 

	address internal user = address(69); 

    function setUp() public {
		tokenMappings = new IBTokenMappings(); 
		flashLoanLiquidation = new FlashLoanLiquidation(); 
		peripheralLogic = new PeripheralLogic(tokenMappings, flashLoanLiquidation); 

		flashLoanLiquidation.init(peripheralLogic); 
			
		//simulating liquidation profits
		//deal(DAI, address(flashLoanLiquidation), 10 * 1e18); 
		deal(WETH, address(flashLoanLiquidation), 0.01 * 1e18); 
		deal(USDC, address(flashLoanLiquidation), 10 * 1e6); 
    }


	//TODO:
	//test that flashloan code is set up correctly
	//test that params are working 
	//test that amounts are returned
	
	//for tests, we're going to go liquidate a position where a user has deposited WETH as collat
	//and has taken out a loan in USDC
	function testFlashLoanBasicPath() public {

		//simulating a loan where a user has taken out a loan in DAI using WETH as collateral
		PeripheralLogic.Protocol protocol = PeripheralLogic.Protocol.NONE;
		
		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			protocol: protocol	
		});

		PeripheralLogic.Path[] memory paths2 = new PeripheralLogic.Path[](1); 
		paths2[0] = PeripheralLogic.Path({
			tokenIn: USDC,
			fee: 500,
			isIBToken: false,
			protocol: protocol
		}); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: address(0),
				fee: 0,
				isIBToken: false,
				protocol: protocol
			}); 
		
		//swap from DAI to WETH
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: USDC,
				amount: 100 * 1e6, //99 USD
				minOut: 0,
				path: paths
			});
		
		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: USDC,
				from: WETH,
				amount: 0, //addded in by contract
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: WETH,
				debtAsset: USDC,
				debtAmount: 100 * 1e6,
				trancheId: 0,
				user: user,
				swapBeforeFlashloan: swapBeforeFlashloan,
				swapAfterFlashloan: swapAfterFlashloan,
				ibPath: ibPath
			}); 

		flashLoanLiquidation.flashLoanCall(data);
	}

	function testFlashLoanComplexPath() public {
		//simulating a time where the borrowed token is not directly flashloanable and has a complex path
		//we flashloan WETH, but our debt asset is actually USDC
		//first swap is WETH -> DAI
		//second swap is DAI -> USDC
		PeripheralLogic.Protocol protocol = PeripheralLogic.Protocol.NONE;

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](2); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			protocol: protocol
		});

		paths[1] = PeripheralLogic.Path({
			tokenIn: DAI,
			fee: 100,
			isIBToken: false,
			protocol: protocol	
		});

		PeripheralLogic.Path[] memory path2 = new PeripheralLogic.Path[](1); 
		path2[0] = PeripheralLogic.Path({
			tokenIn: USDC,
			fee: 500,
			isIBToken: false,
			protocol: protocol	
		}); 
		
		//ignored as we don't have ib collateral
		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: address(0),
				fee: 0,
				isIBToken: false,
				protocol: protocol
			});
	
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: USDC,
				from: WETH,
				amount: 100 * 1e6, //99 USD
				minOut: 0,
				path: paths
			});
			
			//we get dai after collateral liquidation
			PeripheralLogic.SwapData memory swapAfterFlashloan = 
				PeripheralLogic.SwapData({
					to: WETH,
					from: USDC,
					amount: 0,
					minOut: 0,
					path: path2
				});
		
		//debt asset here is WETH, but in this scenario it's actually USDC, which we will get to by the path variable 
		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: USDC,
				debtAsset: WETH,
				debtAmount: 1 * 1e18,
				trancheId: 0,
				user: user,
				swapBeforeFlashloan: swapBeforeFlashloan,
				swapAfterFlashloan: swapAfterFlashloan,
				ibPath: ibPath
			}); 


			flashLoanLiquidation.flashLoanCall(data); 

	}

	function testFlashloanIncludeIBTokenCurveWeth() public {
		//simulating a loan where CRV_wstETH_WETH is supplied
		//and WETH is being borrowed
		PeripheralLogic.Protocol protocolN = PeripheralLogic.Protocol.NONE;
		PeripheralLogic.Protocol protocolCurve = PeripheralLogic.Protocol.CURVE;

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			protocol: protocolN	
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(CRV_wstETH_ETH, address(flashLoanLiquidation), 3 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: CRV_wstETH_ETH,
				fee: 0,
				isIBToken: true,
				protocol: protocolCurve
			}); 
	
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 0.057 * 1e18, //93 USD current
				minOut: 0,
				path: paths
			});
		
		//unwrap function handles direct unwrapping to WETH in this case, however we would need to swap back to collateral if it was something else
		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 0.057 * 1e18, //93 USD current
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: CRV_wstETH_ETH,
				debtAsset: WETH,
				debtAmount: 1 * 1e18,
				trancheId: 0,
				user: user,
				swapBeforeFlashloan: swapBeforeFlashloan,
				swapAfterFlashloan: swapAfterFlashloan,
				ibPath: ibPath
			}); 

			flashLoanLiquidation.flashLoanCall(data); 

	}

	function testFlashloanIncludeIBTokenCurveUSD() public {
		//simulating loan where CRV_sUSD_3CRV is collateral to take out a USDC loan
		PeripheralLogic.Protocol protocolN = PeripheralLogic.Protocol.NONE;
		PeripheralLogic.Protocol protocolCurve = PeripheralLogic.Protocol.CURVE;
		
		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: USDC,
			fee: 100,
			isIBToken: false,
			protocol: protocolN	
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(CRV_sUSD_3CRV, address(flashLoanLiquidation), 3 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: CRV_sUSD_3CRV,
				fee: 0,
				isIBToken: true,
				protocol: protocolCurve //curve
			}); 
		
		//not being used unless flashloaned token is different from debtAsset	
		//in this case, there is no difference so it will not be checked 
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: USDC,
				from: USDC,
				amount: 100 * 1e6, 
				minOut: 0,
				path: paths
			});

		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: USDC,
				from: USDC,
				amount: 0, 
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: CRV_sUSD_3CRV,
				debtAsset: USDC,
				debtAmount: 100 * 1e6,
				trancheId: 0,
				user: user,
				swapBeforeFlashloan: swapBeforeFlashloan,
				swapAfterFlashloan: swapAfterFlashloan,
				ibPath: ibPath
			}); 

			flashLoanLiquidation.flashLoanCall(data); 

	}
//
//	function testFlashloanIncludeIBTokenVelodrome() public {
//		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
//		paths[0] = PeripheralLogic.Path({
//			tokenIn: WETH,
//			fee: 100,
//			isIBToken: false,
//			protocol: 3	
//		});
//
//		//simulate a flashloan where an IBtoken is recovered as collateral
//		//contracts needs it when unwrapping any IBtokens
//		deal(VELO_wstETH_ETH, address(flashLoanLiquidation), 100); 
//
//		PeripheralLogic.Path memory ibPath = 
//			PeripheralLogic.Path({
//				tokenIn: VELO_wstETH_ETH,
//				fee: 0,
//				isIBToken: true,
//				protocol: 1 //velodrome
//			}); 
//		
//		//not being used unless flashloaned token is different from debtAsset	
//		//in this case, there is no difference so it will not be checked 
//		PeripheralLogic.SwapData memory swapData = 
//			PeripheralLogic.SwapData({
//				to: WETH,
//				from: WETH,
//				amount: 100 * 1e18, //93 USD current
//				minOut: 0,
//				path: paths
//			});
//
//		flashLoanLiquidation.flashLoanCall(
//			VELO_wstETH_ETH, //collateral
//			WETH, //debt
//			100 * 1e18, //amount
//			0, //tranche (simulated)
//			user, 
//			swapData,
//			ibPath
//		);
//	}
//
//	function testFlashloanInlcudeIBTokenBalancer() public {
//		//simulate a liquidation on a loan where beets is collateral for a WETH loan
//		//initial path only -- protocol not used
//		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
//		paths[0] = PeripheralLogic.Path({
//			tokenIn: WETH,
//			fee: 100,
//			isIBToken: false,
//			protocol: 2 //none
//		});
//
//		//simulate a flashloan where an IBtoken is recovered as collateral
//		//contracts needs it when unwrapping any IBtokens
//		deal(SHANGAI_SHAKEDOWN, address(flashLoanLiquidation), 100 * 1e18); 
//
//		PeripheralLogic.Path memory ibPath = 
//			PeripheralLogic.Path({
//				tokenIn: SHANGAI_SHAKEDOWN,
//				fee: 0,
//				isIBToken: true,
//				protocol: 2 //beets
//			}); 
//		
//		//not being used unless flashloaned token is different from debtAsset	
//		//in this case, there is no difference so it will not be checked 
//		PeripheralLogic.SwapData memory swapData = 
//			PeripheralLogic.SwapData({
//				to: WETH,
//				from: WETH,
//				amount: 10 * 1e18, //93 USD current
//				minOut: 0,
//				path: paths
//			});
//
//		flashLoanLiquidation.flashLoanCall(
//			SHANGAI_SHAKEDOWN, //collateral
//			WETH, //debt
//			10 * 1e18, //amount
//			0, //tranche (simulated)
//			user, 
//			swapData,
//			ibPath
//		);
//	}
//	
}
