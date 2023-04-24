const Web3 = require("web3"); 
require('dotenv').config(); 
const axios = require('axios'); 
const web3 = new Web3(process.env.GOERLI_RPC); 


const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.11"; 
const mel0n = "0xbf43260bb34daf3ba6f1fd8c3be31c3bb48bdf49";  
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
//TODO: figure out what happens when a user has more than one asset as collateral or borrowed, which do we submit for liquidation?
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
								name: borrowReserve.reserve.name
							}
							userData.tranches[k].borrows.push(borrowData); 
						}
					}
				}

				availableUsers.push(userData); 
			}
		}
		console.log(availableUsers); 
		return availableUsers; 
		
	}); 
}

getTrancheDatas(); 

//TODO
//if done off chain, calculation will probably be faster -- check using aave 
async function getHealthFactor(user_address) {
	//given a user's address, get the health factor from the lending pool contract using a web3 call	
	const healthFactor = await lendingPool.methods.getUserAccountData(user_address, 0, false).call(); 
	//console.log(healthFactor[5]); 
	return healthFactor[5]; 
}


