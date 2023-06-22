//we know that both individual pieces work, now let's put them together 
const liq = require('../liq.js');  
const axios = require('axios'); 
const Web3 = require('web3'); 
const web3 = new Web3('ws://127.0.0.1:8545'); 
const testAbi = require('../contracts/FlashLoanLiquidation.json').abi; 

const wethAbi = require('../contracts/wethAbi.json'); 
const wethAddress = "0x4200000000000000000000000000000000000006"; 

const flashloanLiqAddress = "0x4826533B4897376654Bb4d4AD88B7faFD0C98528"; 

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


async function test() {

	const params = await liq.buildRoute(); 
	const collat = params.tokenIn; 
	const debt = params.tokenOut; 
	const amount = params.amountIn;
	const tranche = 0;
	
	console.log(params); 
	
	//unwrap some weth	
	let balance = await weth.methods.balanceOf(user).call(); 
	if (balance == 0) {
		await weth.methods.deposit().send({from: user, value: "1000000000000000000"});	
	}

	await weth.methods.transfer(flashloanLiqAddress, "1000000000000000000").send({from: user}); 
	let balanceContract = await weth.methods.balanceOf(flashloanLiqAddress).call(); 
	console.log(balanceContract); 
	
	const swapData = {
		to: debt,
		from: collat,
		amount: amount.toString(),
		minOut: 0,
		path: params.path
	};

	const ibPath = {
		tokenIn: debt,
		fee: 500,
		isIBToken: false,
		protocol: 3
	}

	const test = await testContract.methods.flashLoanCall(
		collat.toString(), 
		debt.toString(),
		amount.toString(),
		tranche,
		user.toString(),
		swapData,
		ibPath	
		).send({from: user, gas: 690000}).then((res) => {
			console.log(res); 
		}); 

}

test(); 


