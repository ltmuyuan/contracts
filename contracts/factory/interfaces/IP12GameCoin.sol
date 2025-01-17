// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IP12GameCoin is IERC20 {
  /**
   * @dev record the event that transfer coin with a off-chain account, which will be used when someone want to deposit his coin to off-chain game.
   */
  event TransferWithAccount(address recipient, string account, uint256 amount);

  function mint(address to, uint256 amount) external;

  function gameId() external view returns (string memory);

  function gameCoinIconUrl() external view returns (string memory);

  function transferWithAccount(
    address recipient,
    string memory account,
    uint256 amount
  ) external;
}
