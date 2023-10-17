const liq = require('../liq.js');  
const { mainTest } = require('../liq.js'); 
const axios = require('axios'); 
const Web3 = require('web3'); 
const web3 = new Web3('http://127.0.0.1:8545');
const { expect } = require('chai'); 
const testAbi = require('../../contracts/out/FlashLoanLiquidationV3.sol/FlashLoanLiquidation.json').abi; 
const wethAbi = require('../contracts/wethAbi.json'); 
const wethAddress = "0x4200000000000000000000000000000000000006"; 
const daiAddress = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"; 
const erc20Abi = require("../contracts/erc20Abi.json"); 

const lendingPoolAbi = require("../contracts/lendingPoolAbi.json"); 
const lendingPoolAddress = "0x60F015F66F3647168831d31C7048ca95bb4FeaF9"; 

const assetMappingsAbi = require("../contracts/assetMappingsAbi.json"); 
const assetMappingsAddress = "0x48CB441A85d6EA9798C72c4a1829658D786F3027"; 

const flashloanLiqAddress = "0xDd1Ad10e289B70a48B4dD533906d904f4Ee2Cb4A"; 
const flashloanLiqAbi = require('../../contracts/out/FlashLoanLiquidationV3.sol/FlashLoanLiquidation.json').abi; 

const peripheralLogicAddress = "0xD57b88152f8f3506040d2f38c77982b47bB147A5"; 
const pLogicAbi = require('../../contracts/out/PeripheralLogic.sol/PeripheralLogic.json').abi;

const swapRouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564"; 
const swapRouterAbi = require('../contracts/swapRouter.json'); 

const user = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"; 
const prvKey = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"; 

const usdcAddress = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607"; 

const msigAddress = "0x599e1DE505CfD6f10F64DD7268D856831f61627a"; //global admin

const lendingPool = new web3.eth.Contract(lendingPoolAbi, lendingPoolAddress); 
const assetMappings = new web3.eth.Contract(assetMappingsAbi, assetMappingsAddress); 

const flashloanLiq = new web3.eth.Contract(
	flashloanLiqAbi,
	flashloanLiqAddress
); 

const weth = new web3.eth.Contract(
	wethAbi,
	wethAddress
); 

