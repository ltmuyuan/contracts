// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract P12Asset is ERC1155(''), Ownable {

  /**
   * @dev Update log of contract-level MetaData
   */
  event SetContractURI(string  oldContractURI, string  newContractURI_);


  /**
   * @dev log of token metadata uri
   */
  event SetUri(uint256 id,string uri_);

  /**
   * @dev contract-level metadata uri, refer to https://docs.opensea.io/docs/contract-level-metadata
   */
  string private _contractURI;

  /**
   * @dev token id index, which will increase one by one
   */
  uint256 private idx = 0;

  // Mapping from token ID to account balances
  mapping(uint256 => mapping(address => uint256)) private _balances;

  // metadata uri
  mapping(uint256 => string) private _uri;

  /**
   * @dev current supply, how many a id are minted not.
   */
  mapping(uint256 => uint256) public supply;

  /**
   * @dev max supply, a token id has a max supply cap
   */
  mapping(uint256 => uint256) public maxSupply;

  constructor(string memory contractURI_) {
    _contractURI = contractURI_;
  }

  /**
   * @dev developer create an new asset
   * @return uint256 new asset's tokenId
   */

  function create(uint256 amount_, string calldata uri_) public onlyOwner returns (uint256) {
    // set tokenId totalSupply
    maxSupply[idx] = amount_;
    // set metadata Uri
    _setUri(idx, uri_);
    // idx increment
    idx += 1;
    return idx - 1;
  }

  /**
   * See {_mint}.
   */
  function mint(
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public onlyOwner {
    require(amount + supply[id] <= maxSupply[id], 'P12Asset: exceed max supply');
    _mint(to, id, amount, data);
    supply[id] += amount;
  }

  /**
   * @dev set token metadata uri
   */
  function _setUri(uint256 id, string calldata uri_) private {
    require(bytes(_uri[id]).length == 0, 'P12Asset: uri already set');
    _uri[id] = uri_;
    emit SetUri(id, uri_);
  }

  /**
   * @dev return token metadata uri
   */
  function uri(uint256 id) public view virtual override returns (string memory) {
    require(id < idx, 'P12Asset: id not exist');
    return _uri[id];
  }

  /**
   *  @dev read contract-level MetaData URI
   */
  function contractURI() public view returns (string memory) {
    return _contractURI;
  }

  /**
   * @dev set contract-level MetaData
   */
  function setContractURI(string memory newContractURI_) public onlyOwner {
    string memory oldContractURI = _contractURI;
    _contractURI = newContractURI_;
    emit SetContractURI(oldContractURI,_contractURI);
  }
}
