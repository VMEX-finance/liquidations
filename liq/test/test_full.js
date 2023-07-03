const liq = require('../liq.js');  
const { mainTest } = require('../liq.js'); 
const axios = require('axios'); const Web3 = require('web3'); 
const web3 = new Web3('ws://127.0.0.1:8545'); 
//const chai = require('chai'); 
const testAbi = require('../../contracts/out/FlashLoanLiquidationV3.sol/FlashLoanLiquidation.json').abi; 

const wethAbi = require('../contracts/wethAbi.json'); 
const wethAddress = "0x4200000000000000000000000000000000000006"; 
const daiAddress = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"; 
const erc20Abi = require("../contracts/erc20Abi.json"); 

const flashloanLiqAddress = "0x1275D096B9DBf2347bD2a131Fb6BDaB0B4882487"; 
const peripheralLogicAddress = "0x05Aa229Aec102f78CE0E852A812a388F076Aa555"; 
const pLogicAbi = require('../../contracts/out/PeripheralLogic.sol/PeripheralLogic.json').abi;
const swapRouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564"; 
const swapRouterAbi = require('../contracts/swapRouter.json'); 

const user = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"; 
const prvKey = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"; 

const testContract = new web3.eth.Contract(
	testAbi,
	flashloanLiqAddress
); 

const weth = new web3.eth.Contract(
	wethAbi,
	wethAddress
); 

const dai = new web3.eth.Contract(		
	erc20Abi,
	daiAddress
); 

const pLogic = new web3.eth.Contract(
	pLogicAbi,
	peripheralLogicAddress
); 

const swapRouter = new web3.eth.Contract(
	swapRouterAbi,
	swapRouterAddress
); 

const amount = (1e18).toString(); 

//simulating how the contract would be called via the script on the server
//currently only swaps with NO PATH are working due to not simulating "liquidation funds"
async function test() {
	//SETUP	
	await testContract.methods.init(peripheralLogicAddress).send({from: user}); 

	const params = await liq.mainTest(wethAddress, wethAddress, amount); 
	console.log(params); 
	
	////unwrap some weth	
	let balance = await weth.methods.balanceOf(flashloanLiqAddress).call(); 
	if (balance === 0) {
		await weth.methods.deposit().send({from: user, value: "1000000000000000000"});	
		await weth.methods.transfer(flashloanLiqAddress, "1000000000000000000").send({from: user}); 
	}

	let balanceContract = await weth.methods.balanceOf(flashloanLiqAddress).call(); 
	console.log(balanceContract); 	

	const test = await testContract.methods.flashLoanCall(params).send({from: user, gas: 6900000}); 

}

async function testSwap(outToken, fee, amount) {
	const deadline = Math.floor(Date.now() / 1000 + 1800)

	await weth.methods.deposit().send({from: user, value: "1000000000000000000"});	

	await weth.methods.approve(swapRouterAddress, amount).send({from: user}); 
	const params = {
		tokenIn: wethAddress,
		tokenOut: outToken,
		fee: fee,
		recipient: user,
		deadline: deadline,
		amountIn: amount,
		amountOutMinimum: 0,
		sqrtPriceLimitX96: 0
	};

	swapRouter.methods.exactInputSingle(params).send({from: user, gas: 6900000}); 
	console.log("swap complete");
}

//test(); 
testSwap(daiAddress, 500, amount); 

