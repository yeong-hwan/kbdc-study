require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// .env에서 읽어옵니다.
// - SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/...
// - PRIVATE_KEY=0x...
const { SEPOLIA_RPC_URL, PRIVATE_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks: {
    // 기본 하드햇 로컬 네트워크는 별도 설정 없이 사용 가능
    sepolia: {
      url: SEPOLIA_RPC_URL || "",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
  },
};
