const Web3 = require('web3'); 
require('dotenv').config(); 
const web3 = new Web3(process.env.OP_RPC); 
const ethers = require('ethers'); //@5.7.2
const { AlphaRouter, SwapType } = require('@uniswap/smart-order-router'); 
const uniswap = require('@uniswap/sdk-core'); 
const constants = require('./periphery/constants.js'); 
const converter = require('./periphery/priceConverter.js'); 
const dataGetter = require('./periphery/dataGetter.js'); 

const api_url = "https://api.thegraph.com/subgraphs/name/fico23/optimism-vmex"; 
const provider = new ethers.providers.InfuraProvider('optimism'); 
const lendingPoolAddress = "0x60F015F66F3647168831d31C7048ca95bb4FeaF9";
const lendingPoolAbi = require('./contracts/lendingPoolAbi.json'); 
const flashloanLiquidationAbi = require('../contracts/out/FlashLoanLiquidationV3.sol/FlashLoanLiquidation.json').abi; 
const flashloanLiquidationAddress = "0xDd1Ad10e289B70a48B4dD533906d904f4Ee2Cb4A";

const erc20Abi = require("./contracts/erc20Abi.json"); 

const lendingPool = new web3.eth.Contract(
	lendingPoolAbi,
	lendingPoolAddress
); 

const flashloanLiquidation = new web3.eth.Contract(
	flashloanLiquidationAbi,
	flashloanLiquidationAddress
);

const genericUniPoolAbi = require("./contracts/poolAbi.json"); 

const router = new AlphaRouter({
	chainId: 10,
	provider: provider
}); 

const WETH = "0x4200000000000000000000000000000000000006"; 

//main entry
async function main() {

	let liquidatable; 
	try {
		liquidatable = await dataGetter.getLiquidatableAccounts();
	} catch (getLiquidatableAccountsError) {
		console.log(getLiquidatableAccountsError);
		return getLiquidatableAccountsError;
	}


	if (liquidatable.length === 0) {
		console.log("No loans to liquidate"); 
		return; 
	} else {
		console.log(liquidatable);
	}
	
	let liqParams; 
	for (let i = 0; i < liquidatable.length; i ++) {
		let tempParams = await dataGetter.getTrancheDatasForUser(liquidatable[i].user);  
		liqParams = {
			collateralAsset: tempParams.tranches[0].collateralAsset,
			debtAsset: tempParams.tranches[0].debts[0],
			debtAmount: tempParams.tranches[0].amount,
			trancheId: tempParams.tranches[0].id,
			user: tempParams.id
		}; 

		const swapTo = liqParams.debtAsset; 

		//if this is false, we want the loan to be in WETH unless it's an ibToken
		const exists = checkIfDirectFlashloanExists(liqParams.debtAsset); 
		if (exists == false) {
			liqParams.debtAsset = WETH//WETH
			//convert debtAmount to amount in WETH + 5%
			liqParams.debtAmount = converter.getPriceInWETH(swapTo, liqParams.debtAmount); 
		}
			
	//the debt asset above is the flashloan we're taking out, the swap data includes a path to swap back to the ACTUAL debt token //also handles cases where swapTo and debtAsset are the same
		const swapBeforeFlashloan = await buildRoute(liqParams.debtAsset, swapTo, liqParams.debtAmount); 
		const swapAfterFlashloan = await buildRoute(liqParams.collateralAsset, liqParams.debtAsset, liqParams.debtAmount); //not sure if amount actually really matters? 
		liqParams.ibPath = await buildIBPath(liqParams.collateralAsset); //if the collateral asset is a ib token, needed actions will be included here
		liqParams.swapBeforeFlashloan = swapBeforeFlashloan; 	
		liqParams.swapAfterFlashloan = swapAfterFlashloan; 
		
		let txData = await flashloanLiquidation.methods.flashLoanCall(liqParams).encodeABI();
		
		let tx = {
			from: process.env.ETH_USER,
			to: flashloanLiquidationAddress,
			data: txData,
			gas: 100000
		};


		let sig = await web3.eth.accounts.signTransaction(tx, process.env.PRIVATE_KEY); 
		await web3.eth.sendSignedTransaction(sig.rawTransaction).on('receipt', (res) => {
			console.log(res); 
		}); 
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
		user: "0x4d180AF22cd72b8c6593656a0e123E0C4760e6ac"
	}; 

	const swapTo = liqParams.debtAsset; 

	const exists = checkIfDirectFlashloanExists(liqParams.debtAsset.toString()); 
	if (exists == false) {
		liqParams.debtAsset = WETH; //WETH
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
	
	//console.log(liqParams); 
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

function checkIfCollateralIsIBToken(inputToken) {
	let isIBToken = false; 
	if (constants.ibTokens.hasOwnProperty(inputToken)) {
		isIBToken = true; 		
	}
	return isIBToken; 
}

//checkIfCollateralIsIBToken("0xaD17A225074191d5c8a37B50FdA1AE278a2EE6A2"); 

async function buildRoute(tokenIn, tokenOut, amount) {		
	//for slippage calc only  
	let params; 
	const options = {
		recipient: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045", //vitalik.eth
		slippageTolerance: new uniswap.Percent(3000, 10_000),
		deadline: Math.floor(Date.now() / 1000 + 1800),
		type: SwapType.SWAP_ROUTER_02
	}

	const isIBToken = checkIfCollateralIsIBToken(tokenIn); 
	console.log(tokenIn); 

	tokenIn = await getToken(tokenIn.toString());
	tokenOut = await getToken(tokenOut.toString());
	amount = amount.toString(); 
	//swapping from flashloaned asset to debtAsset, if they are the same, we just return the same two tokens set as a route and decode in contract
	//route used to swap 
	if (tokenIn.address.toLowerCase() != tokenOut.address.toLowerCase() && isIBToken == false) {
			const route = await router.route(
			uniswap.CurrencyAmount.fromRawAmount(tokenIn, amount),
			tokenOut,
			uniswap.TradeType.EXACT_INPUT,
			options
		); 
		params = await buildParams(route.route, tokenIn.decimals, tokenOut.decimals, tokenIn.address); 
	} else {
		params = await buildParams(undefined, tokenIn.decimals, tokenOut.decimals, tokenIn.address); 		
	}
	return params; 
}

//buildRoute(); 

module.exports = { main, mainTest }; 

//NOTE: if there is only a single hop, we want the path array to be a length of 1
async function buildParams(route, decimalsIn, decimalsOut, tokenInAddress) {
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
					protocol: constants.Protocol.NONE //none
				};
				params.path.push(path); 
			}
		} else {
			const pathParams = {
				tokenIn: tokenIn,
				fee: fees[0],
				isIBToken: false, //always false here
				protocol: constants.Protocol.NONE
			};

			params.path.push(pathParams); 

		}
	} else {
		//if tokenIn and tokenOut are the same, params are ignored but we still need to return data
		params = {
			to: tokenInAddress,
			from: tokenInAddress,
			amount: 0,
			minOut: 0,
			path: []
		}
		const path0 = {
			tokenIn: tokenInAddress,
			fee: 0,
			isIBToken: false, //always false here
			protocol: constants.Protocol.NONE //none
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
		path.protocol = constants.Protocol.NONE; //none 
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



