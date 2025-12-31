const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Deployer ETH:", hre.ethers.formatEther(balance));

  const WETH = await hre.ethers.getContractFactory("WETH");
  const weth = await WETH.deploy();
  await weth.waitForDeployment();

  const address = await weth.getAddress();
  console.log("WETH deployed to:", address);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});


