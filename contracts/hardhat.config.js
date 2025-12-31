require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// .env에서 읽어옵니다.
// - SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/...
// - PRIVATE_KEY=0x...
const { SEPOLIA_RPC_URL, PRIVATE_KEY } = process.env;

// Sepolia 배포 실행 시점에 누락된 환경변수를 더 친절하게 안내합니다.
// (Hardhat 기본 에러 HH117은 원인 파악이 어려울 수 있습니다.)
const is_sepolia = process.env.HARDHAT_NETWORK === "sepolia";
if (is_sepolia) {
  if (!SEPOLIA_RPC_URL) {
    throw new Error(
      [
        "SEPOLIA_RPC_URL 이(가) 비어있습니다.",
        "- contracts/.env 에 SEPOLIA_RPC_URL 을 설정하세요.",
        "- 예: SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/<KEY>",
      ].join("\n")
    );
  }
  if (!PRIVATE_KEY) {
    throw new Error(
      [
        "PRIVATE_KEY 이(가) 비어있습니다.",
        "- contracts/.env 에 PRIVATE_KEY 를 설정하세요. (0x로 시작)",
      ].join("\n")
    );
  }
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  // Etherscan에서 Contract 소스코드가 보이려면 verify가 필요합니다.
  // contracts/.env 의 ETHERSCAN_API_KEY 를 사용합니다.
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  },
  networks: {
    // 기본 하드햇 로컬 네트워크는 별도 설정 없이 사용 가능
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
  },
};
