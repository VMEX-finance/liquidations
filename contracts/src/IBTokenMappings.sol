 //SPDX License Identifier: MIT
 pragma solidity >=0.8.0; 

import {IVeloRouter} from "./interfaces/IVeloRouter.sol"; 
import {ISwapRouter} from "./interfaces/ISwapRouter.sol"; 
import {IVault} from "./interfaces/IBalancerVault.sol"; 


contract IBTokenMappings {
	
	//public mappings
	mapping(address => address) public tokenMappings; 
	mapping(address => bytes32) public beetsLookup; 
	mapping(address => bool) public flashloanable; mapping(address => bool) public stable; 
	
	//public constants
	address public constant WETH = 0x4200000000000000000000000000000000000006; 
	address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;  
	address public constant wstETH_CRV_LP = 0xEfDE221f306152971D8e9f181bFe998447975810;
	address public constant wstETH_CRV_POOL = 0xB90B9B1F91a01Ea22A182CD84C1E22222e39B415; 
	address public constant sUSD_THREE_CRV = 0x061b87122Ed14b9526A813209C8a59a633257bAb; //lp AND pool  
	address public constant THREE_CRV = 0x1337BedC9D22ecbe766dF105c9623922A27963EC; //lp AND pool 
	bytes32 public constant SHANGHAI_SHAKEDOWN = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b; 
	
	//interfaces
	IVeloRouter internal constant veloRouter = 
		IVeloRouter(0x9c12939390052919aF3155f41Bf4160Fd3666A6f); 
	ISwapRouter internal swapRouter = 
		ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //same on ETH/OP/ARB/POLY
	IVault internal balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8); 


	
	//CURVE MAY BE BEEFY VAULTS CONTAINING THE UNDERLYING LP TOKEN -- NOT THE LP TOKEN ITSELF
	
	//unwrap to weth
	
	//curve
	address internal constant CRV_wstETH_ETH = 0x0892a178c363b4739e5Ac89E9155B9c30214C0c0; 
	//velo v2
	address internal constant VELO_wstETH_ETH = 0x6dA98Bde0068d10DDD11b468b197eA97D96F96Bc; 
	address internal constant VELO_ETH_USDC = 0x0493Bf8b6DBB159Ce2Db2E0E8403E753Abd1235b; 
	address internal constant VELO_OP_ETH = 0xd25711EdfBf747efCE181442Cc1D8F5F8fc8a0D3; 
	address internal constant VELO_rETH_ETH = 0x7e0F65FAB1524dA9E2E5711D160541cf1199912E; 
	address internal constant VELO_LUSD_ETH = 0x6387765fFA609aB9A1dA1B16C455548Bfed7CbEA; 

	//beets
	bytes32 internal constant ROCKET_FUEL = 0x4fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002b; 

	
	//unwrap to usdc
	
	//curve
	address internal constant CRV_sUSD_THREE_CRV = 0x061b87122Ed14b9526A813209C8a59a633257bAb; 
	//velo v2
	address internal constant VELO_OP_USDC = 0x0df083de449F75691fc5A36477a6f3284C269108;
	address internal constant VELO_SNX_USDC = 0x71d53B5B7141E1ec9A3Fc9Cc48b4766102d14A4A; 
	address internal constant VELO_sUSD_USDC = 0x6d5BA400640226e24b50214d2bBb3D4Db8e6e15a; 
	address internal constant VELO_DAI_USDC = 0x19715771E30c93915A5bbDa134d782b81A820076; 
	address internal constant VELO_FRAX_USDC = 0x8542DD4744edEa38b8a9306268b08F4D26d38581; 
	address internal constant VELO_USDT_USDC = 0x2B47C794c3789f499D8A54Ec12f949EeCCE8bA16; 
	address internal constant VELO_LUSD_USDC = 0xf04458f7B21265b80FC340dE7Ee598e24485c5bB; 

	//yearn
	address internal constant yvUSDC = 0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2; 
	address internal constant yvDAI = 0x65343F414FFD6c97b0f6add33d16F6845Ac22BAc; 
	address internal constant yvUSDT = 0xFaee21D0f0Af88EE72BB6d68E54a90E6EC2616de; 
	address internal constant yvWETH = 0x5B977577Eb8a480f63e11FC615D6753adB8652Ae; 


	
	constructor() {
		tokenMappings[CRV_wstETH_ETH] = WETH; 

		tokenMappings[VELO_wstETH_ETH] = WETH; 	
		stable[VELO_wstETH_ETH] = false; //has more liquidity than stable pair

		tokenMappings[VELO_rETH_ETH] = WETH; 
		stable[VELO_rETH_ETH] = false; 

		tokenMappings[VELO_ETH_USDC] = WETH; 	
		stable[VELO_ETH_USDC] = false; 

		tokenMappings[VELO_LUSD_ETH] = WETH; 
		stable[VELO_LUSD_ETH] = false; 

		tokenMappings[VELO_OP_ETH] = WETH; 	
		stable[VELO_OP_ETH] = false;  

		tokenMappings[CRV_sUSD_THREE_CRV] = USDC; 

		tokenMappings[VELO_SNX_USDC] = USDC; 	
		stable[VELO_SNX_USDC] = false; 

		tokenMappings[VELO_sUSD_USDC] = USDC; 	
		stable[VELO_sUSD_USDC] = true; 

		tokenMappings[VELO_OP_USDC] = USDC; 	
		stable[VELO_OP_USDC] = false; 

		tokenMappings[VELO_DAI_USDC] = USDC; 	
		stable[VELO_DAI_USDC] = true;

		tokenMappings[VELO_FRAX_USDC] = USDC; 	
		stable[VELO_FRAX_USDC] = true; 

		tokenMappings[VELO_USDT_USDC] = USDC; 	
		stable[VELO_USDT_USDC] = true; 

		tokenMappings[VELO_LUSD_USDC] = USDC; 
		stable[VELO_LUSD_USDC] = true; 
		
		//shangai shakedown	
		beetsLookup[0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2] = SHANGHAI_SHAKEDOWN; 
		//rocket fuel
		beetsLookup[0x4Fd63966879300caFafBB35D157dC5229278Ed23] = ROCKET_FUEL; 
		
	}



 }
