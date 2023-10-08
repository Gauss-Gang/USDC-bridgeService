// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import {ERC20} from "./libraries/token/ERC20.sol";
import {ERC20Wrapper} from "./libraries/token/ERC20Wrapper.sol";
import {ERC20Burnable} from "./libraries/token/ERC20Burnable.sol";
import {IERC20Metadata} from "./libraries/interfaces/IERC20Metadata.sol";
import {IERC20} from "./libraries/interfaces/IERC20.sol";
import {SafeERC20} from "./libraries/token/SafeERC20.sol";
import {Pausable} from "./libraries/security/Pausable.sol";
import {Ownable} from "./libraries/access/Ownable.sol";


/**
 * Gauss Stablecoin
 *      This Contract creates a StableCoin for the Gauss Ecosystem by Wrapping an already existing Stable on 
 *      another EVM Compatible Chain. This contract is Chain and Stable Agnostic, allowing GUD to be directly
 *      pegged to ONE existing Stable, creating a 1 to 1 backed Stable Coin with the security and trust of the 
 *      existing ecosystem. This particular contract is set up to use USDC on Polygon, wrap it, and mint at 
 *      a 1:1 ratio. Only the GUDBridgeService can depost or withdrawl Stable Coins. 
 *      
*/
contract GUDStable is ERC20, ERC20Burnable, Pausable, Ownable, ERC20Wrapper {

    IERC20 private immutable _stable;
    bool private _initialized;
    bool private _isGauss;

    address public gudBridge;

    modifier onlyBridge {
        require(_msgSender() == gudBridge, "Address not authorized");
        _;
    }

    // Event emitted when the GUD tokens are minted
    event Minted(address indexed to, uint256 amount);

    // Event emitted when Stable tokens are deposited
    event Deposited(address indexed from, uint256 amount);

    // Event emitted when Stable tokens are withdrawn
    event Withdrawn(address indexed from, uint256 amount);

    // Event emitted when the GUD Bridge address is updated
    event BridgeUpdated(address newBridge);

    // Event emitted when GUD is Minted after the Stable Coin
    // being Wrapped is sent directly to this contract by accident
    event AccidentalRecover(uint256 amount, address recoveryAddress);

    // Event emitted when an ERC20 token has been sent to this address
    // by accident, such as the wrong Stable Coin
    event Recover(address to, address token, uint amount);


    // Creates the GUD Stable ERC20 Token and sets up the Stable Wrapping Extension
    constructor(address stableToWrap) 
        ERC20("Gauss Stable", "GUD", 6)
        ERC20Wrapper((IERC20(stableToWrap))) {         

        _stable = IERC20(stableToWrap);
    }


    // Initializes the Contract to determine which chain the contract is on.
    function init(address bridge) public onlyOwner {
        
        require (_initialized == false, "Contract has already been initialized");

        uint256 currentChainId = block.chainid;

        if (currentChainId == 1777) {
            _isGauss = true;
        }

        else {
            _isGauss = false;
        }

        gudBridge = bridge;
        _initialized = true;
    }


    // Fallback function to allow the contract to receives Native Currency 
    receive() external payable {}
    

    // Pause Token Trading and Transfers
    function pause() public onlyOwner {
        super._pause();
    }


    // Unpause Token Trading and Transfers
    function unpause() public onlyOwner {
        super._unpause();
    }


    // Override to allow the Bridge to deposit stable tokens and mint the corresponding number of wrapped tokens.
    function depositFor(address account, uint256 amount) public override virtual whenNotPaused onlyBridge returns (bool) {
        
        bool depositSuccess = super.depositFor(account, amount);
        
        if (depositSuccess == true) { emit Deposited(account, amount); }
        
        return depositSuccess;
    }


    // Override to allow the Bridge to burn a number of wrapped tokens and withdraw the corresponding number of stable tokens.
    function withdrawTo(address account, uint256 amount) public override virtual whenNotPaused onlyBridge returns (bool) {
        
        bool withdrawSuccess = super.withdrawTo(account, amount);
        
        if (withdrawSuccess == true) { emit Deposited(account, amount); }
        
        return withdrawSuccess;
    }


    // Mint GUD on the Gauss Chain. Can only be called by the Bridge Contract
    function mint(address to, uint256 amount) external whenNotPaused onlyBridge {
        require(_isGauss == true, "Minting only supported on the Gauss Chain");
        super._mint(to, amount);
        emit Minted(to, amount);
    }

    
    // Override transfer function to prevent transfers while paused
    function _transfer(address sender, address recipient, uint256 amount) internal override whenNotPaused {
        super._transfer(sender, recipient, amount);
    }


    // Update GUD Bridge Address
    function updateBridge(address bridgeAddress) external onlyOwner {
        gudBridge = bridgeAddress;
        emit BridgeUpdated(bridgeAddress);
    }


    // Mint wrapped token to cover any Stable Tokens that may have been transferred by mistake
    function accidentalRecover(address account) public onlyOwner returns (uint256) {
        uint256 amountRecovered = super._recover(account);
        emit AccidentalRecover(amountRecovered, account);
        return amountRecovered;
    }


    // Recover all stored Stable Tokens in the Contract in the event of a depegging emergency
    function emergencyRecover(address account) public onlyOwner returns (uint256) {
        require(_isGauss == false, "Recovering only supported on the 'Away' Chain");
        uint256 value = _stable.balanceOf(address(this));
        SafeERC20.safeTransfer(_stable, account, value);
        pause();
        return value;
    }


    // Contract Owner can withdraw any Native sent accidentally
    function nativeRecover(address recoveryWallet) external onlyOwner {
        payable(recoveryWallet).transfer(address(this).balance);
    }


    /* Withdrawl any ERC20 Token that are accidentally sent to this contract
            WARNING:    Interacting with unsafe tokens or smart contracts can 
                        result in stolen private keys, loss of funds, and drained
                        wallets. Use this function with trusted Tokens/Contracts only.
    */
    function withdrawERC20(address tokenAddress, address recoveryWallet) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        token.transfer(recoveryWallet, balance);
        emit Recover(recoveryWallet, tokenAddress, balance);  
    }


    // Hook that is called before any transfer of tokens. This includes minting and burning
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, amount);
    }
}
