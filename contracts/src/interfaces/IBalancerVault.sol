pragma solidity >= 0.8.0; 	
import {IERC20} from "forge-std/interfaces/IERC20.sol"; 

//intentionally blank
interface IAsset {

}

interface IVault {

	struct ExitPoolRequest {
        IAsset[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

	enum ExitKind {
	    EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
	    EXACT_BPT_IN_FOR_TOKENS_OUT,
	    BPT_IN_FOR_EXACT_TOKENS_OUT,
	    MANAGEMENT_FEE_TOKENS_OUT // for InvestmentPool
	}

	function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        IVault.ExitPoolRequest memory request
    ) external;

	function getPoolTokens(bytes32 poolId)
   	external
   	view
   	returns (
   	    IERC20[] memory tokens,
   	    uint256[] memory balances,
   	    uint256 lastChangeBlock
   	);
	
}
