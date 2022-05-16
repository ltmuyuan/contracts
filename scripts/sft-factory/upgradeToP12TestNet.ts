// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import env, { ethers, upgrades } from 'hardhat';

async function main() {
  if (env.network.name === 'p12TestNet') {
    const P12AssetFactoryUpgradableF = await ethers.getContractFactory('P12AssetFactoryUpgradable');

    const proxyAddr = '0x173e4D790A43E3016AAeD9Bbd0987CD760f0dB9F';

    // const p12Token = '0xeAc1F044C4b9B7069eF9F3eC05AC60Df76Fe6Cd0';
    // const uniswapV2Factory = '0x8C2543578eFEd64343C63e9075ed70F1d255D1c6';
    // const uniswapV2Router = '0x71A3B75A9A774EB793A44a36AF760ee2868912ac';
    await upgrades.upgradeProxy(proxyAddr, P12AssetFactoryUpgradableF);

    console.log('proxy contract', proxyAddr);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
