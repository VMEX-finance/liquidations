const Web3 = require('web3'); 
require('dotenv').config(); 
const axios = require('axios'); 
const web3 = new Web3(process.env.OP_RPC); 
const ethers = require('ethers'); //@5.7.2
const { AlphaRouter, SwapType } = require('@uniswap/smart-order-router'); 
const uniswap = require('@uniswap/sdk-core'); 
const constants = require('./periphery/constants.js'); 
const converter = require('./periphery/priceConverter.js'); 
const testData = require('./test/mock_liquidation_data.js'); 

const api_url = "https://api.studio.thegraph.com/query/40387/vmex-finance-goerli/v0.0.11"; 
const provider = new ethers.providers.InfuraProvider('optimism'); 
const lending_pool_address = "0xdff58B48df141BCb86Ba6d06EEaABF02Ef45C528"; //GOERLI TODO: replace with mainnet address
const lending_pool_abi = require('./contracts/lendingPoolAbi.json').abi; 
const flashloanLiquidationAbi = require('./contracts/FlashLoanLiquidation.json'); 
const flashloanLiquidationAddress = ""; //TODO: add mainnet address to call flashloan function

const erc20Abi = require("./contracts/erc20Abi.json"); 

const lendingPool = new web3.eth.Contract(
	lending_pool_abi,
	lending_pool_address
); 

//const flashloanLiquidation = new web3.eth.Contract(
//	flashloanLiquidationAbi,
//	flashloanLiquidationAddress
//);

const genericUniPoolAbi = require("./contracts/poolAbi.json"); 

const router = new AlphaRouter({
	chainId: 10,
	provider: provider
}); 

//main entry
//TODO: refactor:: move peripheral and helper functions to another file
async function main() {
	const liquidatable = await getLiquidatableAccounts(); 	
	for (let i = 0; i < liquidatable.length; i ++) {
		let liqParams = {
			collateralAsset: liquidatable[i].collateralAsset,
			debtAsset: liquidatable[i].debtAsset,
			debtAmount: liquidatable[i].debtAmount,
			trancheId: liquidatable[i].tranche,
			user: liquidatable[i].user
		}; 

		const swapTo = liqParams.debtAsset; 

		//if this is false, we want the loan to be in WETH
		const exists = checkIfDirectFlashloanExists(liqParams.debtAsset.toString()); 
		if (exists == false) {
			liqParams.debtAsset = "0x4200000000000000000000000000000000000006"; //WETH
			//convert debtAmount to amount in WETH + 5%
			liqParams.debtAmount = converter.getPriceInWETH(swapTo, liqParams.debtAmount); 
		}
			
		//the debt asset above is the flashloan we're taking out, the swap data includes a path to swap back to the ACTUAL debt token
		//cases where debtAsset === swapTo are handled in the contract
		const swapBeforeFlashloan = buildRoute(liqParams.debtAsset, swapTo, liqParams.debtAmount); 
		const swapAfterFlashloan = buildRoute(liqParams.collateralAsset, liqParams.debtAsset, liqParams.debtAmount); //not sure if amount actually really matters? 
		liqParams.ibPath = buildIBPath(liq_params.collateralAsset); //if the collateral asset is a ib token, needed actions will be included here
		liqParams.swapBeforeFlashloan = swapBeforeFlashloan; 	
		liqParams.swapAfterFlashloan = swapAfterFlashloan; 

		await flashloanLiquidation.methods.flashLoanCall(
			liqParams.collateralAsset,
			liqParams.debtAsset,
			liqParams.debtAmount,
			liqParams.trancheId,
			liqParams.user,
			liqParams.swapBeforeFlashloan,
			liqParams.swapAfterFlashloan,
			liqParams.ibPath
		);
	}
}

