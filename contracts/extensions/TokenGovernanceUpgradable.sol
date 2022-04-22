// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "../security/TokenGovernance.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev ERC721 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 */
abstract contract ERC721TokenGovernanceUpgradable is Initializable, ERC721Upgradeable, TokenGovernance {

    /**
     * @dev See {ERC721-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - The address must be Whitelisted or tokens also whitelisted or token are transferable .
     * - The Token must not be Blacklisted.
     * - The Sender Address must not be Blacklisted.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(
           _isAddressWhiteListed(to)   ||
           _isTokenWhiteListed(tokenId) || 
           _isTransferable(),
        "Error: Your Address or Tokes are not White Listed, Or your Token is not Transferbale.");
        require(!_isTokenBlackListed(tokenId),"Token is Black Listed");
        require(_isAddressWhiteListed(msg.sender), "Failed: Your Address is not WhiteListed.");
        
        super._beforeTokenTransfer(from, to, tokenId);

        
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}