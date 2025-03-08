require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.13",
  networks: {
    hardhat: {
      accounts: {
        count: 10, // Number of accounts to generate
        accountsBalance: "10000000000000000000000" // 10000 ETH
      }
    },
    mainnet: {
      url: process.env.SONIC_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 146
    }
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.SONIC_EXPLORER_API_KEY
    }
  }
};