//for testing the contract w/o data from subgraph
async function mainTest(collateralAsset, debtAsset, debtAmount) {
		//if this is false, we want the loan to be in WETH
		let liqParams = {
			collateralAsset: collateralAsset, 
			debtAsset: debtAsset,
			debtAmount: debtAmount,
			trancheId: 0,
			user: "0xbF43260Bb34daF3BA6F1fD8C3BE31c3Bb48Bdf49"
		}; 

		const swapTo = liqParams.debtAsset; 

		const exists = checkIfDirectFlashloanExists(liqParams.debtAsset.toString()); 
		if (exists == false) {
			liqParams.debtAsset = "0x4200000000000000000000000000000000000006"; //WETH
			//convert debtAmount to amount in WETH + 5%
			liqParams.debtAmount = converter.getPriceInWETH(swapTo, liqParams.debtAmount); 
		}

			
		//the debt asset above is the flashloan we're taking out, the swap data includes a path to swap back to the ACTUAL debt token
		//cases where debtAsset === swapTo are handled in the contract and ignored
		const swapBeforeFlashloan = await buildRoute(liqParams.debtAsset, swapTo, liqParams.debtAmount); 
		const swapAfterFlashloan = await buildRoute(liqParams.collateralAsset, liqParams.debtAsset, liqParams.debtAmount); //not sure if amount actually really matters? 
		liqParams.swapBeforeFlashloan = swapBeforeFlashloan; 	
		liqParams.swapAfterFlashloan = swapAfterFlashloan; 
		liqParams.ibPath = await buildIBPath(liqParams.collateralAsset); //if the collateral asset is a ib token, needed actions will be included here
		return liqParams; 
}

function checkIfDirectFlashloanExists(inputToken) {
	let exists = false; 
	for (let i = 0; i < constants.flashloanableTokens.length; i++) {
		if (constants.flashloanableTokens[i].toLowerCase() == inputToken.toLowerCase()) {	
			exists = true; 		
		}
	}
	return exists; 
}

//checkIfDirectFlashloanExists("0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb"); 

async function buildRoute(tokenIn, tokenOut, amount) {		
	//for slippage calc only  
	let params; 
	const options = {
		recipient: "0xbF43260Bb34daF3BA6F1fD8C3BE31c3Bb48Bdf49",
		slippageTolerance: new uniswap.Percent(3000, 10_000),
		deadline: Math.floor(Date.now() / 1000 + 1800),
		type: SwapType.SWAP_ROUTER_02
	}
	
	tokenIn = await getToken(tokenIn.toString());  //WETH
	tokenOut = await getToken(tokenOut.toString()); //DAI
	amount = amount.toString(); 
	
	//swapping from flashloaned asset to debtAsset, if they are the same, we just return the same two tokens set as a route and decode in contract
	//route used to swap 
	if (tokenIn.address.toLowerCase() != tokenOut.address.toLowerCase()) {
			const route = await router.route(
			uniswap.CurrencyAmount.fromRawAmount(tokenIn, amount),
			tokenOut,
			uniswap.TradeType.EXACT_INPUT,
			options
		); 
		params = await buildParams(route.route, tokenIn.decimals, tokenOut.decimals); 
	} else {
		params = await buildParams(undefined, tokenIn.decimals, tokenOut.decimals); 		
	}
	return params; 
}

//buildRoute(); 

module.exports = { mainTest, buildRoute }; 

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
	let params = {};

	if (route != undefined) {
		const amountIn = route[0].amount.toSignificant(decimalsIn) * (10 ** decimalsIn); 
		const tokenIn = route[0].route.input.address;
		const tokenOut = route[0].route.output.address;
		const minOut = route[0].quoteAdjustedForGas.toSignificant(decimalsOut) * (10 ** decimalsOut);   
		const pools = route[0].poolAddresses; 
		const fees = await getFeesFromPoolAddress(pools); 

		params = {
			to: tokenOut,
			from: tokenIn,
			amount: BigInt(amountIn),
			minOut: BigInt(minOut),
			path: []
		}
		//if there is more than one token in the path, we need to get the fee for the associated pool
		if (pools.length >= 2) {
			for (let i = 0; i < pools.length; i++) {
				let path = {
					tokenIn: route[0].tokenPath[i].address,
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
	} else {
		//if tokenIn and tokenOut are the same, params are ignored but we still need to return data
		params = {
			to: "0x0000000000000000000000000000000000000000",
			from: "0x0000000000000000000000000000000000000000",
			amount: "0",
			minOut: "0",
			path: []
		}
		const path0 = {
			tokenIn: "0x0000000000000000000000000000000000000000",
			fee: '500',
			isIBToken: false, //always false here
			protocol: 3 //none
		}; 

		params.path.push(path0); 
	}
	
	return params; 
}

async function buildIBPath(token) {
	const ibTokenList = constants.ibTokens; 
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
	const tokenContract = new web3.eth.Contract(
		erc20Abi,
		tokenIn
	); 

	const decimals = await tokenContract.methods.decimals().call(); 
	const symbol = await tokenContract.methods.symbol().call(); 
	const name = await tokenContract.methods.name().call(); 
	
	//chain, address, decimals, symbol, name
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


