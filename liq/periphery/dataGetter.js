const Web3 = require('web3'); 
const axios = require('axios'); 
const web3 = new Web3(process.env.OP_RPC); //TODO: set to wss 
const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.11"; 
const lending_pool_address = "0xdff58B48df141BCb86Ba6d06EEaABF02Ef45C528"; //GOERLI TODO: replace with mainnet address
const lending_pool_abi = require('./contracts/lendingPoolAbi.json').abi; 
const lendingPool = new web3.eth.Contract(
	lending_pool_abi,
	lending_pool_address
); 

//loans will wrap around all loans and be made up of users array
//users houses each loan for each user
//however, users can have multiple loans across multiple tranches, so we need a way to support that
let loans = []; 
let user = {}; 
let userLoanData = []; 


//loans [
//userId {
//	userData loan 1 {
// },
// userData loan 2 {
// }, 
// userData loan 3 {
// }
//}
//]
//
//
//
//minimally, we need the user address and the tranche only, from there we can check the health factor
//we need a way to store the user addresses tho



const Type = {
	DEPOSIT: 0,
	BORROW: 1,
	WITHDRAW: 2
};

async function subscribe() {
	//subscribe to deposit, borrow and withdraw events latest block only


	lendingPool.events.Deposit({fromBlock: "latest"},
		(event) => {
			filterEvents(event, Type.DEPOSIT); 	
	}); 

	lendingPool.events.Borrow({fromBlock: "latest"},
		(events) => {
			filterEvents(event, Type.BOROW); 
	}); 

	lendingPool.events.Withdraw({fromBlock: "latest"},
		(event) => {
			filterEvents(event, Type.WITHDRAW); 
	}); 
}

//TODO: handle multiple deposits and borrows
function filterEvents(eventData, type) {
	//collateralAsset
	//debtAsset
	//debtAmount
	//tracheId
	//user
	if (type == DEPOSIT) {
		let userDepositData = {
			id: eventDatas.returnValues.user,
			collateralAsset: eventData.returnValues.reserve,
			tranche: eventData.returnValues.trancheId,
			collateralAmount: eventData.returnValues.amount
		};
		
		loans.push(userDepositData); 

	}

	if (type == BORROW) {
		let userId = eventData.returnValues.user; 
		const i = loans.findIndex(loan => loan.id == userId); 
		let userData = loans[i]; 
		userData.debtAsset = eventData.returnValues.reserve; 
		userData.debtAmount = eventData.returnValues.amount; 
	}
	
	//we need to loop through the loans, find the user, and determine if this withdraw is all of his collateral 
	if (type == WITHDRAW) {
		let userId = eventData.returnValues.user; 
		const i = loans.findIndex(loan => loan.id == userId); 
		let userData = loans[i]; 
		
		
		
	}
}

//instead of looping through every user, we should probably just get active borrows
async function getLiquidatableAccounts() {
	let liquidatable = []; 
	const users = await getTrancheDatas(); 
	for (let i = 0; i < users.length; i++) {
		const user = users[i]; 
		for	(let j = 0; j < user.tranches.length; j++) {
			const tranche = user.tranches[j]; 
			const healthFactor = await getHealthFactor(user.id, tranche.id); 
			if (healthFactor < 2e18) {
				const liquidationData = {
					user: user.id,
					tranche: tranche.id,
					collateralAsset: tranche.collat,
					debtAsset: tranche.debt,
					debtAmount: tranche.amount
				}

				liquidatable.push(liquidationData); 
			}
		}	
	}

	return liquidatable; 
}

module.exports = { getLiquidatableAccounts }; 

async function getTrancheDatas() {
	let availableUsers = []; 

	await axios.post(api_url, { 
		query: `{
		  users(where: {borrowedReservesCount_gt: 0}) {
			id
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
		
		let userData = {}; 
		const data = res.data.data; 
		const users = data.users; 

		for (let i = 0; i < users.length; i++) {
			userData = {
				id: "",
			}
			userData.tranches = []; 

			userData.id = users[i].id; 
			for (let j = 0; j < users[i].borrowReserve.length; j++) {
				let tranche = {
					id: users[i].borrowReserve[j].reserve.tranche.id,
					debt: users[i].borrowReserve[j].reserve.assetData.id,
					amount: users[i].borrowReserve[j].currentTotalDebt
				}	
				userData.tranches.push(tranche); 
			}
				

			//check if the collateral tranche id matches witht the borrow one
			//if it does, put the relevant data
			//if it doesn't, discard it
			for (let j = 0; j < users[i].collateralReserve.length; j++) {
				for (let k = 0; k < userData.tranches.length; k++) {
					if (userData.tranches[k].id == users[i].collateralReserve[j].reserve.tranche.id) {
						userData.tranches[k].collat = 
							users[i].collateralReserve[j].reserve.assetData.id; 
						}
					}
				}

			availableUsers.push(userData); 
		}
		
	}); 

	return availableUsers; 
}

//getTrancheDatas(); 

//this is returning max hf for accounts that have active borrows?
async function getHealthFactor(user, tranche) {
	//given a user's address, get the health factor from the lending pool contract using a web3 call	
	const accountData = await lendingPool.methods.getUserAccountData(user, tranche, false).call(); 
	const healthFactor = accountData[5]; 
	return healthFactor; 
}
