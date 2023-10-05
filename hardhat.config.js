require("@nomicfoundation/hardhat-toolbox");

const { mnemonic } = require('./secrets.json');

/** @type import('hardhat/config').HardhatUserConfig */

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});


module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
        optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    gaussTestnet: {
      url: "https://rpc.giltestnet.com",
      chainId: 1452,
      accounts: {mnemonic: mnemonic}
    },
    gaussMainnet: {
      url: "https://rpc.gaussgang.com",
      chainId: 1777,
      accounts: {mnemonic: mnemonic}
    },
    polygonTestnet: {
      url: "https://polygon-mumbai-bor.publicnode.com	",
      chainId: 80001,
      accounts: {mnemonic: mnemonic}
    },
    polygonMainnet: {
      url: "https://polygon-bor.publicnode.com",
      chainId: 137,
      accounts: {mnemonic: mnemonic}
    },
    hardhat: {
      chainId: 1452
    }
  }
};