const Web3 = require('web3'); 
const axios = require('axios'); 
const ethers = require('ethers'); 
require('dotenv').config(); 
const web3 = new Web3(process.env.WS_OP_RPC);
const api_url = "https://api.thegraph.com/subgraphs/name/fico23/optimism-vmex"; 
const lendingPoolAddress = "0x60F015F66F3647168831d31C7048ca95bb4FeaF9";
const lendingPoolAbi = require('../contracts/lendingPoolAbi.json');  
const lendingPool = new web3.eth.Contract(
	lendingPoolAbi,
	lendingPoolAddress
); 

let tranches = []; 

//simple: 
//	all we want to do is store the user in an array with the tranche they've deposited into
//	each block, we will loop through the users with the associated tranche, and we will check their health factors
//	if we find one that can be liquidated, we will query their loan data from the subgraph
//
//periodically, we can query loans of users to determine if they are still actively borrowing through the subgraph, if they aren't we can remove them
//if for whatever reason, the service needs to be restarted, we can use this to repopulate the tranches array with relevant data before reading the events from onchain 
async function initializeTranchesArray() {	
	let output = []; 
	await axios.post(api_url, { 
		query: `{
		  users(where: {borrowedReservesCount_gte:0}) {
			id
			borrowedReservesCount
    		borrowReserve: reserves(where: {currentTotalDebt_gt: 0}) {
    		  reserve {
    		    tranche {
    		      id
    		    }
    		}
    	}
	}
}`
	}).then((res) => {
	//verify that the array is empty
		if (tranches.length == 0) {
			const data = res.data.data; 
			let trancheData; 
			for (let i = 0; i < data.users.length; i++) {
				const user = data.users[i]; 
				for (let j = 0; j < user.borrowReserve.length; j++) {
					trancheData = {
						id: user.borrowReserve[j].reserve.tranche.id.toString().slice(43),
						user: user.id
					}
					tranches.push(trancheData); 
				}
			}

		}
	
		let temp = [];  
		for (let i in tranches) {
			const trancheId = tranches[i].id; 	
			if (temp.length == 0 || !temp.includes(trancheId)) {
				temp.push(trancheId); 
			}

		}

		let trancheTemp = []; 
		for (i in temp) {
			let tranche = {
				id: temp[i],
				users: []
			}
			trancheTemp.push(tranche); 
		}
		
		for (let i in tranches) {
			for (let j in trancheTemp) {
				if (tranches[i].id == trancheTemp[j].id) {
					if (!trancheTemp[j].users.includes(tranches[i].user)) {
						trancheTemp[j].users.push(tranches[i].user); 			
					}
				}
			}
		}
		
		tranches = trancheTemp; 
	});

	console.log(tranches); 
	console.log("tranches initialized from subgraph data \n"); 

}  


//helper
function getIndex(tranche) {
		
	for (i in tranches) {
		if (tranches[i].id == tranche) {
			return i;
		}
	}
	
	return -1; 
}

//initializeTranchesArray(); 

async function getBorrowEvents() {
	//only check borrow events since we only care about if they're actively borrowing
	lendingPool.events.Borrow({fromBlock: 'latest'})
		.on('data', (event) => {
			filterEvents(event); 
		});
}

function filterEvents(eventData) {	
	let userId = web3.utils.toChecksumAddress(eventData.returnValues.user);
	let trancheId = eventData.returnValues.trancheId; 
	const index = getIndex(trancheId); 
	if (index == -1) {
		let tranche = {
			id: trancheId,
			users: []
		};
	
		tranche.users.push(userId); 
		tranches.push(tranche); 

	} else {
		if (tranches[index].users.includes(userId)) {
				console.log("user already in tranche, no need to add..."); 
		} else {
			tranches[index].users.push(userId); 
		}
	}

	console.log(`${userId} added to tranche ${index}`); 
	console.log(tranches); 

}

async function getLiquidatableAccounts() {
	let liquidatable = [];
	for (let i = 0; i < tranches.length; i++) {
		for (let j = 0; j < tranches[i].users.length; j++) {
			let healthFactor; 
				try {
				healthFactor = await getHealthFactor(tranches[i].users[j], tranches[i].id);
				} catch (healthFactorError) {
					console.log(healthFactorError); 
					return; 
				}
			if (healthFactor < 1e18) {
				liquidatable.push({user: tranches[i].users[j], tranche: tranches[i].id}); 	
			}
		}
	}

	return liquidatable; 
}
	

