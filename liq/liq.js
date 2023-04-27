const Web3 = require("web3"); 
require('dotenv').config(); 
const axios = require('axios'); 
const web3 = new Web3(process.env.GOERLI_RPC); 


const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.11"; 
const lending_pool_address = "0x9B0baDC6fb17802F8d32b183700C3B957273aeDb"; 
const lending_pool_abi = require('./contracts/lendingPoolAbi.json').abi; 

const lendingPool = new web3.eth.Contract(
	lending_pool_abi,
	lending_pool_address
); 

		//needed: 
			//collateralAsset;  //aToken >> get
			//debtAsset; //currentBorrows >> get? kinda
			//trancheId; >> get
			//user; //already have >> get
			//debtAmount; //currentVariableDebt >> get? 

//main entry
async function main() {
	let liq_params = {}; 
	const liquidatable = await getLiquidatableAccounts(); 	
	for (let i = 0; i < liquidatable.length; i ++) {
		const [supplies, borrows]  = await getLiquidationParams(liquidatable[i]); 
		liq_params = {
			collateralAsset: supplies[0].reserve.aToken.underlyingAssetAddress,
			debtAsset: borrows[0].reserve.aToken.underlyingAssetAddress,
			trancheId: supplies[0].reserve.tranche.id,
			user: liquidatable[i],
			debtAmount: borrows[0].currentVariableDebt
		}; 
		console.log(liq_params); 
	}
}

//main(); 

//instead of looping through every user, we should probably just get active borrows
async function getLiquidatableAccounts() {
	let liquidatable = []; 
	const users = await getUsers(); 
	for (let i = 0; i < users.length; i++) {
		const healthFactor = await getHealthFactor(users[i]); 
		//temp
		if (healthFactor < 1.1e18) {
			liquidatable.push(users[i]); 
		}
	}

	return liquidatable; 
}

//getLiquidatableAccounts(); 

async function getTrancheDatas() {
	await axios.post(api_url, { 
		query: `{
		  users {
			  id
 			  borrowedReservesCount
  			  collateralReserve: reserves(where:{currentATokenBalance_gt: 0}) {
  			    currentATokenBalance
  			    reserve {
  			      underlyingAsset
  			      name
				  assetData {
					liquidationThreshold
				  }
  			      tranche {
  			        id
  			        name
  			      }
  			    }
  			  }
  			  borrowReserve: reserves(where: {currentTotalDebt_gt: 0}) {
  			    currentTotalDebt
  			    reserve {
  			      underlyingAsset
  			      name
				  assetData {
					liquidationThreshold
				  }
  			      tranche {
  			        id
  			        name
  			      }
  			    }
  			  }
  			}
}
`
	}).then((res) => {
		
		let userData = {};
		let availableUsers = []; 

		const data = res.data.data; 
		const users = data.users; 
		
		//break down by user
		//user address holds individual tranche data
		//collateral[{
		//	totalCollater}]
		//borrows[{}]
		for (let i = 0; i < users.length; i++) {
			if (users[i].borrowedReservesCount != 0) {
					userData = {
						user: "",
						//tranche
							//collateral[]
							//borrows[]
						}
				const user = users[i]; 
				userData.user = user.id; 

				const collateralReserves = user.collateralReserve; 
				const borrowReserves = user.borrowReserve; 
				userData.tranches = []; 

				//on per-tranche basis
				for (let j = 0; j < collateralReserves.length; j++) {
					const collateralReserve = collateralReserves[j]; 
					let trancheData = {
						id: collateralReserve.reserve.tranche.id,
						name: collateralReserve.reserve.tranche.name,
						totalCollateral: collateralReserve.currentATokenBalance
					}

					userData.tranches.push(trancheData); 
					userData.tranches[j].collateral = []; 
					let collateralData = {
						token: collateralReserve.reserve.underlyingAsset,
						name: collateralReserve.reserve.name,
					}

					userData.tranches[j].collateral.push(collateralData); 
				}

				//on per-tranche basis
				for (let j = 0; j < borrowReserves.length; j++) {
					const borrowReserve = borrowReserves[j]; 
					for (let k = 0; k < userData.tranches.length; k++) {
						if (userData.tranches[k].id == borrowReserve.reserve.tranche.id) {
								userData.tranches[k].totalDebt = borrowReserve.currentTotalDebt; 	
								userData.tranches[k].borrows = []; 
								let borrowData = {
									token: borrowReserve.reserve.underlyingAsset,
									name: borrowReserve.reserve.name,
									liquidationThreshold: borrowReserve.reserve.assetData.liquidationThreshold
								}
								userData.tranches[k].borrows.push(borrowData); 
							}
						}
					}

				availableUsers.push(userData); 
			}
		}

		//TODO: add all users and tranches together
		for (let i = 0; i < availableUsers.length; i++) {
			const user = availableUsers[i]; 
			for (let j = 0; j < user.tranches.length; j++) {
				if (user.tranches[j].hasOwnProperty("borrows")) {
					console.log("no borrows"); 
				} else {
					console.log("no borrows"); 
				}	
			}
		}

		return availableUsers; 
		
	}); 
}

getTrancheDatas(); 

async function getHealthFactor(users) {
	//given a user's address, get the health factor from the lending pool contract using a web3 call	
	for (let i = 0; i < users.length; i++) {
		const user = users[i];
		for (let j = 0; j < user.tranches.length; j++) {
			const tranche = user.tranche[j]; 
			//if (tranche.borrows 
		}
	}
}

function calculateHealthFactor(totalCollateral, liquidationThreshold, totalDebt) {
	//calcs totalCollat * liquidationThreshold / totalDebt	
	return (totalCollateral * liquidationThreshold) / totalDebt; 
}

function calculateLiquidationThreshold(loans) {
	//weighted average of collateral (priced in eth) * liquidationThreshold of the asset 
	var n = 0;   	
	while (n < loans.length) {
		n++; 
	}
}

//getHealthFactor("0x2ddc2e6ec28ada2e945f36abffdc25dc24d16390"); 


