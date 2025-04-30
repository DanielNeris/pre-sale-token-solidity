import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import {
  PreSaleTokenFactory,
  PreSaleTokenFactory__factory,
  PreSaleToken__factory,
} from "../typechain-types";

describe("PreSaleTokenFactory", function () {
  const NAME = "My Token";
  const SYMBOL = "MTK";
  const INITIAL_SUPPLY = 1_000_000;
  const TOKEN_PRICE = hre.ethers.parseEther("0.01");
  const SALE_DURATION = 604_800; // 7 days
  const MIN_PURCHASE = hre.ethers.parseEther("0.1");
  const MAX_PURCHASE = hre.ethers.parseEther("1.0");

  type Fixture = {
    factory: PreSaleTokenFactory;
    deployer: SignerWithAddress;
    other: SignerWithAddress;
  };

  async function deployFactoryFixture(): Promise<Fixture> {
    const [deployer, other] =
      (await hre.ethers.getSigners()) as SignerWithAddress[];
    const factoryF = new PreSaleTokenFactory__factory(deployer);
    const factory = await factoryF.deploy();
    await factory.waitForDeployment();
    return { factory, deployer, other };
  }

  describe("Deployment", function () {
    it("starts empty", async function () {
      const { factory } = await loadFixture(deployFactoryFixture);
      expect(await factory.getPreSaleCount()).to.equal(0);
      expect(await factory.getAllPreSales()).to.deep.equal([]);
      await expect(factory.getPreSale(0)).to.be.revertedWith(
        "Factory: index out of range"
      );
    });
  });

  describe("createPreSale", function () {
    it("deploys a new presale, updates state, emits event", async function () {
      const { factory, deployer } = await loadFixture(deployFactoryFixture);

      // call factory
      const tx = await factory.createPreSale(
        NAME,
        SYMBOL,
        INITIAL_SUPPLY,
        TOKEN_PRICE,
        SALE_DURATION,
        MIN_PURCHASE,
        MAX_PURCHASE
      );

      // 1) event
      await expect(tx)
        .to.emit(factory, "PreSaleCreated")
        .withArgs(await factory.getPreSale(0), NAME, SYMBOL, SALE_DURATION);

      // 2) factory state
      expect(await factory.getPreSaleCount()).to.equal(1);
      const addr = await factory.getPreSale(0);
      expect(await factory.getAllPreSales()).to.deep.equal([addr]);

      // 3) inspect the deployed PreSaleToken
      const presale = PreSaleToken__factory.connect(addr, deployer);
      expect(await presale.tokenPrice()).to.equal(TOKEN_PRICE);
      expect(await presale.minPurchase()).to.equal(MIN_PURCHASE);
      expect(await presale.maxPurchase()).to.equal(MAX_PURCHASE);

      const start = await presale.saleStart();
      const end = await presale.saleEnd();
      expect(end - start).to.equal(SALE_DURATION);

      expect(await presale.totalRaised()).to.equal(0n);
      expect(await presale.finalized()).to.equal(false);
      expect(await presale.owner()).to.equal(deployer.address);
    });

    it("supports multiple presales", async function () {
      const { factory } = await loadFixture(deployFactoryFixture);
      const addrs: string[] = [];

      for (let i = 0; i < 3; i++) {
        const tx = await factory.createPreSale(
          `${NAME}-${i}`,
          SYMBOL,
          INITIAL_SUPPLY,
          TOKEN_PRICE,
          SALE_DURATION,
          MIN_PURCHASE,
          MAX_PURCHASE
        );
        await expect(tx)
          .to.emit(factory, "PreSaleCreated")
          .withArgs(
            await factory.getPreSale(i),
            `${NAME}-${i}`,
            SYMBOL,
            SALE_DURATION
          );
        addrs.push(await factory.getPreSale(i));
      }

      expect(await factory.getPreSaleCount()).to.equal(3);
      expect(await factory.getAllPreSales()).to.deep.equal(addrs);
      for (let i = 0; i < 3; i++) {
        expect(await factory.getPreSale(i)).to.equal(addrs[i]);
      }
    });
  });
});
