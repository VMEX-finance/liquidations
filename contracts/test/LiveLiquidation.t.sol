// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../src/FlashLoanLiquidationV3.sol"; 
import "../src/IBTokenMappings.sol"; 
import "../src/PeripheralLogic.sol"; 
import "forge-std/interfaces/IERC20.sol"; 
import "../src/Mothership.sol"; 
import "../src/Router.sol"; 
import "../src/interfaces/ILendingPool.sol"; 
import "../src/interfaces/IAssetMappings.sol"; 

import "../src/interfaces/IYearnVault.sol"; 

contract LiquidationTest is Test {
//	IBTokenMappings internal tokenMappings = IBTokenMappings(0xc6030D79EC36BDcD44A27cCB3C7015bE14ed58a4); 
//	FlashLoanLiquidation internal flashLoanLiquidation = FlashLoanLiquidation(payable(0x52121C2508103153FE1a2cDfC7EE28307bE9ceb2)); 
//	PeripheralLogic internal peripheralLogic = PeripheralLogic(payable(0xDd846c63Eb8BB38734576B4C7c1c0da2510fd04c)); //all tokens are OP addresses address internal
//	//FlashLoanRouter internal flashLoanRouter = FlashLoanRouter(0xC9a2191B333e8f40B6bc86752066105EbDeB1fBa); 
//	//Mothership internal mothership = Mothership(0x41045ee8111696C477EE434C4CEe1052dc2a607F); 

	IBTokenMappings internal tokenMappings; 
	FlashLoanLiquidation internal flashLoanLiquidation; 
	PeripheralLogic internal peripheralLogic; 
	FlashLoanRouter internal flashLoanRouter; 
	Mothership internal mothership; 

	ILendingPool public lendingPool = ILendingPool(0x60F015F66F3647168831d31C7048ca95bb4FeaF9); 

	IAssetMappings public assetMappings = IAssetMappings(0x48CB441A85d6EA9798C72c4a1829658D786F3027); 

	address internal WETH = 0x4200000000000000000000000000000000000006; 
	address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
	address internal USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; 
	address internal OP = 0x4200000000000000000000000000000000000042; 
	address internal USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58; 

	address public lendingPoolConfigurator = 0xe9CFdd8375a3E8cDfD8F18F6462c7158a7062484; 
	address public globalAdmin = 0x599e1DE505CfD6f10F64DD7268D856831f61627a; 

	address internal constant yvDAI = 0x65343F414FFD6c97b0f6add33d16F6845Ac22BAc; 

	address internal user = 0x4d180AF22cd72b8c6593656a0e123E0C4760e6ac;  
	address internal newDepositor = 0xd3F06D8AeFaD0AB352fEfB903c36fD7f5Aa140E0; 

    function setUp() public {
			deal(WETH, newDepositor, 1e18); 
			deal(WETH, user, 2e18); 

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

			vm.startPrank(user); 
				IERC20(WETH).approve(address(lendingPool), type(uint256).max); 
				lendingPool.deposit(WETH, 0, 1 * 1e18, user, 0); 
				lendingPool.borrow(WETH, 0, 0.5 * 1e18, 0, user); 
			vm.stopPrank(); 

			//change borrow factor to force liquidation
			vm.startPrank(globalAdmin);
				assetMappings.configureAssetMapping(
					WETH, //asset
					800000000000000000, //baseLTV
					825000000000000000, //liqThreshold
					1050000000000000000, //liqBonus
					35000000000000000000000, //supplyCap
					19000000000000000000000, //borrowCap
					3000000000000000000 //borrowFactor		
				); 
			vm.stopPrank(); 
		}

		function testLiquidation() public {
			//confirm health factor is below 1

			(,,,,,uint healthFactor, ) = lendingPool.getUserAccountData(user, 0); 
			console.log(healthFactor); 

			uint256 balance = IERC20(WETH).balanceOf(newDepositor); 
			console.log(balance); 

		//simulating a loan where a user has taken out a loan in DAI using WETH as collateral
		PeripheralLogic.Protocol protocol = PeripheralLogic.Protocol.YEARN;
		
		PeripheralLogic.Path[] memory paths = new PeripheralLogic.Path[](1); 
		paths[0] = PeripheralLogic.Path({
			tokenIn: WETH,
			fee: 500,
			isIBToken: false,
			protocol: protocol	
		});


		PeripheralLogic.Path memory ibPath = 
			PeripheralLogic.Path({
				tokenIn: yvDAI,
				fee: 0,
				isIBToken: true,
				protocol: protocol 
			}); 
		
		//swap from DAI to WETH
		PeripheralLogic.SwapData memory swapBeforeFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: WETH,
				amount: 0.03 * 1e18, //99 USD
				minOut: 0,
				path: paths
			});
		
		PeripheralLogic.SwapData memory swapAfterFlashloan = 
			PeripheralLogic.SwapData({
				to: WETH,
				from: DAI,
				amount: 0, //addded in by contract
				minOut: 0,
				path: paths
			});

		FlashLoanLiquidation.FlashLoanData memory data = 
			FlashLoanLiquidation.FlashLoanData({
				collateralAsset: yvDAI,
				debtAsset: WETH,
				debtAmount: 0.03 * 1e18,
				trancheId: 0,
				user: user,
				swapBeforeFlashloan: swapBeforeFlashloan,
				swapAfterFlashloan: swapAfterFlashloan,
				ibPath: ibPath
			}); 

			vm.startPrank(newDepositor);	
				IERC20(WETH).approve(address(lendingPool), 100 * 1e18); 
				lendingPool.deposit(WETH, 0, 0.5 * 1e18, newDepositor, 0); 
								
				balance = IERC20(WETH).balanceOf(newDepositor); 
				console.log("balance after deposit", balance); 

				flashLoanLiquidation.flashLoanCall(data);

			vm.stopPrank(); 

			balance = IERC20(WETH).balanceOf(newDepositor); 
			console.log("balance after liq", balance); 

			uint256 balanceOfContract = IERC20(WETH).balanceOf(address(flashLoanLiquidation)); 
			console.log(balanceOfContract); 

			flashLoanLiquidation.sweep(WETH); 

			uint256 balanceMothership = IERC20(WETH).balanceOf(address(mothership)); 
			console.log("motherhsip balance", balanceMothership); 
			address owner = mothership.owner(); 
			console.log("mothership owner", owner); 
			mothership.sweep(WETH); 
			uint256 finalBalance = IERC20(WETH).balanceOf(user); 
			console.log("funds moved to holding wallet:", finalBalance); 

		}


}
	
