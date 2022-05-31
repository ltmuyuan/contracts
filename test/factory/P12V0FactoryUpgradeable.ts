import { ethers, upgrades } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { deployAll, EconomyContract, ExternalContract } from '../../scripts/deploy';

describe('p12V0Factory', function () {
  let admin: SignerWithAddress;
  let developer: SignerWithAddress;
  let user: SignerWithAddress;
  let mintId: string;
  let mintId2: string;
  let gameCoinAddress: string;
  let core: EconomyContract & ExternalContract;

  this.beforeAll(async function () {
    // hardhat test accounts
    const accounts = await ethers.getSigners();
    admin = accounts[0];
    developer = accounts[1];
    user = accounts[2];
    core = await deployAll();
  });
  it('Should pausable effective', async () => {
    await core.p12V0Factory.pause();
    expect(core.p12V0Factory.create('', '', '', '', 0n, 0n)).to.be.revertedWith('Pausable: paused');
    expect(core.p12V0Factory.declareMintCoin('', '', 0n)).to.be.revertedWith('Pausable: paused');
    expect(core.p12V0Factory.executeMint('', '')).to.be.revertedWith('Pausable: paused');
    await core.p12V0Factory.unpause();
  });

  it('Should show developer register successfully', async function () {
    const gameId = '1101';
    await core.p12V0Factory.connect(admin).register(gameId, developer.address);
    expect(await core.p12V0Factory.allGames('1101')).to.be.equal(developer.address);
  });

  it('Give developer p12 and approve p12 token to p12V0factory', async function () {
    await core.p12Token.connect(admin).transfer(developer.address, BigInt(3) * 10n ** 18n);
    expect(await core.p12Token.balanceOf(developer.address)).to.be.equal(3n * 10n ** 18n);
    await core.p12Token.connect(developer).approve(core.p12V0Factory.address, 3n * 10n ** 18n);
  });
  it('Should show gameCoin create successfully!', async function () {
    const name = 'GameCoin';
    const symbol = 'GC';
    const gameId = '1101';
    const gameCoinIconUrl =
      'https://images.weserv.nl/?url=https://i0.hdslb.com/bfs/article/87c5b43b19d4065f837f54637d3932e680af9c9b.jpg';
    const amountGameCoin = BigInt(10) * BigInt(10) ** 18n;
    const amountP12 = BigInt(1) * BigInt(10) ** 18n;

    await core.p12Token.connect(developer).approve(core.p12V0Factory.address, amountP12);
    const createInfo = await core.p12V0Factory
      .connect(developer)
      .create(name, symbol, gameId, gameCoinIconUrl, amountGameCoin, amountP12);

    (await createInfo.wait()).events!.forEach((x) => {
      if (x.event === 'CreateGameCoin') {
        gameCoinAddress = x.args!.gameCoinAddress;
      }
    });
  });

  it('Should show set delay variable successfully! ', async function () {
    await core.p12V0Factory.connect(admin).setDelayK(1);
    await core.p12V0Factory.connect(admin).setDelayB(1);
    expect(await core.p12V0Factory.delayK()).to.be.equal(1);
    expect(await core.p12V0Factory.delayB()).to.be.equal(1);
  });

  // it("Check gameCoin mint fee", async function () {
  //   const price = await core.p12V0Factory.getMintFee(
  //     gameCoinAddress,
  //     BigInt(30) * BigInt(10) ** 18n
  //   );
  //   console.log("check gameCoin mint fee", price);
  // });

  it('Check gameCoin mint delay time', async function () {
    await core.p12V0Factory.getMintDelay(gameCoinAddress, BigInt(5) * BigInt(10) ** 18n);
  });
  it('Should show declare mint successfully!', async function () {
    const amountP12 = BigInt(6) * BigInt(10) ** 17n;
    await core.p12Token.connect(developer).approve(core.p12V0Factory.address, amountP12);
    const tx = await core.p12V0Factory
      .connect(developer)
      .declareMintCoin('1101', gameCoinAddress, BigInt(5) * BigInt(10) ** 18n);
    (await tx.wait()).events!.forEach((x) => {
      if (x.event === 'DeclareMint') {
        mintId = x.args!.mintId;
      }
    });
  });

  it('Should show declare mint successfully!', async function () {
    const amountP12 = BigInt(6) * BigInt(10) ** 17n;

    await core.p12Token.connect(developer).approve(core.p12V0Factory.address, amountP12);
    const tx = await core.p12V0Factory
      .connect(developer)
      .declareMintCoin('1101', gameCoinAddress, BigInt(5) * BigInt(10) ** 18n);
    (await tx.wait()).events!.forEach((x) => {
      if (x.event === 'DeclareMint') {
        mintId2 = x.args!.mintId;
      }
    });
  });

  it('Should show execute mint successfully!', async function () {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    await ethers.provider.send('evm_mine', [timestampBefore + 5000]);
    await core.p12V0Factory.executeMint(gameCoinAddress, mintId);
  });

  it('Should show duplicate mint fail!', async function () {
    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    await ethers.provider.send('evm_mine', [timestampBefore + 5000]);
    await expect(core.p12V0Factory.executeMint(gameCoinAddress, mintId)).to.be.revertedWith('this mint has been executed');
  });

  it('Should show change game developer successfully !', async function () {
    const gameId = '1101';
    await core.p12V0Factory.connect(admin).register(gameId, admin.address);
    expect(await core.p12V0Factory.allGames('1101')).to.be.equal(admin.address);
  });

  it('Should show withdraw gameCoin successfully', async function () {
    await core.p12V0Factory.connect(admin).withdraw(user.address, gameCoinAddress, 1n * 10n ** 18n);
    const P12V0ERC20 = await ethers.getContractFactory('P12V0ERC20');
    const p12V0ERC20 = await P12V0ERC20.attach(gameCoinAddress);

    expect(await p12V0ERC20.balanceOf(user.address)).to.be.equal(1n * 10n ** 18n);
  });
  it('Should contract upgrade successfully', async function () {
    const p12FactoryAlterF = await ethers.getContractFactory('P12V0FactoryUpgradeableAlter');

    await upgrades.upgradeProxy(core.p12V0Factory.address, p12FactoryAlterF);

    const p12FactoryAlter = await ethers.getContractAt('P12V0FactoryUpgradeableAlter', core.p12V0Factory.address);

    await p12FactoryAlter.callWhiteBlack();
  });
});
