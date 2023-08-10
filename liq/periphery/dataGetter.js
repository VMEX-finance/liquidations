const Web3 = require('web3'); 
const axios = require('axios'); 
const web3 = new Web3(process.env.OP_RPC); //TODO: set to wss 
const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.11"; 
const lending_pool_address = "0xdff58B48df141BCb86Ba6d06EEaABF02Ef45C528"; //GOERLI TODO: replace with mainnet address
const lending_pool_abi = require('../contracts/lendingPoolAbi.json').abi; 
const lendingPool = new web3.eth.Contract(
	lending_pool_abi,
	lending_pool_address
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
		  users(where: {borrowedReservesCount_gt:0}) {
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
						id: user.borrowReserve[j].reserve.tranche.id,
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
					trancheTemp[j].users.push(tranches[i].user); 			
				}
			}
		}
		
		tranches = trancheTemp; 
	});
	//console.log(tranches); 
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
	lendingPool.events.Borrow({fromBlock: "latest"},
		(events) => {
			filterEvents(events); 
	}); 

}

function filterEvents(eventData) {	
	let userId = eventData.returnValues.user;
	let trancheId = eventData.returnValues.tranche; 
	const index = getIndex(trancheId); 
	if (index == -1) {
		let tranche = {
			id: trancheId,
			users: []
		};
		
		tranche.users.push(userId); 
		tranches.push(tranche); 
	} else {
		if (!tranches[index].users.includes(userId)) {
			tranches[index].users.push(userId); 
		}
	}
}

async function getLiquidatableAccounts() {
	let liquidatable = [];
	for (let i = 0; i < tranches.length; i++) {
		for (let j = 0; j < tranches[i].users.length; j++) {
			const healthFactor = await getHealthFactor(tranches[i].users[j], tranches[i].id); 
			if (healthFactor < 1e18) {
				liquidatable.push({user: tranches[i].users[j], tranche: tranches[i].id}); 	
			}
		}
	}

	return liquidatable; 
}
	

//instead of looping through every user, we should probably just get active borrows
//we need a new 
async function getLiquidationData() {
	let liquidatableAccounts = await getLiquidatableAccounts(); 
	
	//TODO: what to do if multiple borrows/collats can be liquidated in the same tranche
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

module.exports = { getLiquidatableAccounts, getLiquidationData, initializeTranchesArray, getBorrowEvents }; 

//NOTE: can return multiple borrows/collateral per tranche per user
//TODO: maybe return only relevant collateral for tranche?
async function getTrancheDatasForUser(user) {
	let userData = {};

	await axios.post(api_url, { 
		query: `{
			user(id: "${user}") { 
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
		userData = {
			id: "",
		}
		userData.tranches = []; 
	//TODO: check that this works with multiple borrows and array doesn't overwrite
		userData.id = user; 
		for (let i = 0; i < userRes.borrowReserve.length; i++) {
			let tranche = {
				id: userRes.borrowReserve[i].reserve.tranche.id,
				amount: userRes.borrowReserve[i].currentTotalDebt
			}	

			tranche.debts = []; 
			tranche.debts.push(userRes.borrowReserve[i].reserve.assetData.id); 
			userData.tranches.push(tranche); 
		}
				

		//check if the collateral tranche id matches with the borrow one
		//if it does, put the relevant data
		//if it doesn't, discard it
		for (let i = 0; i < userRes.collateralReserve.length; i++) {
			for (let j = 0; j < userData.tranches.length; j++) {
				if (userData.tranches[j].id == 
					userRes.collateralReserve[i].reserve.tranche.id) {
						if (userData.tranches[j].collat == undefined) {
							userData.tranches[j].collat = []; 
						}
						userData.tranches[j].collat.push(userRes.collateralReserve[i].reserve.assetData.id); 
						}
					}
				}
	}); 
	
	return userData; 
}

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

async function getHealthFactor(user, tranche) {
	const accountData = await lendingPool.methods.getUserAccountData(user, tranche, false).call(); 
	const healthFactor = accountData[5]; 
	return healthFactor; 
}
