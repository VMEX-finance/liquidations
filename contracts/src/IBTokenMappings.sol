 //SPDX License Identifier: MIT
 pragma solidity >=0.8.0; 



contract IBTokenMappings {

	mapping(address => address) public tokenMappings; 
	mapping(address => bytes32) public beetsLookup; 
	mapping(address => bool) public flashloanable;
	mapping(address => bool) public stable; 

	address public constant WETH = 0x4200000000000000000000000000000000000006; 
	address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;  
	address public constant wstETH_CRV_LP = 0xEfDE221f306152971D8e9f181bFe998447975810;
	address public constant wstETH_CRV_POOL = 0xB90B9B1F91a01Ea22A182CD84C1E22222e39B415; 
	address public constant 3CRV = 0x1337BedC9D22ecbe766dF105c9623922A27963EC; //lp AND pool 

	
	//THESE ARE BEEFY VAULTS CONTAINING THE UNDERLYING LP TOKEN -- NOT THE LP TOKEN ITSELF
	//except beets
	
	//curve
	address internal constant CRV_wstETH_ETH = 0x0892a178c363b4739e5Ac89E9155B9c30214C0c0; 
	address internal constant VELO_wstETH_ETH = 0xca39e63E3b798D5A3f44CA56A123E3FCc29ad598; 
	address internal constant VELO_ETH_USDC = 0xB708038C1b4cF9f91CcB918DAD1B9fD757ADa5C1; 
	address internal constant VELO_OP_ETH = 0xC9737c178d327b410068a1d0ae2D30ef8e428754; 
	bytes32 internal constant BEETS_wstETH_ETH = 0x7b50775383d3d6f0215a8f290f2c9e2eebbeceb200020000000000000000008b;  
	bytes32 internal constant BEETS_rETH_ETH = 0x4fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002b; 
	address internal constant CRV_sUSD_3CRV = 0x107Dbf9c9C0EF2Df114159e5C7DC2baf7C444cFF; 
	address internal constant VELO_SNX_USDC = 0x48B3EdF0D7412B11c232BD9A5114B590B7F28134; 
	address internal constant VELO_sUSD_USDC = 0x2232455bf4622002c1416153EE59fd32B239863B; 
	address internal constant VELO_OP_USDC = 0x613f54c8836FD2C09B910869AC9d4de5e49Db1d8; 
	address internal constant VELO_DAI_USDC = 0x43F6De3D9fB0D5EED93d7E7E14A8A526B98f8A58; 
	address internal constant VELO_FRAX_USDC =  0x587c3e2e17c59b09B120fc2D27E0eAd6edD2C71D; 
	address internal constant VELO_USDT_USDC =  0x0495a700407975b2641Fa61Aef5Ccd0106F525Cc; 

	
	constructor() {
		tokenMappings[CRV_wstETH_ETH] = WETH; 

		tokenMappings[VELO_wstETH_ETH] = WETH; 	
		stable[VELO_wstETH_ETH] = false; //has more liquidity than stable pair

		tokenMappings[VELO_ETH_USDC] = WETH; 	
		stable[VELO_ETH_USDC] = false; 

		tokenMappings[VELO_OP_ETH] = WETH; 	
		stable[VELO_OP_ETH] = false;  

		tokenMappings[CRV_sUSD_3CRV] = USDC; 

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
		beetsLookup[0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2] = BEETS_wstETH_ETH; 
		//rocket fuel
		beetsLookup[0x4Fd63966879300caFafBB35D157dC5229278Ed23] = BEETS_rETH_ETH; 
		
	}



 }
