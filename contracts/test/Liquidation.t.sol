// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../src/FlashLoanLiquidationV3.sol"; 
import "../src/IBTokenMappings.sol"; 
import "forge-std/interfaces/IERC20.sol"; 

contract CounterTest is Test {
	FlashLoanLiquidation internal flashLoanLiquidation; 
	IBTokenMappings internal tokenMappings; 

	//all tokens are OP addresses
	address internal WETH = 0x4200000000000000000000000000000000000006; 
	address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
	address internal USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; 


	//test curve unwraps
	address internal constant CRV_wstETH_ETH = 0x0892a178c363b4739e5Ac89E9155B9c30214C0c0; 

	address internal user = address(69); 

    function setUp() public {
		tokenMappings = new IBTokenMappings(); 
		flashLoanLiquidation = new FlashLoanLiquidation(tokenMappings); 

		deal(DAI, address(flashLoanLiquidation), 1000 * 1e18); 
		deal(WETH, address(flashLoanLiquidation), 1000 * 1e18); 

    }

	//TODO:
	//test that flashloan code is set up correctly
	//test that params are working 
	//test that amounts are returned
	
	//for tests, we're going to go liquidate a position where a user has deposited WETH as collat
	//and has taken out a loan in DAI
	function testFlashLoanBasicPath() public {
		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](1); 
		paths[0] = FlashLoanLiquidation.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			isStable: false,
			protocol: 3	
		});

		FlashLoanLiquidation.Path memory ibPath = 
			FlashLoanLiquidation.Path({
				tokenIn: address(0),
				fee: 0,
				isIBToken: false,
				isStable: false,
				protocol: 3		
			}); 
	
		FlashLoanLiquidation.SwapData memory swapData = 
			FlashLoanLiquidation.SwapData({
				to: DAI,
				from: WETH,
				amount: 0.057 * 1e18, //99 USD
				minOut: 0,
				path: paths
			});

		flashLoanLiquidation.flashLoanCall(
			WETH,
			DAI,
			100 * 1e18,
			0,
			user,
			swapData,
			ibPath
		);
	}

	function testFlashLoanComplexPath() public {
		//first swap is WETH -> DAI
		//second swap is DAI -> USDC
		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](2); 
		paths[0] = FlashLoanLiquidation.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			isStable: false,
			protocol: 3	
		});

		paths[1] = FlashLoanLiquidation.Path({
			tokenIn: DAI,
			fee: 100,
			isIBToken: false,
			isStable: false,
			protocol: 3	
		});

		FlashLoanLiquidation.Path memory ibPath = 
			FlashLoanLiquidation.Path({
				tokenIn: address(0),
				fee: 0,
				isIBToken: false,
				isStable: false,
				protocol: 3		
			}); 
	
		FlashLoanLiquidation.SwapData memory swapData = 
			FlashLoanLiquidation.SwapData({
				to: USDC,
				from: WETH,
				amount: 0.057 * 1e18, //99 USD
				minOut: 0,
				path: paths
			});

		flashLoanLiquidation.flashLoanCall(
			WETH,
			DAI,
			100 * 1e18,
			0,
			user,
			swapData,
			ibPath
		);
	}

	function testFlashloanIncludeIBTokenCurve() public {
		//simulating a loan where CRV_wstETH_WETH is supplied
		//and WETH is being borrowed

		FlashLoanLiquidation.Path[] memory paths = new FlashLoanLiquidation.Path[](1); 
		paths[0] = FlashLoanLiquidation.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			isStable: false,
			protocol: 3	
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(CRV_wstETH_ETH, address(flashLoanLiquidation), 10 * 1e18); 

		FlashLoanLiquidation.Path memory ibPath = 
			FlashLoanLiquidation.Path({
				tokenIn: CRV_wstETH_ETH,
				fee: 0,
				isIBToken: true,
				isStable: false,
				protocol: 0 //curve
			}); 
	
		FlashLoanLiquidation.SwapData memory swapData = 
			FlashLoanLiquidation.SwapData({
				to: WETH,
				from: WETH,
				amount: 0.057 * 1e18, //93 USD current
				minOut: 0,
				path: paths
			});

		flashLoanLiquidation.flashLoanCall(
			CRV_wstETH_ETH, //collateral
			WETH, //debt
			100 * 1e18, //amount
			0, //tranche (simulated)
			user, 
			swapData,
			ibPath
		);
	}

	
}