//instead of looping through every user, we should probably just get active borrows
async function getLiquidationData() {
	let liquidatableAccounts = await getLiquidatableAccounts(); 
	
	//what to do if multiple borrows/collats can be liquidated in the same tranche
	//this should already work if a single user has liquidatable loans across multiple tranches
	for (let i = 0; i < liquidatableAccounts.length; i++) {
		let trancheData = await getTrancheDatasForUser(liquidatableAccounts[i].user); 
		
		for (let j = 0; j < trancheData.tranches.length; j++) {
			const liquidationData = {
				user: liquidatableAccounts[i].user,
				tranche: liquidatableAccounts[i].tranche,
				collateralAsset: trancheData.tranches[j].collat[0],
				debtAsset: trancheData.tranches[j].debt[0],
				debtAmount: trancheData.tranches[j].amount
			}
		}
	}

			liquidatable.push(liquidationData); 

	return liquidatable; 
}

module.exports = { getLiquidatableAccounts, getLiquidationData, initializeTranchesArray, getBorrowEvents, getTrancheDatasForUser }; 

//NOTE: can return multiple borrows/collateral per tranche per user
async function getTrancheDatasForUser(user) {
	let userData = {};
	
	//have to convert to string and to lowercase or it breaks???? dumb. IT'S ALREADY A STRING. I should have written this in TS. sigh.  
	await axios.post(api_url, { 
		query: `{
			user(id: "${user.toString().toLowerCase()}") { 
				borrowedReservesCount 
				borrowReserve: reserves(where: {currentTotalDebt_gt: 0}) {
				currentTotalDebt
				reserve {
					assetData {
						underlyingAssetName
						id
					}
				tranche {
		   		    id
					}
				}
		   	}
				collateralReserve: reserves{
					currentATokenBalance
					reserve{
						assetData {
						underlyingAssetName
						id
		   		     }
		   		     tranche{
		   		       id
		   		     }
		   		   }
		   		 }
				}
		}
`
	}).then((res) => {
		const data = res.data.data; 
		const userRes = data.user; 
		console.log(userRes); 
		userData = {
			id: "",
		}
		userData.tranches = []; 
		userData.id = user; 
		for (let i = 0; i < userRes.borrowReserve.length; i++) {
			let id = userRes.borrowReserve[i].reserve.tranche.id.toString().slice(43); 
			let tranche = {
				id: id,
				amount: userRes.borrowReserve[i].currentTotalDebt
			}	

			tranche.debts = []; 
			tranche.debts.push(userRes.borrowReserve[i].reserve.assetData.id); 
			userData.tranches.push(tranche); 
		}
				

		//check if the collateral tranche id matches with the borrow one
		//if it does, put the relevant data
		//if it doesn't, discard it
		//
		//(at some point I will rework this monstrosity, but that point is not today)
		for (let i = 0; i < userRes.collateralReserve.length; i++) {
			let id = userRes.collateralReserve[i].reserve.tranche.id.toString().slice(43); 
			for (let j = 0; j < userRes.borrowReserve.length; j++) {
				let borrowId = userRes.borrowReserve[j].reserve.tranche.id.toString().slice(43); 
				if (id == borrowId) {
					for (let k = 0; k < userData.tranches.length; k++) {
						if (userData.tranches[k].id == id) {
							userData.tranches[k].collateralAsset = userRes.collateralReserve[i].reserve.assetData.id; 
						}
					}
				}
			}
		}
	}); 

	return userData; 
}

//getTrancheDatasForUser("0x4d180AF22cd72b8c6593656a0e123E0C4760e6ac"); 

//NOTE: periodically cleanup inactive loans
async function removeUsersWithoutActiveLoans() {
	for (let i = 0; i < tranches.length; i++) {
		let user = tranches[i].user; 	
		await axios.post(api_url, { 
			query: `{
				user(id: "${user}") { 
					borrowedReservesCount 
				}
			}`.then((res) => {
				let data = res.data.data; 
				if (data.borrowedReservesCount == 0) {
					tranches.splice(i, 1); 
				}
			}) 
		}); 
	}
}

//removeUsersWithoutActiveLoans(); 
//
//web3js is dog so we use ethers for this one specific part, if anyone knows the equivalent of callStatic for web3js pls lmk
const provider = new ethers.providers.InfuraProvider('optimism'); 
const signer = new ethers.Wallet(
	process.env.PRIVATE_KEY,
	provider
);

const contract = new ethers.Contract(lendingPoolAddress, lendingPoolAbi, signer); 

async function getHealthFactor(user, tranche) {
	const accountData = await contract.callStatic.getUserAccountData(user, tranche); 
	const healthFactor = Number(accountData[5].toString()); 
	return healthFactor; 
}

