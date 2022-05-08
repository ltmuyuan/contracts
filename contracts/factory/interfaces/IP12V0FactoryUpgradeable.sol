// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import 'hardhat/console.sol';

interface IP12V0FactoryUpgradeable {
  // register gameId =>developer
  function register(string memory gameId, address developer) external;

  // mint game coin
  function create(
    string memory name,
    string memory symbol,
    string memory gameId,
    string memory gameCoinIconUrl,
    uint256 amountGameCoin,
    uint256 amountP12
  ) external returns (address);

  //  mint coin and Launch a statement
  function declareMintCoin(
    string memory gameId,
    address gameCoinAddress,
    uint256 amountGameCoin
  ) external returns (bool);

  // execute Mint coin
  function executeMint(address gameCoinAddress, bytes32 mintId) external returns (bool);

  function withdraw(
    address userAddress,
    address gameCoinAddress,
    uint256 amountGameCoin
  ) external returns (bool);

  // get mintFee
  function getMintFee(address gameCoinAddress, uint256 amountGameCoin) external view returns (uint256);

  // get mintDelay
  function getMintDelay(address gameCoinAddress, uint256 amountGameCoin) external view returns (uint256);

  // get delayK
  function setDelayK(uint256 delayK) external returns (bool);

  // get delayB
  function setDelayB(uint256 delayB) external returns (bool);

  // register Game developer log
  event RegisterGame(string gameId, address indexed developer);

  // register Game coin log
  event CreateGameCoin(address indexed gameCoinAddress, string gameId, uint256 amountP12);

  // mint coin in future log
  event DeclareMint(
    bytes32 indexed mintId,
    address indexed gameCoinAddress,
    uint256 mintAmount,
    uint256 unlockTimestamp,
    uint256 amountP12
  );

  // mint coin success log
  event ExecuteMint(bytes32 indexed mintId, address indexed gameCoinAddress, address indexed executor);

  // game player withdraw gameCoin
  event Withdraw(address userAddress, address gameCoinAddress, uint256 amountGameCoin);

  // p12Mine address change log
  event SetP12Mine(address oldP12Mine, address newP12Mine);

  // change delayB log
  event SetDelayB(uint256 oldDelayB, uint256 newDelayB);

  // change delayK log
  event SetDelayK(uint256 oldDelayK, uint256 newDelayK);
}
