// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../src/FlashLoanLiquidationV3.sol"; 
import "../src/IBTokenMappings.sol"; 
import "../src/PeripheralLogic.sol"; 
import "forge-std/interfaces/IERC20.sol"; 
import "../src/Mothership.sol"; 
import "../src/Router.sol"; 

import "../src/interfaces/IYearnVault.sol"; 

contract LiquidationTest is Test {
	IBTokenMappings internal tokenMappings; 
	FlashLoanLiquidation internal flashLoanLiquidation; 
	PeripheralLogic internal peripheralLogic; 
	FlashLoanRouter internal flashLoanRouter; 
	Mothership internal mothership; 


	address internal WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; 
	address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
	address internal USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; 
	address internal ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548; 
	address internal USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; 

	//test curve unwraps
	address internal constant CRV_wstETH_ETH = 0xDbcD16e622c95AcB2650b38eC799f76BFC557a0b; //beefy
	address internal constant CRV_USDCE_USDT = 0x7f90122BF0700F9E7e1F688fe926940E8839F353; //crv
	address internal constant CRV_FRAX_USDCE = 0xC9B8a3FDECB9D5b218d02555a8Baf332E5B740d5; 

	//test camelot unwraps
	address internal constant CAM_ETH_USDCE = 0x84652bb2539513BAf36e225c930Fdd8eaa63CE27; 
	address internal constant CAM_USDCE_USDT = 0x1C31fB3359357f6436565cCb3E982Bc6Bf4189ae; 

	//test balancer unwraps
	address internal constant SHANGHAI_SHAKEDOWN = 0x9791d590788598535278552EEcD4b211bFc790CB; 
	address internal constant ROCKET_FUEL = 0xadE4A71BB62bEc25154CFc7e6ff49A513B491E81; 
	
	address internal user = address(69); 

    function setUp() public {
		tokenMappings = new IBTokenMappings(); 
		flashLoanLiquidation = new FlashLoanLiquidation(); 
		peripheralLogic = new PeripheralLogic(tokenMappings, flashLoanLiquidation); 
		flashLoanRouter = new FlashLoanRouter(); 
		mothership = new Mothership(flashLoanRouter, user); 

		flashLoanLiquidation.init(peripheralLogic, mothership); 
		
		flashLoanRouter.init(
			address(flashLoanLiquidation),
			address(tokenMappings),
			address(peripheralLogic),
			address(mothership)
		);
			
		//simulating liquidation profits
		//deal(DAI, address(flashLoanLiquidation), 10 * 1e18); 
		deal(WETH, address(mothership), 1 * 1e6); 
    }


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

		deal(USDC, address(flashLoanLiquidation), 2000 * 1e6); 

		flashLoanLiquidation.flashLoanCall(data);
	}

	function testFlashLoanNoPath() public {

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
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			protocol: protocol
		}); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: WETH,
				fee: 0,
				isIBToken: false,
				protocol: protocol
			}); 
		
		//swap from DAI to WETH
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 0, //99 USD
				minOut: 0,
				path: paths
			});
		
		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 0, //addded in by contract
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: WETH,
				debtAsset: WETH,
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
		//first swap is WETH -> USDC
		//second swap is USDC -> ARB
		PeripheralLogic.Protocol protocol = PeripheralLogic.Protocol.NONE;

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](2); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			protocol: protocol
		});

		paths[1] = PeripheralLogic.Path({
			tokenIn: USDC,
			fee: 500,
			isIBToken: false,
			protocol: protocol	
		});

		PeripheralLogic.Path[] memory path2 = new PeripheralLogic.Path[](1); 
		path2[0] = PeripheralLogic.Path({
			tokenIn: ARB,
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
				to: ARB,
				from: WETH,
				amount: 1 * 1e18, //99 USD
				minOut: 0,
				path: paths
			});
			
			//we get usdc after collateral liquidation
			deal(USDC, address(flashLoanLiquidation), 2000 * 1e6); 

			PeripheralLogic.SwapData memory swapAfterFlashloan = 
				PeripheralLogic.SwapData({
					to: WETH,
					from: USDC,
					amount: 0,
					minOut: 0,
					path: path2
				});
	

		//assuming ARB isn't directly flashloanable, our loan will actually be weth here
		//beforeFlashloan will swap to ARB, liquidate the debt, receive USDC, and then swap back to WETH
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
		deal(CRV_wstETH_ETH, address(flashLoanLiquidation), 0.5 * 1e18); 

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
		//simulating loan where CRV_USDCE_USDT is collateral to take out a USDC loan
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
		deal(CRV_USDCE_USDT, address(flashLoanLiquidation), 3 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: CRV_USDCE_USDT,
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
				collateralAsset: CRV_USDCE_USDT,
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

	function testFlashloanIncludeIBTokenCamelot() public {
		//CAM_ETH_USDCE is collateral for a WETH borrow

		PeripheralLogic.Protocol protocolVelo = PeripheralLogic.Protocol.CAMELOT;

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 100,
			isIBToken: false,
			protocol: protocolVelo	
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(CAM_ETH_USDCE, address(flashLoanLiquidation), 0.01 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: CAM_ETH_USDCE,
				fee: 0,
				isIBToken: true,
				protocol: protocolVelo 
			}); 
		
		//not being used unless flashloaned token is different from debtAsset	
		//in this case, there is no difference so it will not be checked 
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 1 * 1e18, //93 USD current
				minOut: 0,
				path: paths
			});

		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 0, //93 USD current
				minOut: 0,
				path: paths
			});


		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: CAM_ETH_USDCE,
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

	function testFlashloanInlcudeIBTokenBalancerShanghai() public {
		//simulate a liquidation on a loan where beets is collateral for a WETH loan
		//initial path only -- protocol not used
		PeripheralLogic.Protocol protocolBeets = PeripheralLogic.Protocol.BALANCER; 

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 100,
			isIBToken: false,
			protocol: protocolBeets
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(SHANGHAI_SHAKEDOWN, address(flashLoanLiquidation), 1 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: SHANGHAI_SHAKEDOWN,
				fee: 0,
				isIBToken: true,
				protocol: protocolBeets
			}); 
		
		//not being used unless flashloaned token is different from debtAsset	
		//in this case, there is no difference so it will not be checked 
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 1 * 1e18, 
				minOut: 0,
				path: paths
			});

		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 0, 
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: SHANGHAI_SHAKEDOWN,
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

