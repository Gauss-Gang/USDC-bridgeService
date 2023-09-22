// SPDX-License-Identifier: MIT
// Author: Atlas (atlas@cryptolink.tech)
// Modified: Gauss_Austin (austinm@gaussgang.com)
// https://cryptolink.tech
// https://anytoany.io
// https://gaussgang.com

pragma solidity =0.8.21;

import "./libraries/token/SafeERC20.sol";
import "./libraries/access/Ownable.sol";
import "./libraries/security/ReentrancyGuard.sol";
import "./libraries/interfaces/IBridgeV2.sol";


// Interface for the GUD token
interface IGUD {
    function mint(address recipient, uint amount) external;
    function burnFrom(address account, uint256 amount) external;
    function depositFor(address account, uint256 amount) external;
    function withdrawTo(address account, uint256 amount) external;
}


/**
 *  This is a Bridge Service Contract Designed to facilitate the minting and burning of the GUD Stable Token
 *  for the Gauss Ecosystem. GUD is a Wrapped version of an existing Stable and this contract handles
 *  the messaging service between Gauss and 'Away' Chains 
 *      @dev contract desinged to share same contrat address on both Away and Gauss Chains
 */
contract GUDBridgeService is Ownable, ReentrancyGuard {
    address public PAPER;
    address public GUD;
    address public USDC;
    address public BRIDGE;

    bool private _isGauss;
    bool private _initialized = false;

    uint256 private _paperAmount = 100 ether;
    uint16 private _confirmations = 4;

    /* Mainnet:
    uint private constant _gaussChainID = 1777;
    uint private constant _polygonChainID = 137;
    */

    // Testnet:
    uint private constant _gaussChainID = 1452;
    uint private constant _polygonChainID = 8001;

    event Recover(address to, address token, uint amount);
    event UpdateBridge(address bridge);
    event UpdatePaperAmount(uint256 amount);
    event UpdateConfirmations(uint16 amount);
    event MintGUD(address to, uint amount);
    event BurnGUD(address to, uint amount);
    event UnlockGUD(address to, uint amount);
    event LockGUD(address from, uint amount);


    modifier onlyBridge {
        require(msg.sender == BRIDGE, "not authorized");
        _;
    }

    
    // This function allows the contract to receives Native Currency 
    receive() external payable {}


    /**
     * Called after deploy to set contract addresses.
     *
     * @param _bridge Bridge address
     * @param _paper PAPER token address
     * @param _gud GUD address on Gauss (On 'Away' Chain, set to address(0))
     * @param _usdc USDC address on Polygon (on gauss this is address(0))
     */
    function init(address _bridge, address _paper, address _gud, address _usdc) external onlyOwner {
        
        require(_initialized == false, "Contract has previously been initialized");
        
        BRIDGE = _bridge;
        PAPER  = _paper;
        GUD    = _gud;
        USDC   = _usdc;

        // Approve BRIDGE for PAPER token transfers
        IERC20(PAPER).approve(_bridge, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        uint256 currentChainId = block.chainid;

        if (currentChainId == _gaussChainID) {
            _isGauss = true;
        }
        else {
            _isGauss = false;
        }

        _initialized = true;
    }


    /**
     * @param _recipient Address to deliver GUD (wallet or contract)
     * @param _amountIn Amount of STABLE to wrap on Away Chain
     * @param _source Address of the referrer of the transaction
     * @param _express Enable express mode
     */
    function transfer(address _recipient, uint _amountIn, address _source, bool _express) external payable nonReentrant returns (uint _txId) {

        require(_recipient != address(0), "recipient unknown");

        uint _chain;

        // If the 'isGauss' value is false, we know we are on the Away Chain
        if(_isGauss == false) {
            _chain = _gaussChainID;  // sending to Gauss Chain
            SafeERC20.safeTransferFrom(IERC20(USDC), msg.sender, address(this), _amountIn);
            IGUD(GUD).depositFor(address(this), _amountIn);
            emit LockGUD(msg.sender, _amountIn);
        } 

        // If the 'isGauss' value is true, we know we are on the Gauss Chain
        else if(_isGauss == true) {
            _chain = _polygonChainID;   // sending to Polygon Chain
            IGUD(GUD).burnFrom(msg.sender, _amountIn);
            emit BurnGUD(msg.sender, _amountIn);
        }

        else {
            revert("invalid configuration");
        }

        bytes memory _packageData = abi.encode(
            _recipient,     // actual recipient
            _amountIn,      // amount of tokens wrapped(stable) or burned (GUD)
            _source         // address who refered the traffic
        );

        if(_express) {
            _txId = IBridgeV2(BRIDGE).sendRequestExpress(
                address(this),  // recipient is the corresponding destination deploy of this contract, deployed contract addresses must match!
                _chain,         // id of the destination chain
                _paperAmount,   // paper amount, just min so gas/tx fees are paid - desination contract gets the change
                _source,        // "source"
                _packageData    // encoded data to be processed by this contract on Gauss
            );
        } 

        else {
            _txId = IBridgeV2(BRIDGE).sendRequest(
                address(this),  // recipient is the corresponding destination deploy of this contract, deployed contract addresses must match!
                _chain,         // id of the destination chain
                _paperAmount,   // paper amount, just min so gas/tx fees are paid - desination contract gets the change
                _source,        // "source"
                _packageData,   // encoded data to be processed by this contract on Gauss
                _confirmations  // number of confirmations before validating
            );
        }

        return(_txId);
    }


    // BRIDGE ACCESS ONLY
    function messageProcess(uint,uint, address _sender, address _recipient, uint, bytes calldata _packageData) external nonReentrant onlyBridge {
        require(_sender == address(this), "wrong address");     // @dev reminder: contract addresses must match on both Away and Gauss Chains

        /*  Extracts the FINAL recipient and the FINAL data from _packageData,
            which is set on the source chain for the address calling this contract

                @dev _recipient above is "us" so we unwrap and override here with next level _recipient
        */
        address _source;
        uint _amountIn;
        (_recipient, _amountIn, _source) = abi.decode(_packageData, (address, uint, address));

        if(_isGauss == false) {            
            // We are on Away Chain
            IGUD(GUD).withdrawTo(_recipient, _amountIn);
            emit UnlockGUD(msg.sender, _amountIn);
        } 
        
        else if(_isGauss == true) {            
            // We are on Gauss Chain
            IGUD(GUD).mint(_recipient, _amountIn);
            emit MintGUD(msg.sender, _amountIn);
        }
        
        else {
            revert("Invalid configuration");
        }
    }


    // Update the bridge address and approve the new bridge to transfer Paper
    function updateBridge(address _newBridge) external onlyOwner {
        IERC20(PAPER).approve(BRIDGE, 0);
        BRIDGE = _newBridge;
        IERC20(PAPER).approve(_newBridge, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        emit UpdateBridge(_newBridge);
    }


    // Update the paper amount for minimum gas/tx fee payment
    function updatePaperAmount(uint256 _amount) external onlyOwner {
        _paperAmount = _amount;
        emit UpdatePaperAmount(_amount);
    }


    // Update the number of confirmations required before validating
    function updateConfirmations(uint16 _numConfirmations) external onlyOwner {
        _confirmations = _numConfirmations;
        emit UpdateConfirmations(_numConfirmations);
    }


    /* Withdrawl any ERC20 Token that are accidentally sent to this contract
            WARNING:    Interacting with unsafe tokens or smart contracts can 
                        result in stolen private keys, loss of funds, and drained
                        wallets. Use this function with trusted Tokens/Contracts only
    */
    function withdrawERC20(address tokenAddress, address recoveryWallet) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        token.transfer(recoveryWallet, balance);
        emit Recover(recoveryWallet, tokenAddress, balance);  
    }


    // Contract Owner can withdraw any Native sent accidentally
    function nativeRecover(address recoveryWallet) external onlyOwner() {
        payable(recoveryWallet).transfer(address(this).balance);
    }
}
