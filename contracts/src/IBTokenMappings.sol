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
	
	//public constants
	address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; 
	address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; //this is USDCE, not the native version
	//address public constant wstETH_CRV_LP = ;
	//address public constant wstETH_CRV_POOL =; 
	//address public constant sUSD_THREE_CRV =; //lp AND pool  
	//address public constant THREE_CRV =; //lp AND pool 
	//bytes32 public constant SHANGHAI_SHAKEDOWN = ; 
	
	//interfaces
	ISwapRouter internal swapRouter = 
		ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); //same on ETH/OP/ARB/POLY
	IVault internal balancerVault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8); 

	
	//unwrap to weth
	//curve
	address internal constant CRV_wstETH_ETH = 0xDbcD16e622c95AcB2650b38eC799f76BFC557a0b; 

	//balancer
    address internal constant BAL_wstETH_ETH = 0x9791d590788598535278552EEcD4b211bFc790CB; 
    address internal constant BAL_WETH_rETH = 0xadE4A71BB62bEc25154CFc7e6ff49A513B491E81; 

    //camelot
    address internal constant CAM_ARB_ETH = 0xa6c5C7D189fA4eB5Af8ba34E63dCDD3a635D433f; 
    address internal constant CAM_ETH_USDCE = 0x84652bb2539513BAf36e225c930Fdd8eaa63CE27; 
    address internal constant CAM_wstETH_ETH = 0x5201f6482EEA49c90FE609eD9d8F69328bAc8ddA;  


	//unwrap to usdc
	//curve
	address internal constant CRV_sUSD_THREE_CRV = 0x061b87122Ed14b9526A813209C8a59a633257bAb; 
    address internal constant CRV_USDC_USDT = 0x7f90122BF0700F9E7e1F688fe926940E8839F353; 
    address internal constant CRV_FRAX_USDCE = 0xC9B8a3FDECB9D5b218d02555a8Baf332E5B740d5; 

    //camelot
    address internal constant CAM_USDT_USDCE = 0x1C31fB3359357f6436565cCb3E982Bc6Bf4189ae; 
    address internal constant CAM_LUSD_USDCE = 0x1e5b183b589A1d30aE5F6fDB8436F945989828Ca; 


	
	constructor() {
		
	}



 }
