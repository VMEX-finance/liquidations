#! /usr/bin/bash

PRIVATE_KEY="0x0afa002275a687c5b9fd636a9616ddfad6440deb49135d987ee90e9bee0c4a2c"
TOKEN_MAPPINGS="0x546a23d1afb1cb862c09d26aed02b2d513d3f445"
FLASHLOAN_LIQUIDATION="0xf2c8952f9631a45bf33778a09849a1218c8d37be"
PERIPHERAL_LOGIC="0x05Aa229Aec102f78CE0E852A812a388F076Aa555"
ROUTER="0x0b48aF34f4c854F5ae1A3D587da471FeA45bAD52"
MOTHERSHIP="0x0f5D1ef48f12b6f691401bfe88c2037c690a6afe"


#forge c src/IBTokenMappings.sol:IBTokenMappings --private-key $PRIVATE_KEY &&
#forge c src/FlashLoanLiquidationV3.sol:FlashLoanLiquidation --private-key $PRIVATE_KEY
forge c src/PeripheralLogic.sol:PeripheralLogic --constructor-args $TOKEN_MAPPINGS $FLASHLOAN_LIQUIDATION --private-key $PRIVATE_KEY &&
forge c src/Router.sol:FlashLoanRouter --private-key $PRIVATE_KEY &&
#forge c src/Mothership.sol:Mothership --constructor-args $ROUTER 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --private-key $PRIVATE_KEY
