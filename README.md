# PreSaleToken

An all-in-one ERC-20 token and fixed-price presale contract built with Solidity and Hardhat.

Users can mint the token, lock transfers during the sale, purchase tokens at a fixed price, finalize the sale, and collect proceeds securely and gas-optimized.

---

## Project Structure

| Folder         | Purpose                                                                        |
| :------------- | :----------------------------------------------------------------------------- |
| `/contracts/`  | Smart contracts (`MyToken.sol`, `PreSaleToken.sol`, `PreSaleTokenFactory.sol`) |
| `/interfaces/` | Public interfaces (`IPreSaleToken.sol`, `IPreSaleTokenFactory.sol`)            |
| `/scripts/`    | Deployment & interaction scripts                                               |
| `/test/`       | Tests with Hardhat & Chai                                                      |
| `/deploy/`     | (optional) Legacy deploy scripts                                               |

---

## Smart Contracts

### MyToken

- Simple ERC-20 that mints a fixed supply to the deployer.
- Uses `Ownable` for admin control.
- No pause to minimize bytecode.

### PreSaleToken

- Combines token and presale in one.
- Inherits `MyToken` and `ReentrancyGuard`.
- Constructor seeds entire supply into itself.
- Fixed-price sale (`tokenPrice` in wei per smallest unit).
- Custom errors, CEI pattern, immutable state for gas savings.
- Locks all transfers (`transfer`/`transferFrom`) until `finalizeSale()`.
- **Fallback** `receive()` to support `ETH → buyTokens()`.
- Events:
  - `TokensSeeded(seedSource, amount)`
  - `SaleInitialized(tokenPrice, saleStart, saleEnd, minPurchase, maxPurchase, totalTokens)`
  - `ReceivedETH(buyer, amount)`
  - `TokensPurchased(buyer, ethSpent, tokensBought)`
  - `SaleFinalized(totalRaised, tokensSold)`

### PreSaleTokenFactory

- Factory to deploy and track multiple `PreSaleToken` instances.
- Caller becomes owner of each new presale.
- Emits  
  `PreSaleCreated(presaleAddress, name, symbol, saleDuration)`  
  for easy off-chain indexing.

---

## Requirements

- Node.js (>= 18.x)
- pnpm (>= 8.x) or npm (>= 9.x)
- Hardhat (>= 2.12.x)

Install dependencies:

```bash
pnpm install
```

---

## Compile Contracts

```bash
pnpm hardhat compile
```

---

## Run Tests

```bash
pnpm hardhat test
```

> Full coverage: purchase bounds, transfer locking, finalization, view functions.

---

## Local Deployment

Start a local Hardhat network:

```bash
pnpm hardhat node
```

Deploy contracts:

```bash
pnpm hardhat ignition deploy ignition/modules/PreSaleTokenFactory.ts --network localhost
```

Your `PreSaleTokenFactory` will be deployed locally.

---

## Local Interaction

Open the Hardhat console:

```bash
pnpm hardhat console --network localhost
```

Sample flow:

```js
const [deployer, buyer] = await ethers.getSigners();

// 1️⃣ Attach to the factory
const factory = await ethers.getContract("PreSaleTokenFactory");

// 2️⃣ Create a new presale via the factory
await factory.createPreSale(
  "My Token", // name
  "MTK", // symbol
  1_000_000, // initial supply (whole tokens)
  ethers.parseEther("0.01"), // tokenPrice
  604_800, // saleDuration (7 days)
  ethers.parseEther("0.1"), // minPurchase
  ethers.parseEther("1.0") // maxPurchase
);

// 3️⃣ Retrieve the freshly deployed presale address
const presales = await factory.getAllPreSales();
const presaleAddress = presales[presales.length - 1];

// 4️⃣ Attach to the new PreSaleToken
const presale = await ethers.getContractAt("PreSaleToken", presaleAddress);

// 5️⃣ Check how many tokens are available
console.log("Tokens available:", (await presale.tokensAvailable()).toString());

// 6️⃣ Buyer purchases tokens (0.5 ETH)
await presale.connect(buyer).buyTokens({ value: ethers.parseEther("0.5") });

// 7️⃣ Fast-forward time past saleEnd
await network.provider.send("evm_increaseTime", [604_800 + 1]);
await network.provider.send("evm_mine");

// 8️⃣ Finalize sale as the deployer
await presale.connect(deployer).finalizeSale();

// 9️⃣ Verify balances
console.log("Deployer ETH balance:", (await deployer.getBalance()).toString());
console.log(
  "Buyer token balance:",
  (await presale.balanceOf(buyer.address)).toString()
);
```

---

## Testnet Deployment (Optional)

Create a `.env` file:

```bash
RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

Deploy to Sepolia:

```bash
pnpm hardhat run scripts/deploy.js --network sepolia
```

---

## Features

- Gas-optimized: immutable vars, custom errors, cached decimals.
- Security: ReentrancyGuard, CEI pattern, transfer locking.
- Seamless UX: purchase via simple ETH transfer (fallback).
- Full event coverage for off-chain indexing.

---

## License

MIT © 2025 Daniel Neris

---

## Contributions

Pull Requests and Issues are welcome!  
Let’s build the decentralized future together.
