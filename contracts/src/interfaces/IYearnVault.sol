pragma solidity >=0.8.0; 


interface IYearnVault {

	function decimals() external returns (uint256); 
	function name() external returns (string memory); 
	function withdraw(uint256 amountShares, address recipient) external returns (uint256); 

}
