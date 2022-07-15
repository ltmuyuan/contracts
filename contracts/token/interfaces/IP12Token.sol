// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.13;

interface IP12Token {
  function mint(address recipient, uint256 amount) external;
}