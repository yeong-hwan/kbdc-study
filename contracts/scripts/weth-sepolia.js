var hre = require("hardhat");

/**
 * 사용법 (sepolia):
 * - contracts/.env 에 WETH_ADDRESS 를 설정하세요.
 * - 이 스크립트는 Hardhat CLI의 인자 파싱 이슈를 피하려고 node로 직접 실행합니다.
 *
 * 예)
 *   pnpm -C contracts weth:sepolia status
 *   pnpm -C contracts weth:sepolia deposit 0.01
 *   pnpm -C contracts weth:sepolia withdraw 0.01
 *
 * 주의)
 * - amount는 "ETH 단위 문자열"입니다. (예: 0.01 => 0.01 ETH / 0.01 WETH)
 * - withdraw는 내 지갑이 WETH를 보유하고 있어야 합니다.
 */

function requireEnv(name) {
  var value = process.env[name];
  if (!value) {
    throw new Error(
      name + " 이(가) 비어있습니다. contracts/.env 에 설정하세요."
    );
  }
  return value;
}

function parseArgs() {
  // node scripts/weth-sepolia.js <action> <amount>
  // 과거 hardhat run -- <args> 형태도 호환하려고 "--"가 있으면 그 뒤를 사용합니다.
  var argv = process.argv;
  var idx = argv.indexOf("--");
  var args = idx >= 0 ? argv.slice(idx + 1) : argv.slice(2);

  var action = (args[0] || "status").toLowerCase();
  var amountEth = args[1]; // optional
  return { action, amountEth };
}

function printStatus(weth, me) {
  return Promise.all([
    hre.ethers.provider.getBalance(me.address),
    weth.balanceOf(me.address),
    weth.totalSupply(),
  ]).then(function (res) {
    var eth = res[0];
    var wethBal = res[1];
    var supply = res[2];

    console.log("Signer:", me.address);
    console.log("ETH:", hre.ethers.formatEther(eth));
    console.log("WETH:", hre.ethers.formatEther(wethBal));
    console.log("WETH totalSupply:", hre.ethers.formatEther(supply));
  });
}

function main() {
  var wethAddress = requireEnv("WETH_ADDRESS");
  var parsed = parseArgs();
  var action = parsed.action;
  var amountEth = parsed.amountEth;

  return hre.ethers.getSigners().then(function (signers) {
    var me = signers[0];
    return hre.ethers.getContractAt("WETH", wethAddress).then(function (weth) {
      return weth.getAddress().then(function (address) {
        console.log("WETH:", address);
        console.log("Action:", action);

        if (action === "status") {
          return printStatus(weth, me);
        }

        if (!amountEth) {
          throw new Error("amount가 필요합니다. 예: deposit 0.01");
        }
        var amount = hre.ethers.parseEther(amountEth);

        if (action === "deposit") {
          // deposit()에 value를 같이 보내면, 동일 수량의 WETH가 민팅됩니다.
          console.log("Deposit amount(ETH):", amountEth);
          return weth
            .connect(me)
            .deposit({ value: amount })
            .then(function (tx) {
              console.log("tx:", tx.hash);
              return tx.wait();
            })
            .then(function () {
              return printStatus(weth, me);
            });
        }

        if (action === "withdraw") {
          // withdraw()는 내 WETH를 소각하고 동일 수량의 ETH를 내 주소로 보냅니다.
          console.log("Withdraw amount(WETH):", amountEth);
          return weth
            .connect(me)
            .withdraw(amount)
            .then(function (tx) {
              console.log("tx:", tx.hash);
              return tx.wait();
            })
            .then(function () {
              return printStatus(weth, me);
            });
        }

        throw new Error(
          "지원하지 않는 action 입니다: " +
            action +
            " (status|deposit|withdraw)"
        );
      });
    });
  });
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
