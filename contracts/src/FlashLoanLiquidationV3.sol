// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

//actual aave implementations
import {FlashLoanSimpleReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol"; 

//vmex lending pool
import {ILendingPool} from "./interfaces/ILendingPool.sol"; 

//periphery
import {IERC20} from "forge-std/interfaces/IERC20.sol"; 
import {PeripheralLogic} from "./PeripheralLogic.sol"; 
import {Mothership} from "./Mothership.sol"; 

import "forge-std/Test.sol"; 

contract FlashLoanLiquidation is FlashLoanSimpleReceiverBase, Test { 

	ILendingPool internal lendingPool; //vmex 

	IPoolAddressesProvider internal constant aaveAddressesProvider = 
		IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb); //OP

	PeripheralLogic public peripheralLogic; 
	Mothership public mothership; 

	address public owner; 
	bool public active = true; 
	uint256 public MAX_SLIPPAGE = 500; //5%

	struct FlashLoanData {
		address collateralAsset;  
		address debtAsset;
		uint256 debtAmount; 		
		uint64 trancheId; 
		address user;
		PeripheralLogic.SwapData swapBeforeFlashloan;
		PeripheralLogic.SwapData swapAfterFlashloan; 
		PeripheralLogic.Path ibPath; 
	}


	//NOTE: this is aave's address provider, not ours
	constructor() FlashLoanSimpleReceiverBase(aaveAddressesProvider) {
		owner = msg.sender; 
	}
	
	//IMPORTANT -- CALL THIS AFTER PERIPHERAL LOGIC HAS BEEN DELPOYED
	function init(PeripheralLogic _peripheralLogic, Mothership _mothership) external {
		require(msg.sender == owner); 
		peripheralLogic = _peripheralLogic; 
		mothership = _mothership; 
	}

	//called automatically by AAVE lending pool
	function executeOperation(
    	address asset,
    	uint256 amount,
    	uint256 premium,
    	address initiator,
    	bytes calldata params
	) external override returns (bool){
	
	
	FlashLoanData memory decodedParams = abi.decode(params, (FlashLoanData)); 
	console.log("amount flashloaned", amount); 	
	//if we need to swap, this will contain the necessary tokens to swap to. If we do not need to swap, the tokens in swapData.to and swapData.from will be the same. 
	//if not the same, then we swap to the appropriate token using univ3 router.  
	//this will already be set by the node script, including amountsOut
	
	//initial swap from flashloaned token to debtAsset if debtAsset is NOT flashloanable
	uint256 amountOut; 
	PeripheralLogic.SwapData memory swapBeforeFlashloan = decodedParams.swapBeforeFlashloan; 
	console.log("balance flashloan.from before swap", IERC20(swapBeforeFlashloan.from).balanceOf(address(this))); 
	if (swapBeforeFlashloan.to != swapBeforeFlashloan.from) { 
		IERC20(swapBeforeFlashloan.from).transfer(
			address(peripheralLogic), 
			swapBeforeFlashloan.amount
		); 
		amountOut = peripheralLogic._swap(decodedParams.swapBeforeFlashloan); 
	}
	
	//TODO: mock this out later
	//vmex liquidation			
	//lendingPool.liquidationCall(
	//	decodedParams.collateralAsset,
	//	decodedParams.debtAsset,
	//	decodedParams.trancheId,
	//	decodedParams.user,
	//	decodedParams.debtAmount,
	//	false //no vToken/aToken
	//); 

	//after liquidation, receive a single asset of collateral of amount (debtAmount + liquidation bonus) in usd
	uint256 afterLiquidationBalance = 
		IERC20(decodedParams.collateralAsset).balanceOf(address(this)); 
	console.log("after liquidation balance of collateral", afterLiquidationBalance); 

	//unwrap if necessary -> swap back to floashloaned token
	//if vault -> we use the underlying token
	
	if (decodedParams.ibPath.isIBToken == true) {
		IERC20(decodedParams.collateralAsset).transfer(
			address(peripheralLogic),
			afterLiquidationBalance
		);
		peripheralLogic._unwrapIBToken(
			decodedParams.collateralAsset, 
			decodedParams.ibPath.protocol
		); 
	}

	//swap back after the flashloan if necessary	
	if (decodedParams.swapAfterFlashloan.to != decodedParams.swapAfterFlashloan.from) {
		PeripheralLogic.SwapData memory swapAfterFlashloan = decodedParams.swapAfterFlashloan; 
		decodedParams.swapAfterFlashloan.amount = afterLiquidationBalance; 
		IERC20(decodedParams.collateralAsset).transfer(
			address(peripheralLogic), 
			swapAfterFlashloan.amount
		); 
		peripheralLogic._swap(decodedParams.swapAfterFlashloan); 
	}
	

	uint256 amountOwing = amount + premium; 
	uint256 amountAfterAllTxns = IERC20(asset).balanceOf(address(this)); 
	uint256 totalToPayOut = amountOwing + (amountOwing * MAX_SLIPPAGE / 10000); 
	console.log("total + MAX_SLIPPAGE (5%):", totalToPayOut); 
	console.log("amount after all swaps", amountAfterAllTxns); 
	console.log("amount owing", amountOwing); 

	if (amountAfterAllTxns < amountOwing) {
		uint256 dif = amountOwing - amountAfterAllTxns; 
		require(dif < totalToPayOut, "max slippage exceeded"); 
		requestFundsFromMothership(asset, dif); //difference between the amount we need and the amount we have 
	}

    IERC20(asset).approve(address(POOL), amountOwing);

	return true; 
  }
	
	//bot passes these params in
	function flashLoanCall(FlashLoanData memory data) public {	
		require(active == true, "not active implementation"); 

		//keeping in mind that debtAsset here may not actually be the actual debt asset until after the swap has occurred	
		bytes memory params = abi.encode(data); 
		POOL.flashLoanSimple(
			address(this), //receiver
			data.debtAsset,
			data.debtAmount, 
			params, 
			0 //referral code
		); 
  }
	
	//requests funds to cover the difference if the liquidation is not profitable
	function requestFundsFromMothership(address token, uint256 amount) internal {
		mothership.request(token, amount); 	
	}
	
	receive() external payable {} 

	////////// housekeeping logic //////////
	modifier onlyOwner() {
		require(msg.sender == owner); 
		_; 
	}

	function sweep(address token) external onlyOwner {
		uint256 balance = IERC20(token).balanceOf(address(this)); 
		IERC20(token).transfer(address(mothership), balance); 	
	}	

	function setOwner(address newOwner) external onlyOwner {
		owner = newOwner;  
	}

	function changeMaxSlippage(uint256 newMax) external onlyOwner {
		MAX_SLIPPAGE = newMax; 
	}

	function disable() external onlyOwner {
		active = false; 
	}

	function enable() external onlyOwner {
		active = true; 
	}
}
