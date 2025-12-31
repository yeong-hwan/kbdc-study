const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("WETH", function () {
  it("deposit: ETH 예치하면 동일 수량의 WETH 민팅", async function () {
    const [user] = await ethers.getSigners();
    const WETH = await ethers.getContractFactory("WETH");
    const weth = await WETH.deploy();
    await weth.waitForDeployment();

    const amount = ethers.parseEther("0.01");
    await expect(weth.connect(user).deposit({ value: amount }))
      .to.emit(weth, "Deposit")
      .withArgs(user.address, amount);

    expect(await weth.balanceOf(user.address)).to.equal(amount);
    expect(await weth.totalSupply()).to.equal(amount);
  });

  it("receive: ETH를 직접 전송해도 deposit과 동일하게 민팅", async function () {
    const [user] = await ethers.getSigners();
    const WETH = await ethers.getContractFactory("WETH");
    const weth = await WETH.deploy();
    await weth.waitForDeployment();

    const amount = ethers.parseEther("0.02");
    await expect(
      user.sendTransaction({ to: await weth.getAddress(), value: amount })
    )
      .to.emit(weth, "Deposit")
      .withArgs(user.address, amount);

    expect(await weth.balanceOf(user.address)).to.equal(amount);
  });

  it("withdraw: WETH 소각하면 동일 수량의 ETH 반환", async function () {
    const [user] = await ethers.getSigners();
    const WETH = await ethers.getContractFactory("WETH");
    const weth = await WETH.deploy();
    await weth.waitForDeployment();

    const amount = ethers.parseEther("0.03");
    await weth.connect(user).deposit({ value: amount });

    // withdraw는 gas를 쓰므로 정확히 동일 잔액 비교는 어렵고, 이벤트/상태 위주로 검증
    await expect(weth.connect(user).withdraw(amount))
      .to.emit(weth, "Withdrawal")
      .withArgs(user.address, amount);

    expect(await weth.balanceOf(user.address)).to.equal(0n);
    expect(await weth.totalSupply()).to.equal(0n);
  });

  it("ERC20: approve/transferFrom 동작", async function () {
    const [owner, spender, receiver] = await ethers.getSigners();
    const WETH = await ethers.getContractFactory("WETH");
    const weth = await WETH.deploy();
    await weth.waitForDeployment();

    const amount = ethers.parseEther("1");
    const spend = ethers.parseEther("0.4");
    await weth.connect(owner).deposit({ value: amount });

    await expect(weth.connect(owner).approve(spender.address, spend))
      .to.emit(weth, "Approval")
      .withArgs(owner.address, spender.address, spend);

    await expect(
      weth.connect(spender).transferFrom(owner.address, receiver.address, spend)
    )
      .to.emit(weth, "Transfer")
      .withArgs(owner.address, receiver.address, spend);

    expect(await weth.balanceOf(receiver.address)).to.equal(spend);
    expect(await weth.allowance(owner.address, spender.address)).to.equal(0n);
  });
});


