# VMEX Liquidation Docs

### What is VMEX?
VMEX is a decentralized lending protocol forked from AAVE v2 with two main distinctions. The first, is that the protocol is tranched, meaning that each basket of assets in a tranche is isolated from every other tranche. You can think of each tranche like it's own deployed version of AAVE. The second, is that VMEX allows for interest bearing tokens (IB tokens), like LP and vault tokens, to be deposited into the protocol and used as collateral.

This is important to note for liquidations because if you liquidate a loan that has an IB token as collateral, you will need to take additional steps to unwrap it if necessary, for example, if you use a flashloan to liquidate the loan. 


### What other differences are there between liquidating here and liquidating on AAVE?
Mostly the tranches. Each user has a health factor specific to each tranche. They can have a healthy loan in Tranche 1, but be underwater in Tranche 2. It's imporant to pass in the right tranche to the lending pool when performing liquidations.  


### Where do I get data?
It is recommended that you use a web3 library to listen to the events emitted by  `LendingPool.sol`, namely `Borrow`, `Deposit`, and `Withdraw`. However, VMEX also has a subgraph from which you can query information about the tranches from as well.  


### Do you have examples? 
The VMEX team has created a basic liquidation bot that utilizes flashloans from AAVEV3 to liquidate loans for users that are underwater. It can be viewed [here]. <-- link this later

Please bear in mind that this was developed as a temporary measure on our part, and is not meant to be used long term. You are encouraged to improve it or create your own using it as a guide.



