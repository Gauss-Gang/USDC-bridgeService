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
 *      existing ecosystem.
*/
contract GUDStable is ERC20, ERC20Burnable, Pausable, Ownable, ERC20Wrapper {

    IERC20 private immutable _stable;
    bool private _initialized;
    bool private _isGauss;

    address public gudBridge;

    modifier onlyBridge {
        require(msg.sender == gudBridge, "Address not authorized");
        _;
    }


    // Creates the GUD Stable ERC20 Token and sets up the Stable Wrapping Extension
    constructor(IERC20 stableToWrap_) 
        ERC20("Gauss Stable", "GUD", 6)
        ERC20Wrapper(stableToWrap_) {         
        
        _stable = stableToWrap_;
    }


    // Initializes the Contract to determine which chain the contract is on.
    function init(address bridge) public onlyOwner {
        
        require (_initialized == false, "Contract has already been initialized");

        uint256 currentChainId = block.chainid;

        // Testnet Specific Check, sends 1 Million to owner for testing
        if (currentChainId == 1452) {
            _isGauss = true;
            _mint(owner(), (1000000 * 10**decimals()));
        }

        else if (currentChainId == 1777) {
            _isGauss = true;
        }

        else {
            _isGauss = false;
        }

        gudBridge = bridge;
        _initialized = true;
    }


    // Pause Token Trading and Transfers
    function pause() public onlyOwner {
        _pause();
    }


    // Unpause Token Trading and Transfers
    function unpause() public onlyOwner {
        _unpause();
    }


    // Orride to allow the Bridge to deposit stable tokens and mint the corresponding number of wrapped tokens.
    function depositFor(address account, uint256 amount) public override virtual whenNotPaused onlyBridge returns (bool) {
        return super.depositFor(account, amount);
    }


    // Ovveride to allow the Bridge to burn a number of wrapped tokens and withdraw the corresponding number of stable tokens.
    function withdrawTo(address account, uint256 amount) public override virtual whenNotPaused onlyBridge returns (bool) {
        return super.withdrawTo(account, amount);
    }


    // Mint GUD on the Gauss Chain. Can only be called by the Bridge Contract
    function mint(address to, uint256 amount) external whenNotPaused onlyBridge {
        require(_isGauss == true, "Minting only supported on the Gauss Chain");
        _mint(to, amount);
    }

    
    // Override transfer function to prevent transfers while paused
    function _transfer(address sender, address recipient, uint256 amount) internal override whenNotPaused {
        super._transfer(sender, recipient, amount);
    }


    // Update GUD Bridge Address
    function updateBridge(address bridgeAddress) external onlyOwner {
        gudBridge = bridgeAddress;
    }


    // Mint wrapped token to cover any Stable Tokens that may have been transferred by mistake
    function accidentalRecover(address account) public onlyOwner returns (uint256) {
        return _recover(account);
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


    // Hook that is called before any transfer of tokens. This includes minting and burning
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, amount);
    }
}
