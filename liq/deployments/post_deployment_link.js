const Web3 = require('web3'); 
const web3 = new Web3('ws://127.0.0.1:8545'); 


let flashLoanLiquidationAddress; 
let peripheralLogicAddress; 
let tokenMappingsAddress;  
let mothershipAddress;

async function linkContracts() {
	//psudocode	
	flashloanLiquidtion.methods.init(peripheralLogicAddress, mothershipAddress); 

	flashLoanRouter.methods.init(
		flashLoanLiquidationAddress,
		tokenMappingsAddress,
		peripheralLogicAddress,
		mothershipAddress
	); 

}
