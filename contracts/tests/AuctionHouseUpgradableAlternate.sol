// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import '../auctionHouse/AuctionHouseUpgradable.sol';

contract AuctionHouseUpgradableAlternative is AuctionHouseUpgradable {
  string public name;

  function setName(string memory _name) public {
    name = _name;
  }

  function getName() public view returns (string memory) {
    return name;
  }
}