 //SPDX License Identifier: MIT
 pragma solidity >=0.8.0; 


//This contract serves to direct the liquidation bot to new contract addresses after new versions have been deployed
//Just stores the address for the bot to read from, no real upgrading is done or needed
contract FlashLoanRouter {

	address public owner; 
	address public FlashLoanLiquidator; 
	address public IBTokenMappings; 
	address public PeripheralLogic; 
	address public Mothership; 

	constructor() {
		owner = msg.sender; 
	}

	modifier onlyOwner() {
		require(msg.sender == owner);
		_; 
	}

	function init(
		address _flashloan, 
		address _ibTokenMappings, 
		address _peripheralLogic,
		address _mothership
	) external onlyOwner {
		FlashLoanLiquidator = _flashloan; 
		IBTokenMappings = _ibTokenMappings;
		PeripheralLogic = _peripheralLogic; 
		Mothership = _mothership; 
	}

	function setNewFlashloanContract(address newContract) external onlyOwner {
		FlashLoanLiquidator = newContract; 	
	}

	function setNewIBTokenMappings(address newContract) external onlyOwner {
		IBTokenMappings = newContract; 	
	}

	function setNewPeripheralLogic(address newContract) external onlyOwner {
		PeripheralLogic = newContract; 	
	}

	function setNewMothership(address newContract) external onlyOwner {
		Mothership = newContract; 	
	}

 }
