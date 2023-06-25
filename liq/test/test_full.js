const liq = require('../liq.js');  
const { mainTest } = require('../liq.js'); 
const axios = require('axios'); 
const Web3 = require('web3'); 
const web3 = new Web3('ws://127.0.0.1:8545'); 
const testAbi = require('../../contracts/out/FlashLoanLiquidationV3.sol/FlashLoanLiquidation.json').abi; 

const wethAbi = require('../contracts/wethAbi.json'); 
const wethAddress = "0x4200000000000000000000000000000000000006"; 
const daiAddress = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"; 

const flashloanLiqAddress = "0x99bbA657f2BbC93c02D617f8bA121cB8Fc104Acf"; 

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

const amount = (1e18).toString(); 

async function test() {
	const params = await liq.mainTest(wethAddress, daiAddress, amount); 
	console.log(params); 
	
	////unwrap some weth	
	let balance = await weth.methods.balanceOf(user).call(); 
	if (balance == 0) {
		await weth.methods.deposit().send({from: user, value: "1000000000000000000"});	
	}

	await weth.methods.transfer(flashloanLiqAddress, "1000000000000000000").send({from: user}); 
	let balanceContract = await weth.methods.balanceOf(flashloanLiqAddress).call(); 
	console.log(balanceContract); 	

	const test = await testContract.methods.flashLoanCall(params).send({from: user, gas: 6900000}); 

}

test(); 
