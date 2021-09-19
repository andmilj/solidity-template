import { task } from "hardhat/config";
import Web3 from "web3";

task("encodeData", "Prints the list of accounts", async (_taskArgs, hre) => {
  const web3 = new Web3();
  const result = web3.eth.abi.encodeParameters(["uint256", "uint256", "uint256", "bool"], [0, 5000, 600, true]);
  const result2 = web3.eth.abi.encodeFunctionSignature("set(uint256 uint256 uint16 bool");

  console.log(result);
  console.log(result2);
});
