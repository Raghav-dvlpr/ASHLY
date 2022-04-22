const { deployProxy } = require('@openzeppelin/truffle-upgrades');


// const NFTMarketplace = artifacts.require('NFTMarketplaceUpgradableV2');

// module.exports = async function (deployer, network, accounts) {
//     const rootAdmin = accounts[0];
//   await deployProxy(NFTMarketplace, ["VarsityGem", "VG", "https://gateway.pinata.cloud/ipfs/",  "0x1f6ceaa4d3ef6e16d113adc8080320de2d5d8499",true], { deployer });
// };

//0x3Ad77f18E61BC4FC18B3BA56670248d2628415fa

const NFTMarketplace = artifacts.require('McFaydenNFTMarketplaceUpgradable');
// rootadmin, [maintainer address, sendery cmmission in 2 decimals], primary commission in 2 decimals, nft contract address
module.exports = async function (deployer, network, accounts) {
    const rootAdmin = accounts[0];
    await deployProxy(NFTMarketplace, ["0x1f6ceaa4d3ef6e16d113adc8080320de2d5d8499", ["0xDfAd87e691A73d8EA78198D753e1B7Fd0051d431", 200], 200, "0x3Ad77f18E61BC4FC18B3BA56670248d2628415fa"], { deployer });
    //await deployProxy(NFTMarketplace, ["0x31ffdfad5068ad6db7f128932b25b6be05edd0a7", ["0x160550402eFeA97388a2961145971b76AEd832eb", 200], 200, "0xa3769b140b1ae0d6c2ccbb636e286879a0285060"], { deployer });
};

//0xf17e5b54ed02f8f5E4dc1528b35A507bE702FD5B
