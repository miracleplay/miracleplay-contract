/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 300,
      },
    },
  },
  paths: {
    sources: "./contract/SLG-Token-Staking/",
  },
};
