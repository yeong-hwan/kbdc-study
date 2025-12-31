var hre = require("hardhat");

function requireEnv(name) {
  var value = process.env[name];
  if (!value) {
    throw new Error(
      name + " 이(가) 비어있습니다. contracts/.env 에 설정하세요."
    );
  }
  return value;
}

function main() {
  // contracts/hardhat.config.js에서 dotenv를 이미 로드합니다.
  var address = requireEnv("WETH_ADDRESS");

  console.log("Verifying WETH contract...");
  console.log("Network:", hre.network.name);
  console.log("Address:", address);

  // WETH는 constructor가 없으므로 constructorArguments는 빈 배열입니다.
  return hre
    .run("verify:verify", {
      address: address,
      constructorArguments: [],
    })
    .then(function () {
      console.log("Done.");
    });
}

main().catch(function (err) {
  console.error(err);
  process.exitCode = 1;
});
