Frist Compile the contracts

Second: 
1 - Deploy the NFT Marketplace V2 Contract in rinkeby
2 - Deploy the McFaydenNFT Contract in rinkeby

Third :
1 - Load the NFT Marketplace V2 contract in Remix and complie to contract to get abi.... After that paste the contract Address.
2 - After we got the contract instance of the NFT Marketplace V2 paste the McFaydenNFT Contract Address in 
    addminterorpauser function and provide minter role that contract........
3 - Load the McFaydenNFT Contract in Remix and complie to contract to get abi.... After that paste the contract Address.

Fourth:
1 - After we got the contract instance of the McFaydenNFT Contract, Then click mintStartAuction Function to start the auction
    Once Auction started users can start bid the NFT.
2 - If user 1 bided on token for 14 wei then user 2 must be bid above 14 wei only [15 wei or 16 wei], if user 2 try to bid less it will throw error...
3 - If the once more again user 1 is bided higher value than another user then previous user 1 bided amount [14 wei] will be sent back to
    user 1's Wallet..... 
4 - If we want to end the auction click placebid function, that will end the auction and who has highest bid value will recive the token..

5 - Acution will get ended