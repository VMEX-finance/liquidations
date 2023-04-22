const Web3 = require("web3"); 
require('dotenv').config(); 
const axios = require('axios'); 
const web3 = new Web3(process.env.GOERLI_RPC); 


const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.9"; 
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

main(); 

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

async function getLiquidationParams(user_address) {
	let supplied_assets = []; 
	let borrowed_assets = []; 
	await axios.post(api_url, { 
		query: `{
				  user(id: "${user_address}") {
					reserves {
						currentVariableDebt 
						reserve {
							aToken {
								underlyingAssetAddress 
							}
							tranche {
								id
							}
						}
					}
				  }
				}
`
	}).then((res) => {
		const reserves = res.data.data.user.reserves; 
		for (let i = 0; i < reserves.length; i++) {
			if (reserves[i].currentVariableDebt == 0) {
				supplied_assets.push(reserves[i]); 
			} else {
				borrowed_assets.push(reserves[i]); 
			}
		}
	}); 
	return [supplied_assets, borrowed_assets]; 
}

//getLiquidationParams(mel0n); 

async function getUsers() {
	let users = []; 
	await axios.post(api_url, { 
		query: `{
				  users {
				    id
				  }
				}
`
	}).then((res) => {
		const data = res.data.data.users; 
		for(let i = 0; i < data.length; i ++) {
			let user = data[i].id; 
			users.push(user); 	
		}
	}); 
	return users; 
}

//TODO
//if done off chain, calculation will probably be faster -- check using aave 
async function getHealthFactor(user_address) {
	//given a user's address, get the health factor from the lending pool contract using a web3 call	
	const healthFactor = await lendingPool.methods.getUserAccountData(user_address, 0, false).call(); 
	//console.log(healthFactor[5]); 
	return healthFactor[5]; 
}


