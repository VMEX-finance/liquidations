 //SPDX License Identifier: MIT
 pragma solidity >=0.8.0; 


//This contract serves to direct the liquidation bot to new contract addresses after new versions have been deployed
//Just stores the address for the bot to read from, no real upgrading is done or needed
contract FlashLoanRouter {

	address public owner; 
	address public FlashLoanLiquidator; 
	address public IBTokenMappings; 
	address public PeripheralLogic; 

	constructor() {
		owner = msg.sender; 
	}

	modifier onlyOnwer() {
		require(msg.sender == owner);
		_; 
	}

	function setNewFlashloanContract(address newContract) external onlyOnwer {
		FlashLoanLiquidator = newContract; 	
	}

	function setNewIBTokenMappings(address newContract) external onlyOnwer {
		IBTokenMappings = newContract; 	
	}

	function setNewPeripheralLogic(address newContract) external onlyOnwer {
		PeripheralLogic = newContract; 	
	}

 }
