// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

//actual aave implementations
import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol"; 
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol"; 
//vmex lending pool
import {ILendingPool} from "./interfaces/ILendingPool.sol"; 
import {IERC20} from "forge-std/interfaces/IERC20.sol"; 

contract FlashLoanLiquidation is FlashLoanSimpleReceiverBase { 
	
	ILendingPool internal lendingPool; //vmex 
	IPoolAddressesProvider internal constant aaveAddressesProvider = 
		IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e); 

	enum TokenType {
		Token,
		Vault
	} 

	struct SwapData {
		address to;
		address from;
		uint24 fee0;
		uint24 fee1;	
		uint256 amountIn0; 
		uint256 amountIn1; 
	}

	struct FlashLoanData {
		address collateralAsset;  
		address debtAsset;
		uint64 trancheId; 
		address user;
		uint256 debtAmount; 		
		SwapData swapData;
		TokenType tokenType;
	}


	//NOTE: this is aave's address provider, and VMEX's lending pool
	constructor() FlashLoanSimpleReceiverBase(aaveAddressesProvider) { 
	}

	//called automatically by AAVE lending pool
	function executeOperation(
    	address asset,
    	uint256 amount,
    	uint256 premium,
    	address initiator,
    	bytes calldata params
	) external override returns (bool){
	
	
	//TODO check if borrowed asset is what we need, do swaps as necessary
	FlashLoanData memory decodedParams = abi.decode(params, (FlashLoanData)); 
		

	//vmex liquidation			
	lendingPool.liquidationCall(
		decodedParams.collateralAsset,
		decodedParams.debtAsset,
		decodedParams.trancheId,
		decodedParams.user,
		decodedParams.debtAmount,
		false //no vToken
	); 

	uint amountOwing = amount + premium; 
    IERC20(asset).approve(address(POOL), amountOwing);


	return true; 
  }
	
	//bot passes these params in
	function flashLoanCall(
		address collateralAsset, 
		address debtAsset,
		uint64 trancheId, 
		address user,
		SwapData memory swapData,
		TokenType tokenType) public {

		uint256 amountDebt = type(uint256).max; 

		bytes memory params = abi.encode(FlashLoanData({
			collateralAsset: collateralAsset,
			debtAsset: debtAsset,
			trancheId: trancheId,
			user: user,
			debtAmount: amountDebt,
			swapData: swapData,
			tokenType: tokenType})
		); 

		POOL.flashLoanSimple(
			address(this), //receiver
			debtAsset, //we pay down debt so we need the flashloan in the debt asset? 
			amountDebt, 
			params, 
			0 //referral code
		); 
  }


	function _liquidate() internal {
		//unused for now but can move liquidation logic here if needed
	}
		
}