const usdc = new web3.eth.Contract(
	erc20Abi,
	usdcAddress
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

//describe("full liquidation route", async function () {
//	before(async function () {
//		await testContract.methods.init(peripheralLogicAddress).send({from: user, gas: 690000}); 
//		await weth.methods.deposit().send({from: user, value: "1000000000000000000"});	
//		await weth.methods.transfer(flashloanLiqAddress, "1000000000000000000").send({from: user}); 
//	});
//
//	it("should have access to web3", async function () {
//		const router = await pLogic.methods.swapRouter().call(); 
//		expect(router).to.be.equal("0xE592427A0AEce92De3Edee1F18E0157C05861564"); 
//	}); 
//
//	it("should get params back from liq.js", async function () {
//		const params = await liq.mainTest(wethAddress, wethAddress, amount); 	
//		expect(params).to.haveOwnProperty("collateralAsset"); 
//		expect(params).to.haveOwnProperty("debtAsset"); 
//
//	});
//
//	it("should pass in said params to liquidation contract", async function () {
//		this.timeout(5000); 
//		const params = await liq.mainTest(wethAddress, wethAddress, amount); 	
//		const test = await testContract.methods.flashLoanCall(params).send({from: user, gas: 6900000}); 
//	}); 
//
//}); 
//
//
//describe("should test various paths", async function () {
//	before(async function () {
//		await testContract.methods.init(peripheralLogicAddress).send({from: user, gas: 690000}); 
//		await weth.methods.deposit().send({from: user, value: "2000000000000000000"});	
//		await weth.methods.transfer(flashloanLiqAddress, "1000000000000000000").send({from: user}); 
//	});
//
//	//weth to crv
//	it("should single hop swap", async function () {
//		this.timeout(5000); 
//		const opToken = "0x4200000000000000000000000000000000000042"; 
//		const params = await liq.mainTest(opToken, wethAddress, amount); 
//		
//		//borrow token -> debt token 
//		expect(params.collateralAsset).to.be.equal(opToken); 
//		expect(params.debtAsset).to.be.equal(wethAddress); 
//		expect(params.debtAmount).to.be.equal(amount); 
//		expect(params.swapBeforeFlashloan.to).to.be.equal(wethAddress); 
//		expect(params.swapAfterFlashloan.to).to.be.equal(wethAddress); 
//	}); 
//
//	it("should multi hop swap", async function () {
//		this.timeout(5000); 
//		const opToken = "0x4200000000000000000000000000000000000042"; 
//		const params = await liq.mainTest(opToken, wethAddress, amount); 
//		
//		//debt token (weth) -> liquidated for op -> swapped back for weth
//		//TODO: fix failing test -- contract has no OP to swap back for weth
//		expect(params.collateralAsset).to.be.equal(opToken); 
//		expect(params.debtAsset).to.be.equal(wethAddress); 
//		expect(params.debtAmount).to.be.equal(amount); 
//		expect(params.swapBeforeFlashloan.to).to.be.equal(wethAddress); 
//		expect(params.swapAfterFlashloan.to).to.be.equal(wethAddress); 
//
//		//await testContract.methods.flashLoanCall(params).send({from: user, gas: 690000});
//	}); 
//
//	it("should work for ib tokens", async function () {
//		this.timeout(5000); 
//		const crvWstEth = "0x0892a178c363b4739e5Ac89E9155B9c30214C0c0";
//		const params = await liq.mainTest(crvWstEth, wethAddress, amount);  
//		
//		console.log(params); 
//	}); 
//
//}); 


//simulating how the contract would be called via the script on the server
//currently only swaps with NO PATH are working due to not simulating "liquidation funds"
//TODO: TEST VARIOUS TYPES OF COLLATERAL AND AMOUNTS
async function test(testCollateral, testDebt, testAmount) {
	//SETUP	
	//nuke collateral and force hf < 1 
//	let account = "0x042409674e96B513Dc0178f5B8469aC0EaAf59B3"
//	await web3.eth.sendTransaction({to: msigAddress, from: account, value: web3.utils.toWei('10', 'ether')});
//	//impersonate msig
//	await assetMappings.methods.configureAssetMapping(
//  wethAddress, //asset                                                                  
//  800000000000000000n, //baseLTV                                                  
//  825000000000000000n, //liqThreshold                                             
//  1050000000000000000n, //liqBonus                                                
//  35000000000000000000000n, //supplyCap                                           
//  19000000000000000000000n, //borrowCap                                           
//  2000000000000000000n //borrowFactor                                             
//).send({from: msigAddress, gas: 900000});  
//
//	console.log("assetMappings changed"); 
//
//	const mapping = await assetMappings.methods.getAssetMapping(wethAddress).call(); 
//	console.log(mapping); 
//
//	//deposit to add liquidity
//	//have to get WETH, then have to APPROVE
//	await weth.methods.deposit().send({from: account, value: amount, gas: 900000}); 
//	await weth.methods.approve(lendingPoolAddress, amount).send({from: account, gas: 90000}); 
//	await lendingPool.methods.deposit(wethAddress, 0, amount, account, 0).send({from: account, gas: 900000}); 
//	console.log("deposited!"); 

	const params = await liq.mainTest(testCollateral, testDebt, testAmount); 
	console.log(params); 
		
	//const test = await flashloanLiq.methods.flashLoanCall(params).send({from: account, gas: 900000}); 
	
	console.log("liquidation complete"); 
}

test(usdcAddress, wethAddress, String(0.03 * 1e18)); 

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

//testSwap(daiAddress, 500, amount); 

