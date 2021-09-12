import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { MasterChefToken, MasterChefToken__factory, MasterChefV2, MasterChefV2__factory } from "../../typechain";

task("deploy:MaterChef")
  // .addParam("greeting", "Say hello, be nice")
  .setAction(async function (taskArguments: TaskArguments, { ethers }) {
    const tokenFactory: MasterChefToken__factory = await ethers.getContractFactory("MasterChefToken");
    const tokenContract: MasterChefToken = <MasterChefToken>await tokenFactory.deploy(10000);
    await tokenContract.deployed();
    console.log("MaterChefToken deployed to: ", tokenContract.address);

    const farmFactory: MasterChefV2__factory = await ethers.getContractFactory("MasterChefV2");
    const farmContract: MasterChefV2 = <MasterChefV2>(
      await farmFactory.deploy(
        tokenContract.address,
        "0x67f780ca67865c48100F3d633f0F148242eEf2A6",
        "0x67f780ca67865c48100F3d633f0F148242eEf2A6",
        20,
        11023289,
      )
    );

    await farmContract.deployed();
    console.log("MaterChefToken deployed to: ", farmContract.address);
  });
