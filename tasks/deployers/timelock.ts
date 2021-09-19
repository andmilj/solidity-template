import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { Timelock, Timelock__factory } from "../../typechain";

task("deploy:Timelock").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const factory: Timelock__factory = await ethers.getContractFactory("Timelock");
  const contract: Timelock = <Timelock>await factory.deploy("0x36C96C3eBFD674484B17998CEe64615c6601B43D", 10800);
  await contract.deployed();
  console.log("Timelock deployed to: ", contract.address);
});

// npx hardhat verify --network rinkeby 0xC64410844DE8F92d728e8C0e8e7f5475ffB1e768 0x36C96C3eBFD674484B17998CEe64615c6601B43D 10800
