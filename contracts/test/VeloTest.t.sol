// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/interfaces/IERC20.sol"; 
import "../src/interfaces/IVeloRouter.sol"; 
import "../src/interfaces/IVeloPair.sol"; 

contract VeloTest is Test {
	//all tokens are OP addresses
	address internal WETH = 0x4200000000000000000000000000000000000006; 
	address internal DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
	address internal USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607; 
	address internal wstETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb; 


	//test curve unwraps
	address internal constant CRV_wstETH_ETH = 0x0892a178c363b4739e5Ac89E9155B9c30214C0c0; 
	address internal constant CRV_sUSD_3CRV = 0x107Dbf9c9C0EF2Df114159e5C7DC2baf7C444cFF; 

	//test velo unwraps
	address internal constant MOO_wstETH_ETH = 0xca39e63E3b798D5A3f44CA56A123E3FCc29ad598; 
	address internal constant VELO_wstETH_ETH = 0xc6C1E8399C1c33a3f1959f2f77349D74a373345c; 

	address internal user = address(69); 
	IVeloRouter veloRouter = IVeloRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f); 

    function setUp() public {

		deal(DAI, user, 1000 * 1e18); 
		deal(WETH, address(this), 1000 * 1e18); 
		deal(USDC, user, 1000 * 1e18); 
		deal(wstETH, address(this), 1000 * 1e18); 
    }

	function testAddLiquidity() public {
		IERC20(WETH).approve(address(veloRouter), 1000 * 1e18); 				
		IERC20(wstETH).approve(address(veloRouter), 1000 * 1e18); 				

		(uint256 a, uint256 b, uint256 liq) = veloRouter.addLiquidity(
			WETH,
			wstETH,
			false,
			100 * 1e18,
			100 * 1e18,
			0,
			0,
			address(this),
			block.timestamp
		); 

		console.log("a", a); 
		console.log("b", b); 
		console.log("liquidity", liq); 

		console.log(IERC20(VELO_wstETH_ETH).balanceOf(address(this))); 

		IERC20(VELO_wstETH_ETH).approve(address(veloRouter), 1000 * 1e18); 
		(uint256 amount0, uint256 amount1) = veloRouter.removeLiquidity(
			WETH,
			wstETH,
			false,
			liq,
			99 * 1e18,
			88 * 1e18,
			address(this),
			block.timestamp
		);

		console.log("a0", amount0);
		console.log("a1", amount1);

	}

	
}
