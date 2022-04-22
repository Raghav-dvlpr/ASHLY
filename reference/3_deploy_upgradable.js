// const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

// const NFTMarketplace = artifacts.require('ERC721PresetMinterPauserUpgradeable');
// const NFTMarketplaceV2 = artifacts.require('ERC721PresetMinterPauserUpgradeableV2');

// module.exports = async function (deployer) {
//   const existing = await NFTMarketplace.deployed();
//   await upgradeProxy(existing.address, NFTMarketplaceV2, { deployer });
// };