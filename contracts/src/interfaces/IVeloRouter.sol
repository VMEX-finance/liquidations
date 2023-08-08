pragma solidity >=0.8.0; 

interface IVeloRouter {
	struct Route {
		address from;
    address to;
    bool stable;
    address factory;
	}
	/// @notice Swap one token for another
  /// @param amountIn     Amount of token in
  /// @param amountOutMin Minimum amount of desired token received
  /// @param routes       Array of trade routes used in the swap
  /// @param to           Recipient of the tokens received
  /// @param deadline     Deadline to receive tokens
  /// @return amounts     Array of amounts returned per route
	function swapExactTokensForTokens(
		uint256 amountIn,
    uint256 amountOutMin,
    Route[] calldata routes,
    address to,
    uint256 deadline
 ) external returns (uint256[] memory amounts);


  function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);
	function removeLiquidity(
		address tokenA,
    address tokenB,
    bool stable,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
	) external returns (uint256 amount0, uint256 amount1); 

	function swapExactTokensForTokensSimple(
		uint amountIn,
		uint amountOutMin,
		address tokenFrom,
   	address tokenTo,
   	bool stable,
   	address to,
   	uint deadline
	) external returns (uint[] memory amounts); 

	function addLiquidity(
		address tokenA,
  	address tokenB,
  	bool stable,
  	uint amountADesired,
  	uint amountBDesired,
  	uint amountAMin,
  	uint amountBMin,
  	address to,
  	uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity); 

}
