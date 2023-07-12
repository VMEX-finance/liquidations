const Web3 = require('web3'); 
const axios = require('axios'); 
const web3 = new Web3('wss://mainnet.infura.io/ws/v3/1cad81887e224784a4d2ad2db5c0587a'); 
const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.11"; 
const lending_pool_address = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"; //aave
const lending_pool_abi = require('../contracts/aaveLendingPool.json'); 
const lendingPool = new web3.eth.Contract(
	lending_pool_abi,
	lending_pool_address
); 
//NOTE: TEST FILE ONLY -- WATCHING LIVE AAVE V2 POOLS


async function subscribe() {
	//subscribe to borrow and withdraw events latest block only
	//don't care about deposits since borrows give us the same information

	lendingPool.events.Borrow({fromBlock: 'latest'})
		.on('data', (event) => {
			console.log(event); 
		});
	lendingPool.events.Deposit({fromBlock: 'latest'})
		.on('data', (event) => {
			console.log(event); 
		});
	lendingPool.events.Withdraw({fromBlock: 'latest'})
		.on('data', (event) => {
			console.log(event); 
		});
}

//subscribe(); 

//async function getEvents() {
//	let currentBlock = await web3.eth.getBlockNumber(); 
//	let historicalBlock = currentBlock - 100;
//
//	const events = await lendingPool.getPastEvents(
//		'Deposit', 
//		{fromBlock: historicalBlock, toBlock: currentBlock}); 
//
//	console.log(events[0].returnValues); 
//}
//
//getEvents(); 


function testNestedObjects() {

	let tranches = [{}]; 
		
	//tranche 0 {
	// user1,
	// user2,
	// user3,
	// user4
	//},
	//tranche 1 {
	//	user 1,
	//	user 5, 
	//	user 6
	//}

	let trancheId = 0; 
	let trancheData = {
		id: trancheId,
		users: []
	};
	
	tranches.push(trancheData); 
	console.log(tranches); 
}

testNestedObjects(); 



