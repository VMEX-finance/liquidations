# To Test
 
Launch a local fork of optimism using anvil 
``` anvil --fork-url $OP_RPC_URL 
```

Deploy the contracts using the deploy script 
```
	./test/deploy_contracts.sh
```

Run a basic test suite using 
```
	mocha
```
in the root directory.

Run the full test using 
```
	node test/test_full.js
```


### TODO

Before launch, make sure that the rpc used is wss and not https
Load funds into the mothership contract, mostly USDC and WETH, but others should be available as well
Ensure the correct contract addresses are in the scripts
