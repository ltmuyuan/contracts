// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '../access/SafeOwnable.sol';

contract P12AssetDemo is ERC1155(''), SafeOwnable {
  // Mapping from token ID to account balances
  mapping(uint256 => mapping(address => uint256)) private _balances;

  //
  mapping(uint256 => uint256) public supply;

  /**
   * See {_mint}.
   */
  function mint(
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public onlyOwner {
    _mint(to, id, amount, data);
    supply[id] += amount;
  }
}
