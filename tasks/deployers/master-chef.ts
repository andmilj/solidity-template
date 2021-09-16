import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MasterChefToken, MasterChefToken__factory, MasterChef, MasterChef__factory } from "../../typechain";

task("deploy:MaterChef").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const tokenFactory: MasterChefToken__factory = await ethers.getContractFactory("MasterChefToken");
  const tokenContract: MasterChefToken = <MasterChefToken>await tokenFactory.deploy(10000);
  await tokenContract.deployed();
  console.log("MaterChefToken deployed to: ", tokenContract.address);

  const farmFactory: MasterChef__factory = await ethers.getContractFactory("MasterChef");
  const farmContract: MasterChef = <MasterChef>(
    await farmFactory.deploy(
      tokenContract.address,
      "0x67f780ca67865c48100F3d633f0F148242eEf2A6",
      "0x67f780ca67865c48100F3d633f0F148242eEf2A6",
      "100000000000000000",
      9298000,
    )
  );

  await farmContract.deployed();
  console.log("MaterChef deployed to: ", farmContract.address);
});

// npx hardhat verify --network rinkeby "0xcCeac8394C9e0DB97d929F47eff77619dd2E5388" 10000
// npx hardhat verify --network rinkeby "0xB6f85d26D9Bf34684970D8e4Ed65De03099838BF" "0xcCeac8394C9e0DB97d929F47eff77619dd2E5388" "0x67f780ca67865c48100F3d633f0F148242eEf2A6" "0x67f780ca67865c48100F3d633f0F148242eEf2A6" 100000000000000000 9298000
