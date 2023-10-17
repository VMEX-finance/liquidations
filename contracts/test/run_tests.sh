#!/usr/bin/bash

test() {
	echo $ARB_RPC
	forge test --match-path "test/Liq*" --fork-url $ARB_RPC -vvv
}

test
