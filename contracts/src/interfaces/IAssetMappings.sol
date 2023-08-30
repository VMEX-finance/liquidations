// SPDX-License-Identifier: agpl-3.0                                                     
pragma solidity >=0.8.0; 


interface IAssetMappings {

function configureAssetMapping(                                                      
    address asset,//20                                                               
    uint64 baseLTV, //28                                                             
    uint64 liquidationThreshold, //36 --> 1 word, 8 bytes                            
    uint64 liquidationBonus, //1 word, 16 bytes                                      
    uint128 supplyCap, //1 word, 32 bytes -> 1 word                                  
    uint128 borrowCap, //2 words, 16 bytes                                           
    uint64 borrowFactor //2 words, 24 bytes --> 3 words total                        
) external; 


}
