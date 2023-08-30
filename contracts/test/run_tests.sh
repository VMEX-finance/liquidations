#!/usr/bin/bash

OP_RPC=https://optimism-mainnet.infura.io/v3/1cad81887e224784a4d2ad2db5c0587a
test() {
	forge test --match-path "test/Liq*" --fork-url $OP_RPC -vvv
}

test
