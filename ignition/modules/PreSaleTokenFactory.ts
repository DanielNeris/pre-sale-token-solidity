import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const PreSaleFactoryModule = buildModule("PreSaleFactoryModule", (m) => {
  // Deploy the PreSaleTokenFactory contract
  const preSaleFactory = m.contract("PreSaleTokenFactory", []);

  return { preSaleFactory };
});

export default PreSaleFactoryModule;
