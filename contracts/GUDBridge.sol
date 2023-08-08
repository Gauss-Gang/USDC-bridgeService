// SPDX-License-Identifier: MIT
// Author: Atlas (atlas@cryptolink.tech)
// Modified: Gauss_Austin (gaussgang.com)
// https://cryptolink.tech
// https://anytoany.io

pragma solidity =0.8.19;

import "./libraries/token/SafeERC20.sol";
import "./libraries/token/ERC20Burnable.sol";
import "./libraries/access/Ownable.sol";
import "./libraries/security/ReentrancyGuard.sol";
import "./libraries/interfaces/IBridgeV2.sol";


interface IGUD {
    function mint(address recipient, uint amount) external;
}


/**
 *  This is a Bridge Contract Designed to facilitate the minting and burning of the GUD Stable Token
 *  for the Gauss Ecosystem. GUD is a Wrapped version of an existing Stable and this contract handles
 *  the messaging service between the Gauss and 'Away' Chains, 
 *      @dev contract desinged to share same contrat address on both Away and Gauss Chains
 */
contract GUDBridge is Ownable, ReentrancyGuard {
    address public PAPER;
    address public GUD;
    address public BRIDGE;

    uint private _chain;
    bool private _isGauss;

    event Recover(address to, address token, uint amount);
    event UpdateBridge(address bridge);
    event MintGUD(address to, uint amount);
    event BurnGUD(address to, uint amount);
    event UnlockGUD(address to, uint amount);
    event LockGUD(address from, uint amount);

    modifier onlyBridge {
        require(msg.sender == BRIDGE, "not authorized");
        _;
    }


    /**
     * Called after deploy to set contract addresses.
     *
     * @param _bridge Bridge address
     * @param _paper PAPER token address
     * @param _gud GUD address on Gauss (On 'Away' Chain, set to address(0))
     */
    function init(address _bridge, address _paper, address _gud) external onlyOwner {
        BRIDGE = _bridge;
        PAPER  = _paper;
        GUD    = _gud;

        IERC20(PAPER).approve(_bridge, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        uint256 currentChainId = block.chainid;

        // Testnet Specific Check
        if (currentChainId == 1452) {
            _isGauss = true;
        }

        else if (currentChainId == 1777) {
            _isGauss = true;
        }

        else {
            _isGauss = false;
        }
    }


    /**
     * @param _recipient Address to deliver gUSD (wallet or contract)
     * @param _amountIn Amount of STABLE to wrap on Away Chain
     * @param _source Address of the referrer of the transaction
     * @param _express Enable express mode
     */
    function transfer(address _recipient, uint _amountIn, address _source, bool _express) external payable nonReentrant returns (uint _txId) {

        require(_recipient != address(0), "recipient unknown");

        // If the 'isGauss' value is false, we know we are on the Away Chain
        if(_isGauss == false) {
            _chain = 1777;  // sending to Gauss
            SafeERC20.safeTransferFrom(IERC20(GUD), msg.sender, address(this), _amountIn);
            emit LockGUD(msg.sender, _amountIn);
        } 

        // If the 'isGauss' value is true, we know we are on the Gauss Chain
        else if(_isGauss == true) {
            _chain = 137;   // sending to Away Chain
            ERC20Burnable(GUD).burnFrom(msg.sender, _amountIn);
            emit BurnGUD(msg.sender, _amountIn);
        } 

        else {
            revert("invalid configuration");
        }

        bytes memory _packageData = abi.encode(
            _recipient,     // actual recipient
            _amountIn,      // amount of tokens wrapped(stable) or burned (gusd)
            _source         // address who refered the traffic
        );

        if(_express) {
            _txId = IBridgeV2(BRIDGE).sendRequestExpress(
                address(this),  // recipient is the corresponding destination deploy of this contract, deployed contract addresses must match!
                _chain,         // id of the destination chain
                100 ether,      // paper amount, just min so gas/tx fees are paid - desination contract gets the change
                _source,        // "source"
                _packageData    // encoded data to be processed by this contract on Gauss
            );
        } 

        else {
            _txId = IBridgeV2(BRIDGE).sendRequest(
                address(this),  // recipient is the corresponding destination deploy of this contract, deployed contract addresses must match!
                _chain,         // id of the destination chain
                100 ether,      // paper amount, just min so gas/tx fees are paid - desination contract gets the change
                _source,        // "source"
                _packageData    // encoded data to be processed by this contract on Gauss
            );
        }

        return(_txId);
    }


    // BRIDGE ACCESS ONLY
    function messageProcess(uint, address _sender, address _recipient, uint, bytes calldata _packageData) external nonReentrant onlyBridge {
        require(_sender == address(this), "wrong address");     // @dev reminder: contract addresses must match on both Away and Gauss Chains

        /*  This grabs the FINAL recipient and the FINAL data from the _packageData,
            which is set on the source chain for the address calling this contract

                @dev _recipient above is "us" so we unwrap and override here with next level _recipient
        */
        address _source;
        uint _amountIn;
        (_recipient, _amountIn, _source) = abi.decode(_packageData, (address, uint, address));

        if(_isGauss == false) {            
            // We are on Away Chain
            SafeERC20.safeTransfer(IERC20(GUD), _recipient, _amountIn);
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


    function recover(address _token, uint256 _amount, address _to) external onlyOwner {
        require(_to != address(0), "cannot send to zero address");
        
        if(_token == address(0)) {
          
          //    @TODO
          //  (bool _sent, ) = msg.sender.call{ value: address(this).balance }("");
        }
        
        else {
            IERC20(_token).transfer(_to, _amount);
        }

        emit Recover(_to, _token, _amount);
    }    


    function updateBridge(address _bridge) external onlyOwner {
        BRIDGE = _bridge;
        emit UpdateBridge(_bridge);
    }
}
