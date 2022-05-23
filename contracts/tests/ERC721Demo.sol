// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract ERC721Demo is ERC721('', ''), Ownable {
  /**
   * See {_mint}.
   */
  function safeMint(
    address to,
    uint256 id,
    bytes memory data
  ) public onlyOwner {
    _safeMint(to, id, data);
  }
}
