// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";  
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

library libERC721Fee {
    uint256 constant TYPE_DEFAULT = 0;
    uint256 constant TYPE_SALE = 1;
    uint256 constant TYPE_AUCTION = 2;

    struct Part {
        address payable account;
        uint256 value;
    }

    struct Data {
        address payable collectableOwner;
        Part[] creators;
        uint256 transactionNounce;
        bool isSecondary;
    }
}

interface NFTMarketplaceUpgradable {
    struct Royalties {
        address payable account;
        uint256 percentage;
    }
    function mint(address receiver,uint collectibleId, string memory IPFSHash, Royalties calldata royalties) external;
    function ownerOf(uint256 _tokenId) external view returns (address);
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
}

contract GPNFTMarketplaceUpgradable is
    Initializable,
    AccessControlEnumerableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC721ReceiverUpgradeable 
{
     using SafeMathUpgradeable for uint256;

    function initialize(
        address rootAdmin,
        libERC721Fee.Part memory _maintainer,
        uint16 _maintainerInitialFee,
        NFTMarketplaceUpgradable _tokenerc721
    ) public virtual initializer {
        __GPNFTMarketplaceUpgradable_init( 
            rootAdmin,
            _maintainer,
            _maintainerInitialFee,
            _tokenerc721
        );
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function __GPNFTMarketplaceUpgradable_init(
        address rootAdmin,
        libERC721Fee.Part memory _maintainer,
        uint16 _maintainerInitialFee,
        NFTMarketplaceUpgradable _tokenerc721
    ) internal initializer {
        __GPNFTMarketplaceUpgradable_init_unchained(
            rootAdmin,
            _maintainer,
            _maintainerInitialFee,  
            _tokenerc721
        );
        __ReentrancyGuard_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __Ownable_init_unchained();
    }

    function __GPNFTMarketplaceUpgradable_init_unchained(
        address rootAdmin,
        libERC721Fee.Part memory _maintainer,
        uint16 _maintainerInitialFee,
        NFTMarketplaceUpgradable _tokenerc721
    ) internal initializer {
        _setMaintainer(_maintainer, _maintainerInitialFee);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, rootAdmin);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        _setNftToken(_tokenerc721);
    }

    mapping(uint256 => libERC721Fee.Data) private tokenSaleData;
    mapping(uint256 => uint256) private saleStatus;
    mapping(uint256 => libERC721Fee.Part) auction;
    mapping(uint256 => libERC721Fee.Part) sale;
    libERC721Fee.Part private maintainer;
    uint16 private maintainerInitialFee;

    NFTMarketplaceUpgradable private tokenerc721;

    event StartAuction(
        address indexed tokenOwner,
        uint256 indexed tokenId,
        uint256 basePrice
    ); 
    event StartSale(
        address indexed tokenOwner,
        uint256 indexed tokenId,
        uint256 basePrice
    ); 
    event Buy(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        uint256 price
    );
    event Bid(
        uint256 indexed tokenId,
        address indexed currentBidder,
        uint256 biddingAmount
    );
    event PlaceBid(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        uint256 price
    );
    event Cancel(uint256 indexed tokenId, uint256 currentNounce);



     /**
    * @dev overriding the inherited {transferOwnership} function to reflect the admin changes into the {DEFAULT_ADMIN_ROLE}
    */
    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
        _setupRole(DEFAULT_ADMIN_ROLE, newOwner);
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }
    
    /**
    * @dev overriding the inherited {grantRole} function to have a single root admin
    */
    function grantRole(bytes32 role, address account) public override {
        if(role == ADMIN_ROLE)
            require(getRoleMemberCount(ADMIN_ROLE) == 0, "exactly one address can have admin role");
            
        super.grantRole(role, account);
    }

    /**
    * @dev modifier to check admin rights.
    * contract owner and root admin have admin rights
    */
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, _msgSender()) || owner() == _msgSender(), "Restricted to admin.");
        _;
    }
    
    /**
    * @dev modifier to check mint rights.
    * contract owner, root admin and minter's have mint rights
    */
    modifier onlyMinter() {
        require(
            hasRole(ADMIN_ROLE, _msgSender()) || 
            hasRole(MINTER_ROLE, _msgSender()) || 
            owner() == _msgSender(), "Restricted to minter."
            );
        _;
    }
    
    /**
    * @dev This function is to change the root admin 
    * exaclty one root admin is allowed per contract
    * only contract owner have the authority to add, remove or change
    */
    function changeRootAdmin(address newAdmin) public {
        address oldAdmin = getRoleMember(ADMIN_ROLE, 0);
        revokeRole(ADMIN_ROLE, oldAdmin);
        grantRole(ADMIN_ROLE, newAdmin);
    }
    
    /**
    * @dev This function is to add a minter into the contract, 
    * only root admin and contract owner have the authority to add them
    * but only the root admin can revoke them using {revokeRole}
    * minter or pauser can also self renounce the access using {renounceRole}
    */
    function addMinter(address account, bytes32 role) public onlyAdmin{
        if(role == MINTER_ROLE)
            _setupRole(role, account);
    }




    function getTokenNounce(uint256 tokenId) public view returns (uint256) {
        return tokenSaleData[tokenId].transactionNounce;
    }

    function getCurrentBid(uint256 tokenId)
        public
        view
        returns (libERC721Fee.Part memory)
    {
        return auction[tokenId];
    }

    function cancel(uint256 tokenId) public {
        require(tokenSaleData[tokenId].collectableOwner == msg.sender, "Not owner of the token");
        require(
            auction[tokenId].account == address(0),
            "cannot cancel if bidding has started "
        );

        _incrementTokenNounce(tokenId);

        tokenerc721.transferFrom( tokenerc721.ownerOf(tokenId), tokenSaleData[tokenId].collectableOwner, tokenId);

        delete auction[tokenId];
        delete saleStatus[tokenId];
        delete sale[tokenId];

        emit Cancel(tokenId, getTokenNounce(tokenId));
    }

    function _incrementTokenNounce(uint256 tokenId) internal {
        // if (tokenerc721._exists(tokenId)) {
        tokenSaleData[tokenId].transactionNounce++;
        // }
    }

    function _checkPercentageValue(uint256 _value) internal virtual {
        require(_value <= 5000, "maintainer fee cannot exceed half");
    }

    function _setNftToken(NFTMarketplaceUpgradable _nfttoken) internal virtual{
        tokenerc721 = _nfttoken; 
    }

    function _setMaintainer(
        libERC721Fee.Part memory _maintainer,
        uint16 _maintainerInitialFee
    ) internal virtual {
        require(_maintainer.account != address(0));
        _checkPercentageValue(_maintainer.value);
        _checkPercentageValue(_maintainerInitialFee);
        maintainer = _maintainer;
        maintainerInitialFee = _maintainerInitialFee;
    }

    function updateMaintainer(
        libERC721Fee.Part memory _maintainer,
        uint16 _maintainerInitialFee
    ) public onlyAdmin {
        _setMaintainer(_maintainer, _maintainerInitialFee);
    }

    function updatemaintainerInitialFee(uint16 _value) public onlyAdmin {
        _checkPercentageValue(_value);
        maintainerInitialFee = _value;
    }

    function updateMaintainerValue(uint256 _value) public onlyAdmin {
        _checkPercentageValue(_value);
        maintainer.value = _value;
    }

    /**
     * @dev This funtion is to return maintainer account address
     *
     */
    function getMaintainer() public view returns (address) {
        return maintainer.account;
    }

    /**
     * @dev This funtion is to return maintainer fee (secondery sale)
     *
     */

    function getMaintainerValue() public view returns (uint256) {
        return maintainer.value;
    }

    /**
     * @dev This funtion is to return maintainer fee (primary sale)
     *
     */
    function getMaintainerInitialFee() public view returns (uint16) {
        return maintainerInitialFee;
    }

    function _setTokenSaleStatus(uint256 tokenId, uint256 status) internal {
        require(
            status == libERC721Fee.TYPE_DEFAULT ||
                status == libERC721Fee.TYPE_SALE ||
                status == libERC721Fee.TYPE_AUCTION,
            "Invalid token sale status"
        );

        saleStatus[tokenId] = status;
    }

    function _setBasePrice(uint256 tokenId, uint256 basePrice) internal {
        require(
            auction[tokenId].account == address(0),
            "The auction is not yet closed"
        );

        auction[tokenId].value = basePrice;
    }
    function _setSalePrice(uint256 tokenId, uint256 salePrice) internal {
        //sale active
        sale[tokenId].value = salePrice;
    }

    function _returnCurrentBid(uint256 tokenId) internal {
        address payable currentBidder = auction[tokenId].account;
        uint256 currentBid = auction[tokenId].value;

        if (currentBidder != address(0)) {
            currentBidder.transfer(currentBid);
        }
    }

    function _setBidder(
        uint256 tokenId,
        address payable bidder,
        uint256 amount
    ) internal {
        require(
            saleStatus[tokenId] == libERC721Fee.TYPE_AUCTION,
            "No active auction"
        );

        auction[tokenId].account = bidder;
        auction[tokenId].value = amount;
    }

    // As part of the lazy minting this mint function can be called by rootAdmin
    function mintAndTransfer(
        libERC721Fee.Part[] memory creators, 
        address receiver,
        uint256 collectableId,
        string memory IPFS_hash
    )
        public
        onlyMinter 
        nonReentrant
    {
        require(
            !_isShareExceedsHalf(creators),
            "Creators share shouldn't exceed half of price"
        );

        for (uint256 i = 0; i < creators.length; i++) {
            tokenSaleData[collectableId].creators.push(creators[i]);
        }

        NFTMarketplaceUpgradable.Royalties memory  royalties= NFTMarketplaceUpgradable.Royalties(creators[0].account, creators[0].value);
        
        NFTMarketplaceUpgradable(tokenerc721).mint(receiver, collectableId, IPFS_hash, royalties);
        emit Buy(address(0), receiver, collectableId, 0);
        tokenSaleData[collectableId].isSecondary = true;
    }

    function mintAndStartAuction(
        uint256 startingPrice,
        uint256 salePrice,
        libERC721Fee.Part[] memory creators,
        address payable collectableOwner,
        uint256 collectableId,
        string memory IPFS_hash
    ) public onlyMinter {
        require(
            !_isShareExceedsHalf(creators),
            "Creators share shouldn't exceed half of price"
        );

        for (uint256 i = 0; i < creators.length; i++) {
            tokenSaleData[collectableId].creators.push(creators[i]);
        }
        tokenSaleData[collectableId].collectableOwner = collectableOwner;
        // _mint(collectableOwner, collectableId);
        // _setTokenURI(collectableId, IPFS_hash);
        NFTMarketplaceUpgradable.Royalties memory  royalties= NFTMarketplaceUpgradable.Royalties(creators[0].account, creators[0].value);
        
        NFTMarketplaceUpgradable(tokenerc721).mint(address(this), collectableId, IPFS_hash, royalties);

        _setTokenSaleStatus(collectableId, libERC721Fee.TYPE_AUCTION);
        _setBasePrice(collectableId, startingPrice);
        _setSalePrice(collectableId, salePrice);

        emit StartAuction(collectableOwner, collectableId, startingPrice);
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     * 0 default, 1 sale, 2 auction
     */
    function onERC721Received(
        address , address _from, uint256 _tokenId, bytes memory  _data
    ) public virtual override returns (bytes4) {
        
        (uint saleType, uint basePrice , uint salePrice) = abi.decode(_data, (uint, uint, uint));

        if(saleType == 1){
             startSale (_from, salePrice, _tokenId);
        }else if(saleType == 2){
              startAuction(_from, basePrice, salePrice, _tokenId);  
        }
        
        return this.onERC721Received.selector;
    }
    
    function startAuction(address tokenOwner, uint256 startingPrice, uint256 salePrice, uint256 collectableId) internal {
        // require(
        //     tokenerc721.ownerOf(collectableId) == msg.sender,
        //     "Restricted to token Owner"
        // );

        _setTokenSaleStatus(collectableId, libERC721Fee.TYPE_AUCTION);
        _setBasePrice(collectableId, startingPrice);
        _setSalePrice(collectableId, salePrice);
        tokenSaleData[collectableId].collectableOwner =  payable(tokenOwner);

        emit StartAuction(tokenerc721.ownerOf(collectableId), collectableId, startingPrice);
    }
    function startSale(address tokenOwner, uint256 salePrice, uint256 collectableId) internal {
        // require(
        //     tokenerc721.ownerOf(collectableId) == msg.sender,
        //     "Restricted to token Owner"
        // );

        _setTokenSaleStatus(collectableId, libERC721Fee.TYPE_SALE);
        _setSalePrice(collectableId, salePrice);
        tokenSaleData[collectableId].collectableOwner = payable(tokenOwner);

        emit StartSale(tokenOwner, collectableId, salePrice);  
    }

    function bid(uint256 collectableId) public payable nonReentrant {
        require(
            saleStatus[collectableId] == libERC721Fee.TYPE_AUCTION,
            "There is no active auction"
        );
        require(
            msg.value > auction[collectableId].value,
            "Insufficient fund to make a bid"
        );
        // require(!msg.sender.isContract(), "Contracts cannot do bidding");

        _returnCurrentBid(collectableId);
        _setBidder(collectableId, payable(msg.sender), msg.value);

        emit Bid(collectableId, msg.sender, msg.value);
    }

    function placeBid(
        uint256 collectableId,
        uint256 nounce
    ) public payable onlyAdmin nonReentrant {
        require(
            (getTokenNounce(collectableId) + 1) == nounce,
            "Invalid nounce"
        );

        // When there is no active bidding, return the asset to the owner
        // else transfer the asset to the heigest bidder and initiate the payout process
        if(auction[collectableId].account == address(0)){
            tokenerc721.transferFrom(
                tokenerc721.ownerOf(collectableId),
                tokenSaleData[collectableId].collectableOwner,
                collectableId
            );
        } else {
            tokenerc721.transferFrom(
                tokenerc721.ownerOf(collectableId),
                auction[collectableId].account,
                collectableId
            );
            _payout(collectableId, auction[collectableId].value);
        }


        emit PlaceBid(
            tokenSaleData[collectableId].collectableOwner,
            auction[collectableId].account,
            collectableId,
            auction[collectableId].value
        );
        // _safeTransfer(
        //     ownerOf(collectableId),
        //     auction[collectableId].account,
        //     collectableId,
        //     ""
        // );
        _incrementTokenNounce(collectableId);
        delete saleStatus[collectableId];
        delete auction[collectableId];
    }

    function buy(
        address receiver,
        uint256 collectableId,
        uint256 nounce,
        uint256 purchaseType
    ) public payable nonReentrant {
        require(msg.value >= sale[collectableId].value, "Insufficient fund to purchase token");
        require(
            (getTokenNounce(collectableId) + 1) == nounce,
            "Invalid nounce"
        );

        if (purchaseType == libERC721Fee.TYPE_AUCTION) {
            _returnCurrentBid(collectableId);
            delete saleStatus[collectableId];
            delete auction[collectableId];
        } else {
            require(
                purchaseType == libERC721Fee.TYPE_SALE,
                "Invalid purchase type"
            );
        }

        _payout(collectableId, sale[collectableId].value);
        emit Buy(tokenSaleData[collectableId].collectableOwner, receiver, collectableId, sale[collectableId].value);
        tokenerc721.transferFrom( tokenerc721.ownerOf(collectableId), receiver, collectableId);
        // _safeTransfer(ownerOf(collectableId), receiver, collectableId, "");
        _incrementTokenNounce(collectableId);
        delete sale[collectableId];
    }

    function _payout(uint256 collectableId, uint256 price) internal {
        uint256 creatorsPayment;
        uint256 maintainerPayment;
        uint256 ownerPayout = price;
        libERC721Fee.Part[] storage creators = tokenSaleData[collectableId]
            .creators;

        if (tokenSaleData[collectableId].isSecondary) {
            maintainerPayment = price.mul(maintainer.value).div(10000);

            for (uint256 i = 0; i < creators.length; i++) {
                creatorsPayment = price.mul(creators[i].value).div(10000);
                ownerPayout = ownerPayout.sub(creatorsPayment);
                creators[i].account.transfer(creatorsPayment);
            }
        } else {
            maintainerPayment = price.mul(maintainerInitialFee).div(10000);

            if (creators.length >= 0) {
                creatorsPayment = price.sub(maintainerPayment).div(
                    creators.length
                );
            }
            for (uint256 i = 0; i < creators.length; i++) {
                ownerPayout = ownerPayout.sub(creatorsPayment);
                creators[i].account.transfer(creatorsPayment);
            }

            tokenSaleData[collectableId].isSecondary = true;
        }

        if (maintainer.account != address(0)) {
            maintainer.account.transfer(maintainerPayment);
            ownerPayout = ownerPayout.sub(maintainerPayment);
        }

        payable(tokenSaleData[collectableId].collectableOwner).transfer(ownerPayout);
        // payable(tokenerc721.ownerOf(collectableId)).transfer(ownerPayout);
    }

    function _isShareExceedsHalf(libERC721Fee.Part[] memory creators)
        internal
        pure
        returns (bool)
    {
        uint256 accumulatedShare;
        for (uint256 i = 0; i < creators.length; i++) {
            accumulatedShare = accumulatedShare + creators[i].value;
        }
        return accumulatedShare > 5000;
    }
}
