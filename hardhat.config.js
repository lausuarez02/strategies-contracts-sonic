require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.13",
  networks: {
    hardhat: {
      accounts: {
        count: 10, // Number of accounts to generate
        accountsBalance: "10000000000000000000000" // 10000 ETH
      }
    }
  }
};
