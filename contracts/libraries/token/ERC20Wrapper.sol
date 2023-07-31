    
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/ERC20Wrapper.sol)

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./SafeERC20.sol";

/**
 * @dev Extension of the ERC20 token contract to support token wrapping.
 *
 * Users can deposit and withdraw "underlying tokens" and receive a matching number of "wrapped tokens". This is useful
 * in conjunction with other modules. For example, combining this wrapping mechanism with {ERC20Votes} will allow the
 * wrapping of an existing "basic" ERC20 into a governance token.
 *
 * _Available since v4.2._
 */
abstract contract ERC20Wrapper is ERC20 {
    IERC20 private immutable _stable;    

    constructor(IERC20 stableToWrap) {
        require(stableToWrap != this, "GUDStable: cannot self wrap");
        _stable = stableToWrap;
    }


    // Returns the address of the stable ERC-20 token that is being wrapped.
    function stableToken() public view returns (IERC20) {
        return _stable;
    }


    // Allow a user to deposit stable tokens and mint the corresponding number of wrapped tokens.
    function depositFor(address account, uint256 amount) public virtual returns (bool) {
        
        address sender = _msgSender();        
        require(sender != address(this), "GUDStable: can't deposit from self");
        
        SafeERC20.safeTransferFrom(_stable, sender, address(this), amount);
        _mint(account, amount);

        return true;
    }


    // Allow a user to burn a number of wrapped tokens and withdraw the corresponding number of stable tokens.
    function withdrawTo(address account, uint256 amount) public virtual returns (bool) {
        _burn(_msgSender(), amount);
        SafeERC20.safeTransfer(_stable, account, amount);
        return true;
    }


    // Mint wrapped token to cover any stableTokens that would have been transferred by mistake
    function _recover(address account) internal virtual returns (uint256) {
        uint256 value = _stable.balanceOf(address(this)) - totalSupply();
        _mint(account, value);
        return value;
    }
}