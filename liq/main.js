const liq = require("./liq.js"); 
const data = require("./periphery/dataGetter.js"); 



async function run() {
	//initialize tranches with subgraph data
	let tranches = await data.initializeTranchesArray(); 
	
	//watch for borrow events
	await data.getBorrowEvents(); 	
	
	//check for liquidatable loans, liquidate if able to do so
	setInterval(await liq.main(), 10000); 
}

run(); 
