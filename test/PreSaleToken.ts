import {
  loadFixture,
  time,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { PreSaleToken, PreSaleToken__factory } from "../typechain-types";

describe("PreSaleToken", function () {
  const NAME = "My Token";
  const SYMBOL = "MTK";
  const INITIAL_SUPPLY = 1_000_000;
  const TOKEN_PRICE = hre.ethers.parseEther("0.01");
  const SALE_DURATION = 3600; // 1h
  const MIN_PURCHASE = hre.ethers.parseEther("0.1");
  const MAX_PURCHASE = hre.ethers.parseEther("1.0");

  type Fixture = {
    presale: PreSaleToken;
    owner: SignerWithAddress;
    buyer: SignerWithAddress;
    other: SignerWithAddress;
  };

  async function deployPresaleFixture(): Promise<Fixture> {
    const [owner, buyer, other] =
      (await hre.ethers.getSigners()) as SignerWithAddress[];
    const factory = new PreSaleToken__factory(owner);
    const presale = await factory.deploy(
      NAME,
      SYMBOL,
      INITIAL_SUPPLY,
      TOKEN_PRICE,
      SALE_DURATION,
      MIN_PURCHASE,
      MAX_PURCHASE
    );
    await presale.waitForDeployment();
    return { presale, owner, buyer, other };
  }

  describe("Constructor & Events", function () {
    it("emits TokensSeeded & SaleInitialized", async function () {
      const { presale, owner } = await loadFixture(deployPresaleFixture);

      // Assertion on deployment transaction
      await expect(presale.deploymentTransaction())
        .to.emit(presale, "TokensSeeded")
        .withArgs(owner.address, await presale.totalSupply());

      await expect(presale.deploymentTransaction())
        .to.emit(presale, "SaleInitialized")
        .withArgs(
          TOKEN_PRICE,
          await presale.saleStart(),
          await presale.saleEnd(),
          MIN_PURCHASE,
          MAX_PURCHASE,
          await presale.totalSupply()
        );
    });
  });

  describe("buyTokens & receive()", function () {
    it("reverts below minimum", async function () {
      const { presale, buyer } = await loadFixture(deployPresaleFixture);
      await expect(
        presale.connect(buyer).buyTokens({ value: MIN_PURCHASE - 1n })
      ).to.be.revertedWithCustomError(presale, "BelowMinimum");
    });

    it("reverts above maximum", async function () {
      const { presale, buyer } = await loadFixture(deployPresaleFixture);
      await expect(
        presale.connect(buyer).buyTokens({ value: MAX_PURCHASE + 1n })
      ).to.be.revertedWithCustomError(presale, "AboveMaximum");
    });

    it("allows purchase via buyTokens()", async function () {
      const { presale, buyer } = await loadFixture(deployPresaleFixture);
      const spend = hre.ethers.parseEther("0.2");
      const dec = await presale.decimals();
      const mul = 10n ** BigInt(dec);
      const expected = (spend * mul) / TOKEN_PRICE;

      await expect(presale.connect(buyer).buyTokens({ value: spend }))
        .to.emit(presale, "ReceivedETH")
        .withArgs(buyer.address, spend)
        .and.to.emit(presale, "TokensPurchased")
        .withArgs(buyer.address, spend, expected);

      expect(await presale.totalRaised()).to.equal(spend);
      expect(await presale.balanceOf(buyer.address)).to.equal(expected);
    });

    it("allows purchase via receive()", async function () {
      const { presale, buyer } = await loadFixture(deployPresaleFixture);
      const spend = hre.ethers.parseEther("0.3");
      const dec = await presale.decimals();
      const mul = 10n ** BigInt(dec);
      const expected = (spend * mul) / TOKEN_PRICE;

      await expect(buyer.sendTransaction({ to: presale.target, value: spend }))
        .to.emit(presale, "ReceivedETH")
        .withArgs(buyer.address, spend)
        .and.to.emit(presale, "TokensPurchased")
        .withArgs(buyer.address, spend, expected);

      expect(await presale.balanceOf(buyer.address)).to.equal(expected);
    });
  });

  describe("finalizeSale", function () {
    it("reverts too early or on replay", async function () {
      const { presale } = await loadFixture(deployPresaleFixture);
      await expect(presale.finalizeSale()).to.be.revertedWithCustomError(
        presale,
        "SaleNotEnded"
      );
      await time.increase(SALE_DURATION + 1);
      await presale.finalizeSale();
      await expect(presale.finalizeSale()).to.be.revertedWithCustomError(
        presale,
        "AlreadyFinalized"
      );
    });
  });

  describe("Transfer locking & views", function () {
    it("blocks transfers until finalized", async function () {
      const { presale, buyer, other } = await loadFixture(deployPresaleFixture);
      const spend = hre.ethers.parseEther("0.2");
      await presale.connect(buyer).buyTokens({ value: spend });
      await expect(
        presale.connect(buyer).transfer(other.address, 1n)
      ).to.be.revertedWithCustomError(presale, "Locked");
    });

    it("allows transfers after finalize", async function () {
      const { presale, buyer, other } = await loadFixture(deployPresaleFixture);
      const spend = hre.ethers.parseEther("0.2");
      await presale.connect(buyer).buyTokens({ value: spend });
      await time.increase(SALE_DURATION + 1);
      await presale.finalizeSale();
      await presale.connect(buyer).transfer(other.address, 1n);
      expect(await presale.balanceOf(other.address)).to.equal(1n);
    });

    it("blocks transferFrom until finalized", async function () {
      const { presale, buyer, other } = await loadFixture(deployPresaleFixture);
      const spend = hre.ethers.parseEther("0.2");
      await presale.connect(buyer).buyTokens({ value: spend });
      // buyer must approve first
      await presale.connect(buyer).approve(other.address, 1n);
      await expect(
        presale.connect(other).transferFrom(buyer.address, other.address, 1n)
      ).to.be.revertedWithCustomError(presale, "Locked");
    });

    it("allows transferFrom after finalize", async function () {
      const { presale, buyer, other } = await loadFixture(deployPresaleFixture);
      const spend = hre.ethers.parseEther("0.2");
      await presale.connect(buyer).buyTokens({ value: spend });
      await presale.connect(buyer).approve(other.address, 1n);
      await time.increase(SALE_DURATION + 1);
      await presale.finalizeSale();
      // now it succeeds
      await presale
        .connect(other)
        .transferFrom(buyer.address, other.address, 1n);
      expect(await presale.balanceOf(other.address)).to.equal(1n);
    });

    it("returns zero for timeRemaining after saleEnd", async function () {
      const { presale } = await loadFixture(deployPresaleFixture);
      // fast-forward past end
      await time.increase(SALE_DURATION + 1);
      expect(await presale.timeRemaining()).to.equal(0n);
    });

    it("reports timeRemaining & tokensAvailable correctly", async function () {
      const { presale } = await loadFixture(deployPresaleFixture);
      const rem1 = await presale.timeRemaining();
      expect(rem1).to.be.greaterThan(0n);
      await time.increase(1000);
      expect(await presale.timeRemaining()).to.equal(rem1 - 1000n);
      expect(await presale.tokensAvailable()).to.equal(
        await presale.totalSupply()
      );
    });
  });
});