//	function testFlashloanInlcudeIBTokenBeetsRocketPool() public {
//		//simulate a liquidation on a loan where beets is collateral for a WETH loan
//		//initial path only -- protocol not used
//		PeripheralLogic.Protocol protocolBeets = PeripheralLogic.Protocol.BALANCER; 
//
//		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
//		paths[0] = PeripheralLogic.Path({
//			tokenIn: WETH,
//			fee: 100,
//			isIBToken: false,
//			protocol: protocolBeets
//		});
//
//		//simulate a flashloan where an IBtoken is recovered as collateral
//		//contracts needs it when unwrapping any IBtokens
//		deal(ROCKET_FUEL, address(flashLoanLiquidation), 2 * 1e18); 
//
//		PeripheralLogic.Path memory ibPath = 
//			PeripheralLogic.Path({
//				tokenIn: ROCKET_FUEL,
//				fee: 0,
//				isIBToken: true,
//				protocol: protocolBeets //beets
//			}); 
//		
//		//not being used unless flashloaned token is different from debtAsset	
//		//in this case, there is no difference so it will not be checked 
//		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
//			PeripheralLogic.SwapData({
//				to: WETH,
//				from: WETH,
//				amount: 1 * 1e18, 
//				minOut: 0,
//				path: paths
//			});
//
//		PeripheralLogic.SwapData memory swapAfterFlashloan = 
//			PeripheralLogic.SwapData({
//				to: WETH,
//				from: WETH,
//				amount: 0, 
//				minOut: 0,
//				path: paths
//			});
//
//		FlashLoanLiquidation.FlashLoanData memory data = 
//			FlashLoanLiquidation.FlashLoanData({
//				collateralAsset: ROCKET_FUEL,
//				debtAsset: WETH,
//				debtAmount: 1 * 1e18,
//				trancheId: 0,
//				user: user,
//				swapBeforeFlashloan: swapBeforeFlashloan,
//				swapAfterFlashloan: swapAfterFlashloan,
//				ibPath: ibPath
//			}); 
//
//		flashLoanLiquidation.flashLoanCall(data); 
//
//	}
	
	
}
