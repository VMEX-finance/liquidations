// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../src/FlashLoanLiquidationV3.sol"; 
import "../src/IBTokenMappings.sol"; 
import "forge-std/interfaces/IERC20.sol"; 

contract LiquidationTest is Test {
	FlashLoanLiquidation internal flashLoanLiquidation; 
	IBTokenMappings internal tokenMappings; 

	//all tokens are OP addresses
	address internal WETH = 0x4200000000000000000000000000000000000006; 
	address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
	address internal USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; 


	//test curve unwraps
	address internal constant CRV_wstETH_ETH = 0x0892a178c363b4739e5Ac89E9155B9c30214C0c0; 
	address internal constant CRV_sUSD_3CRV = 0x107Dbf9c9C0EF2Df114159e5C7DC2baf7C444cFF; 

	//test velo unwraps
	address internal constant VELO_wstETH_ETH = 0xca39e63E3b798D5A3f44CA56A123E3FCc29ad598; 

	//test beets unwraps
	address internal constant SHANGAI_SHAKEDOWN = 0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2; 

	address internal user = address(69); 

    function setUp() public {
		tokenMappings = new IBTokenMappings(); 
		flashLoanLiquidation = new FlashLoanLiquidation(tokenMappings); 

		deal(DAI, address(flashLoanLiquidation), 1000 * 1e18); 
		deal(WETH, address(flashLoanLiquidation), 1000 * 1e18); 
		deal(USDC, address(flashLoanLiquidation), 1000 * 1e18); 
    }

	//TODO: investigate why USDC flashloans are not working

	//TODO:
	//test that flashloan code is set up correctly
	//test that params are working 
	//test that amounts are returned
	
	//for tests, we're going to go liquidate a position where a user has deposited WETH as collat
	//and has taken out a loan in DAI
//	function testFlashLoanBasicPath() public {
//		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](1); 
//		paths[0] = FlashLoanLiquidation.Path({
//			tokenIn: WETH,
//			fee: 500,
//			isIBToken: false,
//			protocol: 3	
//		});
//
//		FlashLoanLiquidation.Path memory ibPath = 
//			FlashLoanLiquidation.Path({
//				tokenIn: address(0),
//				fee: 0,
//				isIBToken: false,
//				protocol: 3		
//			}); 
//	
//		FlashLoanLiquidation.SwapData memory swapData = 
//			FlashLoanLiquidation.SwapData({
//				to: DAI,
//				from: WETH,
//				amount: 0.057 * 1e18, //99 USD
//				minOut: 0,
//				path: paths
//			});
//
//		flashLoanLiquidation.flashLoanCall(
//			WETH,
//			DAI,
//			100 * 1e18,
//			0,
//			user,
//			swapData,
//			ibPath
//		);
//	}
//
//	function testFlashLoanComplexPath() public {
//		//first swap is WETH -> DAI
//		//second swap is DAI -> USDC
//		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](2); 
//		paths[0] = FlashLoanLiquidation.Path({
//			tokenIn: WETH,
//			fee: 500,
//			isIBToken: false,
//			protocol: 3	
//		});
//
//		paths[1] = FlashLoanLiquidation.Path({
//			tokenIn: DAI,
//			fee: 100,
//			isIBToken: false,
//			protocol: 3	
//		});
//
//		FlashLoanLiquidation.Path memory ibPath = 
//			FlashLoanLiquidation.Path({
//				tokenIn: address(0),
//				fee: 0,
//				isIBToken: false,
//				protocol: 3		
//			}); 
//	
//		FlashLoanLiquidation.SwapData memory swapData = 
//			FlashLoanLiquidation.SwapData({
//				to: USDC,
//				from: WETH,
//				amount: 0.057 * 1e18, //99 USD
//				minOut: 0,
//				path: paths
//			});
//
//		flashLoanLiquidation.flashLoanCall(
//			WETH,
//			DAI,
//			100 * 1e18,
//			0,
//			user,
//			swapData,
//			ibPath
//		);
//	}
//
//	function testFlashloanIncludeIBTokenCurveWeth() public {
//		//simulating a loan where CRV_wstETH_WETH is supplied
//		//and WETH is being borrowed
//
//		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](1); 
//		paths[0] = FlashLoanLiquidation.Path({
//			tokenIn: WETH,
//			fee: 500,
//			isIBToken: false,
//			protocol: 3	
//		});
//
//		//simulate a flashloan where an IBtoken is recovered as collateral
//		//contracts needs it when unwrapping any IBtokens
//		deal(CRV_wstETH_ETH, address(flashLoanLiquidation), 10 * 1e18); 
//
//		FlashLoanLiquidation.Path memory ibPath = 
//			FlashLoanLiquidation.Path({
//				tokenIn: CRV_wstETH_ETH,
//				fee: 0,
//				isIBToken: true,
//				protocol: 0 //curve
//			}); 
//	
//		FlashLoanLiquidation.SwapData memory swapData = 
//			FlashLoanLiquidation.SwapData({
//				to: WETH,
//				from: WETH,
//				amount: 0.057 * 1e18, //93 USD current
//				minOut: 0,
//				path: paths
//			});
//
//		flashLoanLiquidation.flashLoanCall(
//			CRV_wstETH_ETH, //collateral
//			WETH, //debt
//			100 * 1e18, //amount
//			0, //tranche (simulated)
//			user, 
//			swapData,
//			ibPath
//		);
//	}
//
//	function testFlashloanIncludeIBTokenCurveUSD() public {
//		//simulating a loan where CRV_sUSD_3CRV is supplied
//		//and DAI is being borrowed
//
//		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](1); 
//		paths[0] = FlashLoanLiquidation.Path({
//			tokenIn: DAI,
//			fee: 100,
//			isIBToken: false,
//			protocol: 3	
//		});
//
//		//simulate a flashloan where an IBtoken is recovered as collateral
//		//contracts needs it when unwrapping any IBtokens
//		deal(CRV_sUSD_3CRV, address(flashLoanLiquidation), 1 * 1e18); 
//
//		FlashLoanLiquidation.Path memory ibPath = 
//			FlashLoanLiquidation.Path({
//				tokenIn: CRV_wstETH_ETH,
//				fee: 0,
//				isIBToken: true,
//				protocol: 0 //curve
//			}); 
//		
//		//not being used unless flashloaned token is different from debtAsset	
//		//in this case, there is no difference so it will not be checked 
//		FlashLoanLiquidation.SwapData memory swapData = 
//			FlashLoanLiquidation.SwapData({
//				to: USDC,
//				from: DAI,
//				amount: 100 * 1e18, //93 USD current
//				minOut: 0,
//				path: paths
//			});
//
//		flashLoanLiquidation.flashLoanCall(
//			CRV_sUSD_3CRV, //collateral
//			DAI, //debt
//			100 * 1e18, //amount
//			0, //tranche (simulated)
//			user, 
//			swapData,
//			ibPath
//		);
//	}
//
//	function testFlashloanIncludeIBTokenVelodrome() public {
//		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](1); 
//		paths[0] = FlashLoanLiquidation.Path({
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
//		FlashLoanLiquidation.Path memory ibPath = 
//			FlashLoanLiquidation.Path({
//				tokenIn: VELO_wstETH_ETH,
//				fee: 0,
//				isIBToken: true,
//				protocol: 1 //velodrome
//			}); 
//		
//		//not being used unless flashloaned token is different from debtAsset	
//		//in this case, there is no difference so it will not be checked 
//		FlashLoanLiquidation.SwapData memory swapData = 
//			FlashLoanLiquidation.SwapData({
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
//		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](1); 
//		paths[0] = FlashLoanLiquidation.Path({
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
//		FlashLoanLiquidation.Path memory ibPath = 
//			FlashLoanLiquidation.Path({
//				tokenIn: SHANGAI_SHAKEDOWN,
//				fee: 0,
//				isIBToken: true,
//				protocol: 2 //beets
//			}); 
//		
//		//not being used unless flashloaned token is different from debtAsset	
//		//in this case, there is no difference so it will not be checked 
//		FlashLoanLiquidation.SwapData memory swapData = 
//			FlashLoanLiquidation.SwapData({
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
