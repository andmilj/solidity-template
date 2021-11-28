import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";
import { RouterWrapper__factory } from "../../typechain/factories/RouterWrapper__factory";
import { RouterWrapper } from "../../typechain/RouterWrapper";

task("deploy:RouterWrapper").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const factory: RouterWrapper__factory = await ethers.getContractFactory("RouterWrapper");

  const tokenContract: RouterWrapper = <RouterWrapper>(
    await factory.deploy("0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506")
  );
  await tokenContract.deployed();
  console.log("Wrapped router deployed to: ", tokenContract.address);
});

// npx hardhat verify --network rinkeby "0x5192752a74dA5a99d16D7Cc7f7C83Ba5d29d14Ec"
