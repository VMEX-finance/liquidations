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
let reserves = [
  {
    id: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    users: [ '0x35808696D0355B26DbA97d140eE999A6f7509AfE' ]
  },
  {
    id: '0x514910771AF9Ca656af840dff83E8264EcF986CA',
    users: [ '0xCF2D25f4eC502c3EF7b49b4c0247B01096Ad43c9' ]
  },
  {
    id: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
    users: [ '0x35808696D0355B26DbA97d140eE999A6f7509AfE' ]
  },
  {
    id: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    users: [ '0x80Aca0C645fEdABaa20fd2Bf0Daf57885A309FE6' ]
  }
] 

async function subscribe() {
	//subscribe to borrow and withdraw events latest block only
	//don't care about deposits since borrows give us the same information

	lendingPool.events.Borrow({fromBlock: 'latest'})
		.on('data', (event) => {
			console.log(event); 
			filterEvents(event); 
		});
	lendingPool.events.Deposit({fromBlock: 'latest'})
		.on('data', (event) => {
			console.log(event); 
			filterEvents(event); 
		});
	lendingPool.events.Withdraw({fromBlock: 'latest'})
		.on('data', (event) => {
			console.log(event); 
			filterEvents(event); 
		});
}

//subscribe(); 

async function filterEvents(eventData) {	
	let userId = eventData.returnValues.user;
	let reserveId = eventData.returnValues.reserve; 
	console.log(reserveId); 
	const index = getIndex(reserveId); 
	if (index == -1) {
		let res = {
			id: reserveId,
			users: []
		};
		
		res.users.push(userId); 
		reserves.push(res); 
	} else {
		if (!reserves[index].users.includes(userId)) {
			reserves[index].users.push(userId); 
		}
	}

	console.log(reserves); 
}

function getIndex(reserve) {
	//console.log(reserves); 
	//let reserveId = reserve; 
	for (i in reserves) {
		if (reserves[i].id == reserve) {
			console.log(i); 
			return i;
		}
	}
	
	console.log(-1); 
	return -1; 
}

let t = [
  { id: '0', users: [ '0x4d180af22cd72b8c6593656a0e123e0c4760e6ac' ] }
]; 

function whyNoWork(index, userId) {
	if (t[index].users.includes(userId)) {
		console.log("found user"); 
	} else {
		console.log("not working"); 
	}
}

whyNoWork(0, "0x4d180af22cd72b8c6593656a0e123e0c4760e6ac"); 


