import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { Multicall, Multicall__factory } from "../../typechain";

task("deploy:Multicall").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const tokenFactory: Multicall__factory = await ethers.getContractFactory("Multicall");
  const tokenContract: Multicall = <Multicall>await tokenFactory.deploy();
  await tokenContract.deployed();
  console.log("Multicall deployed to: ", tokenContract.address);
});

// npx hardhat verify --network rinkeby "0x5192752a74dA5a99d16D7Cc7f7C83Ba5d29d14Ec"
