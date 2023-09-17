// SPDX-License-Identifier: MIT
pragma solidity >0.5.0;

interface IBridgeV2 {
    
    function bridgeEnabled() external view returns (bool);

    function enabledChains(uint256 chainId) external view returns (bool);

    function minTokenForChain(uint256 chainId) external view returns (uint256);

    function stable() external view returns (address);
    
    function cccnft() external view returns (address);

    // called by sending contract
    function sendRequest(address _recipient, uint256 _chain, uint256 _amount, address _source, bytes calldata _data, uint16 confirmations) external returns (uint txId);
    function sendRequestExpress(address _recipient, uint256 _chain, uint256 _amount, address _source, bytes calldata _data) external returns (uint txId);

    // implemented by receiving contract
    function messageProcess(uint txId, uint sourceChainId, address sender, address recipient, uint amount, bytes calldata data) external;

    // returns the source fee in terms of PAPER (takes cccnft discounts into account)
    // (to get the destination gas fee, call the estimateGas from messageProcess on destination chain)
    function getSourceFee(uint _amount) external view returns (uint _fee);
    function getSourceFee(uint _amountInPaper, bool _express, uint _destChainId) external view returns (uint _fee);
}