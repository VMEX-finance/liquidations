#! /usr/bin/bash

PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
TOKEN_MAPPINGS="0xC6bA8C3233eCF65B761049ef63466945c362EdD2"
FLASHLOAN_LIQUIDATION="0x1275D096B9DBf2347bD2a131Fb6BDaB0B4882487"
PERIPHERAL_LOGIC="0x05Aa229Aec102f78CE0E852A812a388F076Aa555"
ROUTER="0x0b48aF34f4c854F5ae1A3D587da471FeA45bAD52"
MOTHERSHIP="0x0f5D1ef48f12b6f691401bfe88c2037c690a6afe"


forge c src/IBTokenMappings.sol:IBTokenMappings --private-key $PRIVATE_KEY &&
forge c src/FlashLoanLiquidationV3.sol:FlashLoanLiquidation --private-key $PRIVATE_KEY &&
forge c src/PeripheralLogic.sol:PeripheralLogic --constructor-args $TOKEN_MAPPINGS $FLASHLOAN_LIQUIDATION --private-key $PRIVATE_KEY &&
forge c src/Router.sol:FlashLoanRouter --private-key $PRIVATE_KEY &&
forge c src/Mothership.sol:Mothership --constructor-args $ROUTER 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --private-key $PRIVATE_KEY
