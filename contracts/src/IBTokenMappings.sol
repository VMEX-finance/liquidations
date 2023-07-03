 //SPDX License Identifier: MIT
 pragma solidity >=0.8.0; 

import {IVeloRouter} from "./interfaces/IVeloRouter.sol"; 
import {ISwapRouter} from "./interfaces/ISwapRouter.sol"; 
import {IVault} from "./interfaces/IBalancerVault.sol"; 


contract IBTokenMappings {
	
	//public mappings
	mapping(address => address) public tokenMappings; 
	mapping(address => bytes32) public beetsLookup; 
	mapping(address => bool) public flashloanable;
	mapping(address => bool) public stable; 
	
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
	//velo v1
	address internal constant VELO_wstETH_ETH = 0xc6C1E8399C1c33a3f1959f2f77349D74a373345c; 
	address internal constant VELO_ETH_USDC = 0x79c912FEF520be002c2B6e57EC4324e260f38E50; 
	address internal constant VELO_OP_ETH = 0xcdd41009E74bD1AE4F7B2EeCF892e4bC718b9302; 
	//beets
	bytes32 internal constant ROCKET_FUEL = 0x4fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002b; 

	
	//unwrap to usdc
	
	//curve
	address internal constant CRV_sUSD_THREE_CRV = 0x061b87122Ed14b9526A813209C8a59a633257bAb; 
	//velo v1
	address internal constant VELO_OP_USDC = 0x47029bc8f5CBe3b464004E87eF9c9419a48018cd;
	address internal constant VELO_SNX_USDC = 0x9056EB7Ca982a5Dd65A584189994e6a27318067D; 
	address internal constant VELO_sUSD_USDC = 0xd16232ad60188B68076a235c65d692090caba155; 
	address internal constant VELO_DAI_USDC = 0x4F7ebc19844259386DBdDB7b2eB759eeFc6F8353; 
	address internal constant VELO_FRAX_USDC = 0xAdF902b11e4ad36B227B84d856B229258b0b0465; 
	address internal constant VELO_USDT_USDC = 0xe08d427724d8a2673FE0bE3A81b7db17BE835B36; 

	
	constructor() {
		tokenMappings[CRV_wstETH_ETH] = WETH; 

		tokenMappings[VELO_wstETH_ETH] = WETH; 	
		stable[VELO_wstETH_ETH] = false; //has more liquidity than stable pair

		tokenMappings[VELO_ETH_USDC] = WETH; 	
		stable[VELO_ETH_USDC] = false; 

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
		
		//shangai shakedown	
		beetsLookup[0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2] = SHANGHAI_SHAKEDOWN; 
		//rocket fuel
		beetsLookup[0x4Fd63966879300caFafBB35D157dC5229278Ed23] = ROCKET_FUEL; 
		
	}



 }
