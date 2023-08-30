const liq = require("./liq.js"); 
const data = require("./periphery/dataGetter.js"); 


async function run() {
	//initialize tranches with subgraph data
	let tranches = await data.initializeTranchesArray(); 

	//check for liquidatable loans, liquidate if able to do so

	//watch for borrow events
	await data.getBorrowEvents(); 	

	setInterval(async () => {
			console.log("Querying for loans..."); 
			try {
					await liq.main()
			} catch (err) {
				console.log(err);
			}
	}, 60000); 
	
}

run(); 

