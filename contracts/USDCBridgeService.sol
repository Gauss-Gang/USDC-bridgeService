// SPDX-License-Identifier: MIT
// Authors: 
//      Atlas (atlas@cryptolink.tech) - https://cryptolink.tech
//      Gauss_Austin (austinm@gaussgang.com) - https://gaussgang.com

pragma solidity =0.8.19;

import "./libraries/token/SafeERC20.sol";
import "./libraries/access/Ownable.sol";
import "./libraries/security/ReentrancyGuard.sol";
import "./libraries/interfaces/IBridgeV2.sol";


// Interface for the USDC.pol token
interface IUSDCpol {
    function mint(address recipient, uint amount) external;
    function burn(uint256 amount) external;
}


/**
 *  This is a Bridge Service Contract Designed to facilitate the minting and burning of the Bridged USDC (Gauss) - USDC.pol stable 
 *  coin for the Gauss Ecosystem. USDC.pol is a Wrapped version of native USDC on the Polygon Chain and this contract handles
 *  the messaging service between Gauss and Polygon
 *      @dev contract desinged to share same contrat address on both Away and Gauss Chains
 */
contract USDCBridgeService is Ownable, ReentrancyGuard {
    address public FeeToken;
    address public USDCpol;
    address public USDC;
    address public WETH;
    address public BRIDGE;

    bool private _isGauss;
    bool private _initialized = false;

    uint256 private _feeAmount = 250000; // FeeToken is in USDC; equal to $0.25
    uint16 private _confirmations = 4;

    uint private constant _gaussChainID = 1777;
    uint private constant _polygonChainID = 137;

    event Recover(address to, address token, uint amount);
    event UpdateBridge(address bridge);
    event UpdateFeeToken(address feeToken);
    event UpdateFeeAmount(uint256 amount);
    event UpdateWETH(address weth);
    event UpdateConfirmations(uint16 amount);
    event MintUSDCpol(address to, uint amount);
    event BurnUSDCpol(address to, uint amount);
    event UnlockUSDCpol(address to, uint amount);
    event LockUSDCpol(address from, uint amount);


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
     * @param _feeToken Fee token address
     * @param _weth Wrapped Native token address
     * @param _usdcPol USDCpol address on Gauss (On 'Away' Chain, set to address(0))
     * @param _usdc USDC address on Polygon (on gauss this is address(0))
     */
    function init(address _bridge, address _feeToken, address _weth, address _usdcPol, address _usdc) external onlyOwner {
        
        require(_initialized == false, "Contract has previously been initialized");
        
        BRIDGE = _bridge;
        FeeToken = _feeToken;
        WETH = _weth;
        USDCpol = _usdcPol;
        USDC = _usdc;

        // Approve BRIDGE for Fee token transfers
        IERC20(FeeToken).approve(_bridge, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        IERC20(WETH).approve(_bridge, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

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
     * @param _recipient Address to deliver USDCpol (wallet or contract)
     * @param _amountIn Amount of STABLE to wrap on Away Chain
     * @param _source Address of the referrer of the transaction
     * @param _express Enable express mode
     */
    function transfer(address _recipient, uint _amountIn, address _source, bool _express) external payable nonReentrant returns (uint _txId) {

        require(_recipient != address(0), "recipient unknown");
        require(_amountIn > _feeAmount, "Amount too low to cover Bridge Fee");

        uint _chain;
        uint _adjustedAmountIn;

        // If the 'isGauss' value is false, we know we are on the Away Chain
        if(_isGauss == false) {
            _chain = _gaussChainID;  // sending to Gauss Chain
            _adjustedAmountIn = _amountIn - _feeAmount;
            require(_adjustedAmountIn > 0, "Amount too low to cover Bridge Fee");
            SafeERC20.safeTransferFrom(IERC20(USDC), msg.sender, address(this), _amountIn);
            emit LockUSDCpol(msg.sender, _adjustedAmountIn);
        } 

        // If the 'isGauss' value is true, we know we are on the Gauss Chain
        else if(_isGauss == true) {
            _chain = _polygonChainID;   // sending to Polygon Chain
            _adjustedAmountIn = _amountIn - _feeAmount;
            require(_adjustedAmountIn > 0, "Amount too low to cover Bridge Fee");
            SafeERC20.safeTransferFrom(IERC20(USDCpol), msg.sender, address(this), _amountIn);
            IUSDCpol(USDCpol).burn(_adjustedAmountIn);
            emit BurnUSDCpol(msg.sender, _adjustedAmountIn);
        }

        else {
            revert("invalid configuration");
        }

        bytes memory _packageData = abi.encode(
            _recipient,         // actual recipient
            _adjustedAmountIn,  // amount of tokens wrapped(stable) or burned (USDCpol)
            _source             // address who refered the traffic
        );

        if(_express) {
            _txId = IBridgeV2(BRIDGE).sendRequestExpress(
                address(this),  // recipient is the corresponding destination deploy of this contract, deployed contract addresses must match!
                _chain,         // id of the destination chain
                _feeAmount,     // fee amount, just min so gas/tx fees are paid - desination contract gets the change
                _source,        // "source"
                _packageData,   // encoded data to be processed by this contract on Gauss
                _confirmations  // number of confirmations before validating
            );
        }

        else {
            _txId = IBridgeV2(BRIDGE).sendRequest(
                address(this),  // recipient is the corresponding destination deploy of this contract, deployed contract addresses must match!
                _chain,         // id of the destination chain
                _feeAmount,     // fee amount, just min so gas/tx fees are paid - desination contract gets the change
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
            // We are on Polygon Chain
            SafeERC20.safeTransfer(IERC20(USDC), _recipient, _amountIn);
            emit UnlockUSDCpol(msg.sender, _amountIn);
        } 
        
        else if(_isGauss == true) {            
            // We are on Gauss Chain
            IUSDCpol(USDCpol).mint(_recipient, _amountIn);
            emit MintUSDCpol(msg.sender, _amountIn);
        }
        
        else {
            revert("Invalid configuration");
        }
    }


    // Update the Bridge address
    function updateBridge(address _newBridge) external onlyOwner {
        IERC20(FeeToken).approve(BRIDGE, 0);
        IERC20(WETH).approve(BRIDGE, 0);
        BRIDGE = _newBridge;
        IERC20(FeeToken).approve(_newBridge, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        IERC20(WETH).approve(_newBridge, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);        
        emit UpdateBridge(_newBridge);
    }


    // Update the Fee Token and approve the bridge to transfer the new Token
    function updateFeeToken(address _newFeeToken) external onlyOwner {
        IERC20(FeeToken).approve(BRIDGE, 0);
        FeeToken = _newFeeToken;
        IERC20(_newFeeToken).approve(BRIDGE, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        emit UpdateFeeToken(_newFeeToken);
    }


    // Update the Fee amount for minimum gas/tx fee payment
    function updateFeeAmount(uint256 _amount) external onlyOwner {
        _feeAmount = _amount;
        emit UpdateFeeAmount(_amount);
    }


    // Get the current fee amount
    function getFeeAmount() external view returns(uint256) {
        return _feeAmount;
    }

    
    // Update the WETH Token and approve the bridge to transfer the new Token
    function updateWETH(address _newWETH) external onlyOwner {
        IERC20(WETH).approve(BRIDGE, 0);
        WETH = _newWETH;
        IERC20(_newWETH).approve(BRIDGE, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        emit UpdateWETH(_newWETH);
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


    /* Withdrawl any ERC20 Token that are accidentally sent to this contract
            WARNING:    Interacting with unsafe tokens or smart contracts can 
                        result in stolen private keys, loss of funds, and drained
                        wallets. Use this function with trusted Tokens/Contracts only
    */
    function withdrawERC20Amount(address tokenAddress, address recoveryWallet, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > amount, "Balance too low to transfer amount");

        token.transfer(recoveryWallet, amount);
        emit Recover(recoveryWallet, tokenAddress, amount);  
    }


    // Contract Owner can withdraw any Native sent accidentally
    function nativeRecover(address recoveryWallet) external onlyOwner() {
        payable(recoveryWallet).transfer(address(this).balance);
    }
}
