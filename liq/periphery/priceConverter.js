const Web3 = require('web3'); 
const web3 = new Web3("https://optimism-mainnet.infura.io/v3/1cad81887e224784a4d2ad2db5c0587a"); 


const uniswapFactoryAbi = require('../contracts/factoryAbi.json'); 
const uniswapFactoryAddress = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; 
const factory = new web3.eth.Contract(
	uniswapFactoryAbi,
	uniswapFactoryAddress
);

const quoterAbi = require('../contracts/quoterAbi.json'); const quoterAddress = "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6"; 
const quoter = new web3.eth.Contract(
	quoterAbi,
	quoterAddress
); 
const fees = [500, 3000, 10000]; 
const WETH = "0x4200000000000000000000000000000000000006"; 

//converts a given amount of inputToken to price in WETH
//easiest way would be to get the price of somehting in WETH via a uniswapv3 pool
async function getPriceInWETH(inputToken, amount) {
	const feeIndex = await getPool(inputToken); 
	const fee = fees[feeIndex]; 
	amount = amount.toString(); 
	const out = await quoter.methods.quoteExactInputSingle(inputToken, WETH, fee, amount, 0).call(); 
	const final = Number(out) + (Number(out) * 0.05); 
	console.log(final); 
	return final; 
}

//checkPriceInWETH("0x9Bcef72be871e61ED4fBbc7630889beE758eb81D"); 

module.exports = { getPriceInWETH }; 

async function getPool(inputToken) {
	for (let i = 0; i < fees.length; i++) {	
		const pool = await factory.methods.getPool(inputToken, WETH, fees[i]).call(); 
		if (pool != "0x0000000000000000000000000000000000000000") {
			console.log(pool); 
			return i; 
		} else {
			throw("no weth pools exist"); 
		}
	}
}


//getPool("0x9e1028F5F1D5eDE59748FFceE5532509976840E0"); 

