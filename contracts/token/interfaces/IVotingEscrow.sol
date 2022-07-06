// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.13;

interface IVotingEscrow {
  function getLastUserSlope(address addr) external returns (int256);

  function lockedEnd(address addr) external returns (uint256);

  event Expired(address addr, uint256 timestamp);
}
