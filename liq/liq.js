const Web3 = require("web3"); 
require('dotenv').config(); 
const axios = require('axios'); 
const web3 = new Web3(process.env.OP_RPC); 
const ethers = require("ethers"); //@5.7.2
const { AlphaRouter, SwapType } = require("@uniswap/smart-order-router"); 
const uniswap = require("@uniswap/sdk-core"); 
const ibTokens = require("./ibTokenList.js"); 

const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.11"; 
const provider = new ethers.providers.InfuraProvider('optimism'); 
const lending_pool_address = "0xdff58B48df141BCb86Ba6d06EEaABF02Ef45C528"; 
const lending_pool_abi = require('./contracts/lendingPoolAbi.json').abi; 
const erc20Abi = require("./contracts/erc20Abi.json"); 

const lendingPool = new web3.eth.Contract(
	lending_pool_abi,
	lending_pool_address
); 

const genericUniPoolAbi = require("./contracts/poolAbi.json"); 

		//needed: 
			//collateralAsset;  //aToken >> get
			//debtAsset; //currentBorrows >> get? kinda
			//trancheId; >> get
			//user; //already have >> get
			//debtAmount; //currentVariableDebt >> get? 

const router = new AlphaRouter({
	chainId: 10,
	provider: provider
}); 

//main entry
//currently, we take out a flashloan in debt asset, regardless of whether or not it is actually flashloanable on AAVE
//TODO: finish checkIfDirectFlashloanExists()
async function main() {
	const liquidatable = await getLiquidatableAccounts(); 	
	console.log(liquidatable); 
	for (let i = 0; i < liquidatable.length; i ++) {
		let liqParams = {
			collateralAsset: liquidatable[i].collateralAsset,
			debtAsset: liquidatable[i].debtAsset,
			trancheId: liquidatable[i].tranche,
			user: liquidatable[i].user,
			debtAmount: liquidatable[i].debtAmount
		}; 
		const swapData = buildRoute(liqParams); 
		liqParams.swapData = swapData; 	
		liqParams.ibPath = buildIBPath(liq_params.collateralAsset); 
	}
}

//main(); 

function checkIfDirectFlashloanExists(inputToken) {
	//lookup the list of available aave flashloans (off-chain)	
	//get back relevant data
}

async function buildRoute() {		
	const options = {
		recipient: "0xbF43260Bb34daF3BA6F1fD8C3BE31c3Bb48Bdf49",
		slippageTolerance: new uniswap.Percent(100, 10_000),
		deadline: Math.floor(Date.now() / 1000 + 1800),
		type: SwapType.SWAP_ROUTER_02
	}
	
	//TODO: remove test tokens (after live)
	const tokenIn = await getToken("0x4200000000000000000000000000000000000006");  //WETH
	const tokenOut = await getToken("0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"); //DAI
	const wei = 1e18;
	const amount = wei.toString(); 
	
	//swapping from flashloaned asset to debtAsset, if they are the same, we just return the same two tokens set as a route and decode in contract
	//route used to swap 
	const route = await router.route(
		uniswap.CurrencyAmount.fromRawAmount(tokenIn, amount),
		tokenOut,
		uniswap.TradeType.EXACT_INPUT,
		options
	); 
	const params = await buildParams(route.route, tokenIn.decimals, tokenOut.decimals); 
	console.log(params); 
	return params; 
}

buildRoute(); 

module.exports = { buildRoute }; 

//NOTE: if there is only a single hop, we want the path array to be a length of 1
async function buildParams(route, decimalsIn, decimalsOut) {
	//receives the route and returns an object that is specific for liquidation contract
	//params needed:
	//	- amountIn
	//	- tokenIn
	//	- tokenOut
	//	- fee
	//	- minOut
	//	- path
	const amountIn = route[0].amount.toSignificant(decimalsIn) * (10 ** decimalsIn); 
	const tokenIn = route[0].route.input.address;
	const tokenOut = route[0].route.output.address;
	const minOut = route[0].quoteAdjustedForGas.toSignificant(decimalsOut) * (10 ** decimalsOut);   
	const pools = route[0].poolAddresses; 
	const fees = await getFeesFromPoolAddress(pools); 

	//console.log(route[0].tokenPath[0]); 

	const params = {
		tokenIn: tokenIn,
		tokenOut: tokenOut,
		amountIn: amountIn,
		minOut: minOut,
		path: []
	}
	//if there is more than one token in the path, we need to get the fee for the associated pool
	if (pools.length >= 2) {
		for (let i = 0; i < pools.length; i++) {
			let path = {
				tokenIn: route[0].tokenPath[i],
				fee: fees[i],
				isIBToken: false, //always false here
				protocol: 3 //none
			};
			params.path.push(path); 
		}
	} else {
		params.path[0].tokenIn = tokenIn; 
		params.path[0].fee = fees[0];
		params.path[0].isIBToken = false; //always false here
		params.path[0].protocol = 3; //none
	}
	
	return params; 
}

async function buildIBPath(token) {
	const ibTokenList = ibTokens.ibTokens; 	
	let path = {}; 
	if (ibTokenList[token.toString()] != undefined) {
		path.tokenIn = token; 
		path.fee = 0; 
		path.isIBToken = true;
		path.protocol = ibTokenList[token.toString()]; 
	} else {
		//ignored by flashloan
		path.tokenIn = token; 
		path.fee = 0; 
		path.isIBToken = false;
		path.protocol = 3; //none 
	}
	
	return path; 
}

//buildIBPath("0x0892a178c363b4739e5Ac89E9155B9c30214C0c0"); 

async function getFeesFromPoolAddress(pools) {
	const poolLength = pools.length; 
	const fees = []; 
	for (let i = 0; i < poolLength; i++) {
		const poolContract = new web3.eth.Contract(
			genericUniPoolAbi,
			pools[i]
		);

		const fee = await poolContract.methods.fee().call(); 
		fees.push(fee); 
	}	

	return fees; 
}


async function getToken(tokenIn) {
	//token address
	//token decimals
	//token symbol
	//token name
	const tokenContract = new web3.eth.Contract(
		erc20Abi,
		tokenIn
	); 

	const decimals = await tokenContract.methods.decimals().call(); 
	const symbol = await tokenContract.methods.symbol().call(); 
	const name = await tokenContract.methods.name().call(); 

	const token = new uniswap.Token(10, tokenIn, Number(decimals), symbol, name); 
	return token;

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

//getLiquidatableAccounts(); 

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
							userData.tranches[k].collat = users[i].collateralReserve[j].reserve.assetData.id; 
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


