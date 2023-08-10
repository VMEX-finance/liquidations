 //SPDX License Identifier: MIT
 pragma solidity >=0.8.0; 

import {IERC20} from "forge-std/interfaces/IERC20.sol"; 
import {FlashLoanRouter} from "./Router.sol"; 


 contract Mothership {
	
	FlashLoanRouter public router;
	address public owner; 
	address public holdingAccount; //external team wallet

	constructor(FlashLoanRouter _router, address _holdingAccount) {
		router = _router; 
		owner = msg.sender; 
		holdingAccount = _holdingAccount; 
	}	

	modifier onlyOwner() {
		require(msg.sender == owner);
		_; 
	}

	modifier onlyFlashLoanContract() {
		require(msg.sender == router.FlashLoanLiquidator()); 
		_; 
	}

	function request(address token, uint256 amount) external onlyFlashLoanContract {
		address flashLoanContract = router.FlashLoanLiquidator(); 
		IERC20(token).transfer(flashLoanContract, amount);  
	}

	function sweep(address token) external onlyOwner {
		uint256 balance = IERC20(token).balanceOf(address(this)); 
		IERC20(token).transfer(holdingAccount, balance); 	
	}	

	receive() external payable {

	}

}
