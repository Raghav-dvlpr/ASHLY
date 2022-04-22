// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// library functions
// library can be called directly and they can't modify the state variables
// Reduces Gas Cost
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
        bool isSecondary;
    }
}

// interface from NFTMarketplaceUpgradableV2 contract 
// with the help of this interface we can call Royalties, Mint and transfer from Funcationalites of that contract
interface NFTMarketplaceUpgradable {
    struct Royalties {
        address payable account;
        uint256 percentage;
    }

    function mint(
        address receiver,
        uint256 collectibleId,
        string memory IPFSHash,
        Royalties calldata royalties
    ) external;

    function ownerOf(uint256 _tokenId) external view returns (address);

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;
}

contract McFaydenNFTMarketplaceUpgradable is
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
        __McFaydenNFTMarketplaceUpgradable_init(
            rootAdmin,
            _maintainer,
            _maintainerInitialFee,
            _tokenerc721
        );
    }

    // Access Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function __McFaydenNFTMarketplaceUpgradable_init(
        address rootAdmin,
        libERC721Fee.Part memory _maintainer,
        uint16 _maintainerInitialFee,
        NFTMarketplaceUpgradable _tokenerc721
    ) internal initializer {
        __McFaydenNFTMarketplaceUpgradable_init_unchained(
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

    function __McFaydenNFTMarketplaceUpgradable_init_unchained(
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

    // Mappings
    mapping(uint256 => libERC721Fee.Data) private tokenSaleData; // mapping the token and the data to Data Struct in libERC721
    mapping(uint256 => uint256) private saleStatus; // mapping token id with Auction Type
    mapping(uint256 => libERC721Fee.Part) auction; // for which token pepole auctioning and bided value for particular token.
    mapping(uint256 => libERC721Fee.Part) sale; //for which token pepole particpating for sale
    libERC721Fee.Part private maintainer; // maintainer is platform admin to get some commisson on each token.
    uint16 private maintainerInitialFee; //setting up maintainer initial fee

    // interface Varibale declaration
    NFTMarketplaceUpgradable private tokenerc721; // t interact minit with NFT marketplace v2 contract.

    // event is called when emit is happend on specific function.
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
    event Cancel(uint256 indexed tokenId);

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
        if (role == ADMIN_ROLE)
            require(
                getRoleMemberCount(ADMIN_ROLE) == 0,
                "exactly one address can have admin role"
            );

        super.grantRole(role, account);
    }

    /**
     * @dev modifier to check admin rights.
     * contract owner and root admin have admin rights
     */
    modifier onlyAdmin() {
        require(
            hasRole(ADMIN_ROLE, _msgSender()) || owner() == _msgSender(),
            "Restricted to admin."
        );
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
                owner() == _msgSender(),
            "Restricted to minter."
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
    function addMinter(address account, bytes32 role) public onlyAdmin {
        if (role == MINTER_ROLE) _setupRole(role, account);
    }


    // it shows current bid value of particular token in auction
    function getCurrentBid(uint256 tokenId)
        public
        view
        returns (libERC721Fee.Part memory)
    {
        return auction[tokenId];
    }


   // this function is used to cancle the bided token
   // and transfer the token to token with help tranferFrom from NFTMarketplaceUpgradableV2 contract interface..
   // and delete the data from auction,salestatus and sale mappings..
    function cancel(uint256 tokenId) public {
        require(
            tokenSaleData[tokenId].collectableOwner == msg.sender,
            "Not owner of the token"
        );
        require(
            auction[tokenId].account == address(0),
            "cannot cancel if bidding has started "
        );

        tokenerc721.transferFrom(
            tokenerc721.ownerOf(tokenId),
            tokenSaleData[tokenId].collectableOwner,
            tokenId
        );

        delete auction[tokenId];
        delete saleStatus[tokenId];
        delete sale[tokenId];

        emit Cancel(tokenId);
    }

    // This will check the initial value and percentage value for maintainer
    function _checkPercentageValue(uint256 _value) internal virtual {
        require(_value <= 5000, "maintainer fee cannot exceed half");
    }

    // Interface the TokeniD TO Nft marketplace upgradeable contract..
    function _setNftToken(NFTMarketplaceUpgradable _nfttoken) internal virtual {
        tokenerc721 = _nfttoken;
    }

    // It shows NFT marketplace V2 Contract Address
    function gettNftAddress() view public returns(NFTMarketplaceUpgradable) { 
        return tokenerc721; 
    }

    // This will set the value and Initialfee for maintainer address
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

    /**
     * @dev This funtion is to update maintainer account address,
     * primary commission percentage and secondery commission percentage.
     */
    function updateMaintainer(
        libERC721Fee.Part memory _maintainer,
        uint16 _maintainerInitialFee
    ) public onlyAdmin {
        _setMaintainer(_maintainer, _maintainerInitialFee);
    }

    /**
     * @dev This funtion is to update primary commission percentage.
     */

    function updatemaintainerInitialFee(uint16 _value) public onlyAdmin {
        _checkPercentageValue(_value);
        maintainerInitialFee = _value;
    }

    /**
     * @dev This funtion is to update Secondery commission percentage.
     */

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

    /**
     * @dev This funtion is to return current bidder, current bid, buy now price of auction with tokenId
     *
     */

    function getAuctionDetails(uint256 collectableId)
        public
        view
        returns (
            address,
            uint256,
            uint256,
            address
        )
    {
        return (
            auction[collectableId].account,
            auction[collectableId].value,
            sale[collectableId].value,
            tokenSaleData[collectableId].collectableOwner
        );
    }
    // this will set token sale status..
    function _setTokenSaleStatus(uint256 tokenId, uint256 status) internal {
        require(
            status == libERC721Fee.TYPE_DEFAULT ||
                status == libERC721Fee.TYPE_SALE ||
                status == libERC721Fee.TYPE_AUCTION,
            "Invalid token sale status"
        );
        saleStatus[tokenId] = status;
    }
    // this will set base price (Staring Price) for each token
    function _setBasePrice(uint256 tokenId, uint256 basePrice) internal {
        require(
            auction[tokenId].account == address(0),
            "The auction is not yet closed"
        );

        auction[tokenId].value = basePrice;
    }
    // this will set Sale price(Final Price) for each token 
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
    // This will added bidder account and value to the for specific token in auction mappping..
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
    ) public onlyMinter nonReentrant {
        require(
            !_isShareExceedsHalf(creators),
            "Creators share shouldn't exceed half of price"
        );

        for (uint256 i = 0; i < creators.length; i++) {
            tokenSaleData[collectableId].creators.push(creators[i]);
        }

        NFTMarketplaceUpgradable.Royalties
            memory royalties = NFTMarketplaceUpgradable.Royalties(
                creators[0].account,
                creators[0].value
            );

        NFTMarketplaceUpgradable(tokenerc721).mint(
            receiver,
            collectableId,
            IPFS_hash,
            royalties
        );
        emit Buy(address(0), receiver, collectableId, 0);
        tokenSaleData[collectableId].isSecondary = true;
    }

    // As part of the offchain sale this transfer function can be called by rootAdmin
    function transferAsset(uint256 collectableId, address receiver)
        public
        onlyMinter
        nonReentrant
    {
        emit Buy(
            tokenSaleData[collectableId].collectableOwner,
            receiver,
            collectableId,
            0
        );
        tokenerc721.transferFrom(
            tokenerc721.ownerOf(collectableId),
            receiver,
            collectableId
        );
        delete sale[collectableId];
    }

    // Mint the token and start auction
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
         // adds token to tokensaledata mapping
        for (uint256 i = 0; i < creators.length; i++) {
            tokenSaleData[collectableId].creators.push(creators[i]);
        }
        tokenSaleData[collectableId].collectableOwner = collectableOwner;

           // setup's royalties using NFTMarketplaceUpgradableV2 interface
        NFTMarketplaceUpgradable.Royalties
            memory royalties = NFTMarketplaceUpgradable.Royalties(
                creators[0].account,
                creators[0].value
            );

         // started mint using NFTMarketplaceUpgradableV2 interface
        NFTMarketplaceUpgradable(tokenerc721).mint(
            address(this),
            collectableId,
            IPFS_hash,
            royalties
        );

        _setTokenSaleStatus(collectableId, libERC721Fee.TYPE_AUCTION); // setting up token sale status types
        _setBasePrice(collectableId, startingPrice); //setting up base price for token
        _setSalePrice(collectableId, salePrice); //setting up sale price for token

        emit StartAuction(collectableOwner, collectableId, startingPrice);
    }

    // mint the toekn and start token for sale
    function mintAndStartSale(
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
        // adds token to tokensaledata mapping
        for (uint256 i = 0; i < creators.length; i++) {
            tokenSaleData[collectableId].creators.push(creators[i]);
        }
        tokenSaleData[collectableId].collectableOwner = collectableOwner;

        // setup's royalties using NFTMarketplaceUpgradableV2 interface
        NFTMarketplaceUpgradable.Royalties
            memory royalties = NFTMarketplaceUpgradable.Royalties(
                creators[0].account,
                creators[0].value
            );

        // started mint using NFTMarketplaceUpgradableV2 interface
        NFTMarketplaceUpgradable(tokenerc721).mint(
            address(this),
            collectableId,
            IPFS_hash,
            royalties
        );

        _setTokenSaleStatus(collectableId, libERC721Fee.TYPE_SALE);// setting up token sale status types
        _setSalePrice(collectableId, salePrice); //setting up sale price for token

        emit StartSale(collectableOwner, collectableId, salePrice);
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     * 0 default, 1 sale, 2 auction
     */
    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) public virtual override returns (bytes4) {
        (uint256 saleType, uint256 basePrice, uint256 salePrice) = abi.decode(
            _data,
            (uint256, uint256, uint256)
        );

        if (saleType == 1) {
            startSale(_from, salePrice, _tokenId);
        } else if (saleType == 2) {
            startAuction(_from, basePrice, salePrice, _tokenId);
        }

        return this.onERC721Received.selector;
    }
    // this will start auction for specific token
    function startAuction(
        address tokenOwner,
        uint256 startingPrice,
        uint256 salePrice,
        uint256 collectableId
    ) internal {
        _setTokenSaleStatus(collectableId, libERC721Fee.TYPE_AUCTION);
        _setBasePrice(collectableId, startingPrice);
        _setSalePrice(collectableId, salePrice);
        tokenSaleData[collectableId].collectableOwner = payable(tokenOwner);

        emit StartAuction(
            tokenerc721.ownerOf(collectableId),
            collectableId,
            startingPrice
        );
    }
    // This will start sale for specific token [This is also part of Reseller]
    function startSale(
        address tokenOwner,
        uint256 salePrice,
        uint256 collectableId
    ) internal {
        _setTokenSaleStatus(collectableId, libERC721Fee.TYPE_SALE);
        _setSalePrice(collectableId, salePrice);
        tokenSaleData[collectableId].collectableOwner = payable(tokenOwner);

        emit StartSale(tokenOwner, collectableId, salePrice);
    }

    // this function will bidding users to the list . 
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

    // this function is used to close the bidding of specific token..
    function placeBid(uint256 collectableId)
        public
        payable
        onlyAdmin
        nonReentrant
    {
        // When there is no active bidding, return the asset to the owner
        // else transfer the asset to the heigest bidder and initiate the payout process
        if (auction[collectableId].account == address(0)) {
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

        delete saleStatus[collectableId];
        delete auction[collectableId];
    }
    // this function used to buy a token if it is in Sale 
    // after token is sold the commisioms are given to specfic address with the help of payout function
    function buy(
        address receiver,
        uint256 collectableId,
        uint256 purchaseType
    ) public payable nonReentrant {
        require(
            sale[collectableId].value > 0,
            "This operation not permitted for this asset"
        );
        require(
            msg.value >= sale[collectableId].value,
            "Insufficient fund to purchase token"
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
        // thsi function will give pay commission..
        _payout(collectableId, sale[collectableId].value);
        emit Buy(
            tokenSaleData[collectableId].collectableOwner,
            receiver,
            collectableId,
            sale[collectableId].value
        );
        tokenerc721.transferFrom(
            tokenerc721.ownerOf(collectableId),
            receiver,
            collectableId
        );
        delete sale[collectableId];
    }
    // this function will be called when buy function is called
    // this function gives the commission to creator[admin], maintainer[Platform admin] and owner[Token Owner]
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

        payable(tokenSaleData[collectableId].collectableOwner).transfer(
            ownerPayout
        );
    }

    // It will true or false of token creator if share price is exceed half or not 
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
