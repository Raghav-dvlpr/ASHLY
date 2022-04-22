// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


/**
 * @dev Contract module which allows children to implement an TokenGovernance
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It Creates a security for address and Token Transfer, 
 * When the are addresses and Tokens are restriced to transfer by ADMIN's OR CONTRACT Owners.
 */
abstract contract TokenGovernance is Initializable, ContextUpgradeable {
    
    /**
     * @dev Emitted when the Address is added to White List is triggered by `governer`.
     */
    
     event AddressWhiteListed(address account);

    /**
     * @dev Emitted when the Token is added to White List is triggered by `governer`.
     */

     event TokenWhiteListed(uint tokenid);
    
    /**
     * @dev Emitted when the Address is added to Black List is triggered by `governer`.
     */
    event AddressBlackListed(address account);

    /**
     * @dev Emitted when the Token is added to White List is triggered by `governer`.
     */
    event TokenBlackListed(uint tokenid);



    /**
     * @dev Emitted when the Address is removed from White List is triggered by `governer`.
     */
    
     event RemovedAddressFromWhiteList(address account);

    /**
     * @dev Emitted when the Token is removed from White List is triggered by `governer`.
     */

     event RemovedTokenFromWhiteList(uint tokenid);
    
    /**
     * @dev Emitted when the Address is removed from Black List is triggered by `governer`.
     */
    event RemovedAddressFromBlackList(address account);

    /**
     * @dev Emitted when the Token is removed from White List is triggered by `governer`.
     */

    event RemovedTokenFromBlackList(uint tokenid);
     
     
     
     /**
     * @dev Mapping Varibales That are used add Addresses and tokens to WhiteList and BlackList.
     */

    /**
     * @dev By default every mapping address and token will be false state..
     */



    mapping (address => bool) public whitelistedAddresses;
    mapping (address => bool) public blacklistedAddresses;

    mapping (uint => bool) public whitelistedTokens;
    mapping (uint => bool) public blacklistedTokens;

    bool public Transferable;

    /**
     * @dev Initializes the TokenGovernance contract  .
     */
    function __TokenGovernance_init(bool _transferable) internal onlyInitializing {
        __TokenGovernance_init_unchained(_transferable);
    }

    function __TokenGovernance_init_unchained(bool _transferable) internal onlyInitializing {
       Transferable = _transferable;
    }



     /**
     * @dev Function to check if the particular address is blacklisted
     *
     */
    function _isAddressBlackListed(address _address) internal virtual returns(bool) {
        return blacklistedAddresses[_address];
        
    }


     /**
     * @dev Function to check if the particular address is whitelisted
     *
     */

    function _isAddressWhiteListed(address _address) internal virtual returns(bool) {
        return whitelistedAddresses[_address];
        
    }

     /**
     * @dev Function to check if the particular token is blacklisted
     *
     */
    function _isTokenBlackListed(uint _tokenid) internal virtual returns(bool) {
        return blacklistedTokens[_tokenid];
    }

    /**
     * @dev Function to check if the particular token is whitelisted
     *
     */

    function _isTokenWhiteListed(uint _tokenid) internal virtual returns(bool) {
        return whitelistedTokens[_tokenid];
    }

    /**
     * @dev Sets true and Address are added to WhiteList Mapping.
     * It also Checks for Address is already blacklisted.
     * If it is blacklisted it will not add Address to whitelist.
     */
    function _whiteListAddress(address _address) internal virtual  {
        require(!_isAddressBlackListed(_address), "Your Address is Blacklisted");
        whitelistedAddresses[_address]=true;
        emit AddressWhiteListed(_address);
    }

    /**
     * @dev Sets true and Address are added to BlackList Mapping.
     */
    function _blackListAddress(address _address) internal virtual {
        blacklistedAddresses[_address]=true;
        emit AddressBlackListed(_address);
    }


    /**
     * @dev Sets true and Tokens are added to WhiteList Mapping.
     * It also Checks for Token is already blacklisted.
     * If it is blacklisted it will not add token to whitelist.
     */
    function _whiteListToken(uint _tokenid) internal virtual  {
        require(!_isTokenBlackListed(_tokenid), "Your Token is Blacklisted");
        whitelistedTokens[_tokenid]=true;
        emit TokenWhiteListed(_tokenid);
    }

    /**
     * @dev Sets true and  Tokens are added to BlackList Mapping.
     */
    function _blackListToken(uint _tokenid) internal virtual {
        blacklistedTokens[_tokenid]=true;
        emit TokenBlackListed(_tokenid);
    }


     /**
     * @dev Sets false if the Addresses are added to WhiteList Mapping.
     * and asssumed as address is removed from WhiteList.
     */
    function _removeWhiteListAddress(address _address) internal virtual {
        whitelistedAddresses[_address]=false;
        emit RemovedAddressFromWhiteList(_address);
    }

     /**
     * @dev Sets false if the Addresses are added to BlackList Mapping.
     * It also Checks for Token is already blacklisted.
     * If it is blacklisted it will be removed from blacklist.
     * and asssumed as address is removed from BlackList.
     */
    function _removeBlackListAddress(address _address) internal virtual {
        require(_isAddressBlackListed(_address), "addressError :address is not blacklisted");
        blacklistedAddresses[_address]=false;
        emit RemovedAddressFromBlackList(_address);
    }

    /**
     * @dev Sets false if the Tokens are added to WhiteList Mapping.
     * and asssumed as Token is removed from WhiteList.
     */
    function _removeWhiteListToken(uint _tokenid) internal virtual {
        whitelistedTokens[_tokenid]=false;
        emit RemovedTokenFromWhiteList(_tokenid);
    }

     /**
     * @dev Sets false if the Tokens are added to BlackList Mapping.
     * It also Checks for Token is already blacklisted.
     * If it is blacklisted it will be removed from blacklist.
     * and asssumed as Token is removed from BlackList.
     */
    function _removeBlackListToken(uint _tokenid) internal virtual {
        require(_isTokenBlackListed(_tokenid),"Error : Token is not blacklisted");
        blacklistedTokens[_tokenid]=false;
        emit RemovedTokenFromBlackList(_tokenid);
    }

    /**
     * @dev Returns true or false for Transferable.
     */
    function _isTransferable() internal virtual returns(bool){
        return Transferable;
    }

    /**
     * @dev Sets true or false for Transferable.
     */

    function _setTransferable(bool _transferable) internal virtual {
        Transferable = _transferable;
    }
    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}