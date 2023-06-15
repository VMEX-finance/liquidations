//uniswap router is out of date/not working/a pain in the ass
//so we gonna roll our own
const uniswap = require("@uniswap/sdk"); 
const core = require("@uniswap/sdk-core"); 
const Web3 = require("web3"); 
const web3 = new Web3(process.env.OP_RPC); 


const factoryAddress = uniswap.FACTORY_ADDRESS;
const factoryAbi = require("./contracts/factory.json").abi; 


function getPair(

