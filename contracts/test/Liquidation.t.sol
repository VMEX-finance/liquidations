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
	PeripheralLogic internal peripheralLogic; //all tokens are OP addresses address internal 
	FlashLoanRouter internal flashLoanRouter; 
	Mothership internal mothership; 


	address internal WETH = 0x4200000000000000000000000000000000000006; 
	address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
	address internal USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; 
	address internal OP = 0x4200000000000000000000000000000000000042; 
	address internal USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58; 

	//test curve unwraps
	address internal constant CRV_wstETH_ETH = 0x0892a178c363b4739e5Ac89E9155B9c30214C0c0; //beefy
	address internal constant CRV_sUSD_3CRV = 0x061b87122Ed14b9526A813209C8a59a633257bAb; //crv

	//test velo unwraps
	address internal constant VELO_wstETH_ETH = 0x6dA98Bde0068d10DDD11b468b197eA97D96F96Bc; 

	//test beets unwraps
	address internal constant SHANGHAI_SHAKEDOWN = 0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2; 
	address internal constant ROCKET_FUEL = 0x4Fd63966879300caFafBB35D157dC5229278Ed23; 
	
	//test yearn unwraps
	address internal constant yvUSDT = 0xFaee21D0f0Af88EE72BB6d68E54a90E6EC2616de; 
	address internal constant yvUSDC = 0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2; 
	address internal constant yvWETH = 0x5B977577Eb8a480f63e11FC615D6753adB8652Ae; 
	address internal constant yvDAI = 0x65343F414FFD6c97b0f6add33d16F6845Ac22BAc; 

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
		deal(WETH, address(mothership), 0.01 * 1e18); 
		deal(USDC, address(mothership), 10 * 1e6); 
		deal(USDT, address(mothership), 10 * 1e6); 
    }


	//TODO:
	//test that flashloan code is set up correctly
	//test that params are working 
	//test that amounts are returned
	
	//for tests, we're going to),
	//address(tokenMappings),
	//address(peripheralLogic),
	//address(mothership) go liquidate a position where a user has deposited WETH as collat
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
		//second swap is USDC -> OP
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
			tokenIn: OP,
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
				to: OP,
				from: WETH,
				amount: 100 * 1e6, //99 USD
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
	

		//assuming OP isn't directly flashloanable, our loan will actually be weth here
		//beforeFlashloan will swap to OP, liquidate the debt, receive USDC, and then swap back to WETH
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

	function testFlashloanIncludeIBTokenVelodrome() public {
		//VELO_wstETH_ETH is collateral for a WETH borrow

		PeripheralLogic.Protocol protocolVelo = PeripheralLogic.Protocol.VELODROME;

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 100,
			isIBToken: false,
			protocol: protocolVelo	
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(VELO_wstETH_ETH, address(flashLoanLiquidation), 1 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: VELO_wstETH_ETH,
				fee: 0,
				isIBToken: true,
				protocol: protocolVelo //velodrome
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
				collateralAsset: VELO_wstETH_ETH,
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

	function testFlashloanInlcudeIBTokenBeetsShanghai() public {
		//simulate a liquidation on a loan where beets is collateral for a WETH loan
		//initial path only -- protocol not used
		PeripheralLogic.Protocol protocolBeets = PeripheralLogic.Protocol.BEETHOVEN; 

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 100,
			isIBToken: false,
			protocol: protocolBeets
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(SHANGHAI_SHAKEDOWN, address(flashLoanLiquidation), 2 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: SHANGHAI_SHAKEDOWN,
				fee: 0,
				isIBToken: true,
				protocol: protocolBeets //beets
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

	function testFlashloanInlcudeIBTokenBeetsRocketPool() public {
		//simulate a liquidation on a loan where beets is collateral for a WETH loan
		//initial path only -- protocol not used
		PeripheralLogic.Protocol protocolBeets = PeripheralLogic.Protocol.BEETHOVEN; 

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 100,
			isIBToken: false,
			protocol: protocolBeets
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(ROCKET_FUEL, address(flashLoanLiquidation), 2 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: ROCKET_FUEL,
				fee: 0,
				isIBToken: true,
				protocol: protocolBeets //beets
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
				collateralAsset: ROCKET_FUEL,
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

	function testFlashloanInlcudeIBTokenYearnUSDT() public {
		//simulate a liquidation on a loan where yearn is collateral for a WETH loan
		//initial path only -- protocol not used
		PeripheralLogic.Protocol YEARN = PeripheralLogic.Protocol.YEARN; 

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: USDT,
			fee: 0,
			isIBToken: false,
			protocol: YEARN
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(yvUSDT, address(flashLoanLiquidation), 100 * 1e6); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: yvUSDT,
				fee: 0,
				isIBToken: true,
				protocol: YEARN
			}); 
		
		//not being used unless flashloaned token is different from debtAsset	
		//in this case, there is no difference so it will not be checked 
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: USDT,
				from: USDT,
				amount: 100 * 1e6, 
				minOut: 0,
				path: paths
			});
		
		//usdt after unwrapped
		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: USDT,
				from: USDT,
				amount: 0, 
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: yvUSDT,
				debtAsset: USDT,
				debtAmount: 100 * 1e6,
				trancheId: 0,
				user: user,
				swapBeforeFlashloan: swapBeforeFlashloan,
				swapAfterFlashloan: swapAfterFlashloan,
				ibPath: ibPath
			}); 

		flashLoanLiquidation.flashLoanCall(data); 

	}

	function testFlashloanInlcudeIBTokenYearnUSDC() public {
		//simulate a liquidation on a loan where yearn is collateral for a WETH loan
		//initial path only -- protocol not used
		PeripheralLogic.Protocol YEARN = PeripheralLogic.Protocol.YEARN; 

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: USDC,
			fee: 0,
			isIBToken: false,
			protocol: YEARN
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(yvUSDC, address(flashLoanLiquidation), 100 * 1e6); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: yvUSDC,
				fee: 0,
				isIBToken: true,
				protocol: YEARN
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
		
		//usdt after unwrapped
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
				collateralAsset: yvUSDC,
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

	function testFlashloanInlcudeIBTokenYearnWETH() public {
		//simulate a liquidation on a loan where yearn is collateral for a WETH loan
		//initial path only -- protocol not used
		PeripheralLogic.Protocol YEARN = PeripheralLogic.Protocol.YEARN; 

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 0,
			isIBToken: false,
			protocol: YEARN
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(yvWETH, address(flashLoanLiquidation), 1 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: yvWETH,
				fee: 0,
				isIBToken: true,
				protocol: YEARN
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
		
		//usdt after unwrapped
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
				collateralAsset: yvWETH,
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

	function testFlashloanInlcudeIBTokenYearnDAI() public {
		//simulate a liquidation on a loan where yearn is collateral for a DAI loan
		//initial path only -- protocol not used
		PeripheralLogic.Protocol YEARN = PeripheralLogic.Protocol.YEARN; 

		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: DAI,
			fee: 0,
			isIBToken: false,
			protocol: YEARN
		});

		//simulate a flashloan where an IBtoken is recovered as collateral
		//contracts needs it when unwrapping any IBtokens
		deal(yvDAI, address(flashLoanLiquidation), 10 * 1e18); 

		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: yvDAI,
				fee: 0,
				isIBToken: true,
				protocol: YEARN
			}); 
		
		//not being used unless flashloaned token is different from debtAsset	
		//in this case, there is no difference so it will not be checked 
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: DAI,
				from: DAI,
				amount: 10 * 1e18, 
				minOut: 0,
				path: paths
			});
		
		//usdt after unwrapped
		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: DAI,
				from: DAI,
				amount: 0, 
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: yvDAI,
				debtAsset: DAI,
				debtAmount: 10 * 1e18,
				trancheId: 0,
				user: user,
				swapBeforeFlashloan: swapBeforeFlashloan,
				swapAfterFlashloan: swapAfterFlashloan,
				ibPath: ibPath
			}); 

		flashLoanLiquidation.flashLoanCall(data); 

	}
	
	
	
}
