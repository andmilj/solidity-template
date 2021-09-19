import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import {
  MasterChefToken,
  MasterChefToken__factory,
  MasterChef,
  MasterChef__factory,
  Timelock__factory,
  Timelock,
} from "../../typechain";

const WALLET_ADDRESS = "0x36C96C3eBFD674484B17998CEe64615c6601B43D";
const DEV_ADDRESS = "0x67f780ca67865c48100F3d633f0F148242eEf2A6";
const FEE_ADDRESS = "0x67f780ca67865c48100F3d633f0F148242eEf2A6";

const FARMING_START_BLOCK = 9298000;
const TOKEN_EMISSION_PER_BLOCK = "100000000000000000";

task("deploy:MasterChef").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const tokenFactory: MasterChefToken__factory = await ethers.getContractFactory("MasterChefToken");
  const tokenContract: MasterChefToken = <MasterChefToken>await tokenFactory.deploy(0);
  await tokenContract.deployed();
  console.log("MasterChefToken deployed to: ", tokenContract.address);

  const mintResult = await tokenContract.mint(WALLET_ADDRESS, "4000000000000000000000");
  console.log("Token minted", mintResult.blockHash);

  const farmFactory: MasterChef__factory = await ethers.getContractFactory("MasterChef");
  const farmContract: MasterChef = <MasterChef>(
    await farmFactory.deploy(
      tokenContract.address,
      DEV_ADDRESS,
      FEE_ADDRESS,
      TOKEN_EMISSION_PER_BLOCK,
      FARMING_START_BLOCK,
    )
  );

  await farmContract.deployed();
  console.log("MasterChef deployed to: ", farmContract.address);

  const tokenTransferOwnershipResult = await tokenContract.transferOwnership(farmContract.address);
  console.log("Token Ownership transferred to Mastershef", tokenTransferOwnershipResult.blockHash);

  const factory: Timelock__factory = await ethers.getContractFactory("Timelock");
  const timelockContract: Timelock = <Timelock>await factory.deploy(WALLET_ADDRESS, 60);
  await timelockContract.deployed();
  console.log("Timelock deployed to: ", timelockContract.address);

  //----------------------------- verifictaion
  console.log("--------------------------------");
  console.log(`npx hardhat verify --network rinkeby "${tokenContract.address}" 0`);
  console.log(
    `npx hardhat verify --network rinkeby ${farmContract.address} "${tokenContract.address}" "${DEV_ADDRESS}" "${FEE_ADDRESS}" ${TOKEN_EMISSION_PER_BLOCK} ${FARMING_START_BLOCK}`,
  );
  console.log(`npx hardhat verify --network rinkeby ${timelockContract.address} ${WALLET_ADDRESS} 60`);

  //----------------------------- custom should be removed
  await farmContract.add(4000, "0x95094111946f91381d7d4c933acbe35dd88f8d0e", 500, true);
  await farmContract.transferOwnership(timelockContract.address);
  await timelockContract.queueTransaction(
    farmContract.address,
    0,
    "set(uint256,uint256,uint16,bool)",
    "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000138800000000000000000000000000000000000000000000000000000000000002580000000000000000000000000000000000000000000000000000000000000001",
    1632069355,
  );
});

// npx hardhat verify --network rinkeby "0xcCeac8394C9e0DB97d929F47eff77619dd2E5388" 10000
// npx hardhat verify --network rinkeby "0xB6f85d26D9Bf34684970D8e4Ed65De03099838BF" "0xcCeac8394C9e0DB97d929F47eff77619dd2E5388" "0x67f780ca67865c48100F3d633f0F148242eEf2A6" "0x67f780ca67865c48100F3d633f0F148242eEf2A6" 100000000000000000 9298000
