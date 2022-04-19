import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

async function main() {
  let admin: SignerWithAddress;
  let user: SignerWithAddress;
  [admin, user] = await ethers.getSigners();

  const P12FACTORY = await ethers.getContractFactory('P12V0Factory');
  const P12Factory = await P12FACTORY.attach('0xF7fd4112CFf5da535BBFa3811D40fE9Aa61FA722');

  await P12Factory.connect(admin).register('1001', user.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});