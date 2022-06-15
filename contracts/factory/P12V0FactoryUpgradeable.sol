// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.13;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '../access/SafeOwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import './interfaces/IP12V0FactoryUpgradeable.sol';
import '../staking/interfaces/IP12MineUpgradeable.sol';
import './P12V0FactoryStorage.sol';
import '../staking/interfaces/IGaugeController.sol';
import './P12V0ERC20.sol';
import '../token/interfaces/IP12Token.sol';

contract P12V0FactoryUpgradeable is
  AccessControlUpgradeable,
  P12V0FactoryStorage,
  UUPSUpgradeable,
  IP12V0FactoryUpgradeable,
  SafeOwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  bytes32 public constant DEV_ROLE = keccak256('DEV_ROLE');
  bytes32 public constant SUPER_ADMIN_ROLE = keccak256('SUPER_ADMIN_ROLE');

  function pause() public onlyRole(SUPER_ADMIN_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(SUPER_ADMIN_ROLE) {
    _unpause();
  }

  function initialize(
    IP12Token p12_,
    IUniswapV2Factory uniswapFactory_,
    IUniswapV2Router02 uniswapRouter_,
    uint256 effectiveTime_,
    bytes32 initHash_
  ) public initializer {
    p12 = p12_;
    uniswapFactory = uniswapFactory_;
    uniswapRouter = uniswapRouter_;
    _initHash = initHash_;
    addLiquidityEffectiveTime = effectiveTime_;
    IERC20Upgradeable(address(p12)).safeApprove(address(uniswapRouter), type(uint256).max);
    _setupRole(SUPER_ADMIN_ROLE, msg.sender);
    _setRoleAdmin(DEV_ROLE, SUPER_ADMIN_ROLE);
    __ReentrancyGuard_init_unchained();
    __Pausable_init_unchained();
    __Ownable_init_unchained();
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(SUPER_ADMIN_ROLE) {}

  /**
   * @dev compare two string and judge whether they are the same
   */
  function compareStrings(string memory a, string memory b) internal pure virtual returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  /**
   * @dev get current block's timestamp
   */
  function getBlockTimestamp() internal view virtual returns (uint256) {
    return block.timestamp;
  }

  /**
   * @dev calculate the MintFee in P12
   */
  function getMintFee(IP12V0ERC20 gameCoinAddress, uint256 amountGameCoin)
    public
    view
    virtual
    override
    returns (uint256 amountP12)
  {
    uint256 gameCoinReserved;
    uint256 p12Reserved;
    if (address(p12) < address(gameCoinAddress)) {
      (p12Reserved, gameCoinReserved, ) = IUniswapV2Pair(
        IUniswapV2Factory(uniswapFactory).getPair(address(gameCoinAddress), address(p12))
      ).getReserves();
    } else {
      (gameCoinReserved, p12Reserved, ) = IUniswapV2Pair(
        IUniswapV2Factory(uniswapFactory).getPair(address(gameCoinAddress), address(p12))
      ).getReserves();
    }

    // overflow when p12Reserved * amountGameCoin > 2^256 ~= 10^77
    amountP12 = (p12Reserved * amountGameCoin) / (gameCoinReserved * 100);

    return amountP12;
  }

  /**
   * @dev linear function to calculate the delay time
   */
  function getMintDelay(IP12V0ERC20 gameCoinAddress, uint256 amountGameCoin)
    public
    view
    virtual
    override
    returns (uint256 time)
  {
    time = (amountGameCoin * delayK) / (IP12V0ERC20(gameCoinAddress).totalSupply()) + delayB;
    return time;
  }

  /**
   * @dev set p12mine contract address
   * @param newP12Mine new p12mine address
   */
  function setP12Mine(IP12MineUpgradeable newP12Mine) external virtual onlyRole(SUPER_ADMIN_ROLE) {
    require(address(newP12Mine) != address(0), 'P12Factory: address cannot be zero');
    IP12MineUpgradeable oldP12Mine = p12Mine;
    p12Mine = newP12Mine;
    emit SetP12Mine(oldP12Mine, newP12Mine);
  }

  /**
   * @dev set gaugeController contract address
   * @param newGaugeController new gaugeController address
   */
  function setGaugeController(IGaugeController newGaugeController) external virtual onlyRole(SUPER_ADMIN_ROLE) {
    require(address(newGaugeController) != address(0), 'P12Factory: address cannot be zero');
    IGaugeController oldGaugeController = gaugeController;
    gaugeController = newGaugeController;
    emit SetGaugeController(oldGaugeController, newGaugeController);
  }

  /**
    @notice Transfer the permissions under the role
    @param multiSignWallet address of multiSignWallet 
   */
  function grantSuperAdminRoleToMultiSignWallet(address multiSignWallet) external virtual onlyRole(SUPER_ADMIN_ROLE) {
    require(multiSignWallet != address(0), 'P12Factory: address cannot be zero');
    _grantRole(SUPER_ADMIN_ROLE, multiSignWallet);
    renounceRole(SUPER_ADMIN_ROLE, msg.sender);
    _transferOwnership(multiSignWallet);
  }

  /**
    @notice Grant p12Dev permissions to the account
    @param dev address of dev account
   */
  function grantDevRole(address dev) external virtual onlyRole(SUPER_ADMIN_ROLE) {
    require(dev != address(0), 'P12Factory: address cannot be zero');
    _grantRole(DEV_ROLE, dev);
  }

  /**
    @notice Cancel the permissions of the P12Dev account
    @param dev address of dev account
   */
  function revokeDevRole(address dev) external virtual onlyRole(SUPER_ADMIN_ROLE) {
    require(dev != address(0), 'P12Factory: address cannot be zero');
    _revokeRole(DEV_ROLE, dev);
  }

  /**
   * @dev create binding between game and developer, only called by p12 backend
   * @param gameId game id
   * @param developer developer address, who own this game
   */
  function register(string memory gameId, address developer) external virtual override onlyRole(DEV_ROLE) {
    allGames[gameId] = developer;
    emit RegisterGame(gameId, developer);
  }

  /**
   * @dev developer first create their game coin
   * @param name new game coin's name
   * @param symbol game coin's symbol
   * @param gameId the game's id
   * @param gameCoinIconUrl game coin icon's url
   * @param amountGameCoin how many coin first mint
   * @param amountP12 how many P12 coin developer would stake
   * @return gameCoinAddress the address of the new game coin
   */
  function create(
    string memory name,
    string memory symbol,
    string memory gameId,
    string memory gameCoinIconUrl,
    uint256 amountGameCoin,
    uint256 amountP12
  ) external virtual override nonReentrant whenNotPaused returns (IP12V0ERC20 gameCoinAddress) {
    require(msg.sender == allGames[gameId], 'FORBIDDEN: no permit to create');
    require(amountP12 > 0, 'FORBIDDEN: not enough p12');
    gameCoinAddress = _create(name, symbol, gameId, gameCoinIconUrl, amountGameCoin);
    uint256 amountGameCoinDesired = amountGameCoin / 2;

    IERC20Upgradeable(address(p12)).safeTransferFrom(msg.sender, address(this), amountP12);

    IERC20Upgradeable(address(gameCoinAddress)).safeApprove(address(uniswapRouter), amountGameCoinDesired);

    uint256 liquidity0;
    (, , liquidity0) = IUniswapV2Router02(uniswapRouter).addLiquidity(
      address(p12),
      address(gameCoinAddress),
      amountP12,
      amountGameCoinDesired,
      amountP12,
      amountGameCoinDesired,
      address(p12Mine),
      getBlockTimestamp() + addLiquidityEffectiveTime
    );
    //get pair contract address
    address pair = IUniswapV2Factory(uniswapFactory).getPair(address(p12), address(gameCoinAddress));

    // check address
    require(pair != address(0), 'P12Factory: pair address error');

    // get lpToken value
    uint256 liquidity1 = IUniswapV2Pair(pair).balanceOf(address(p12Mine));
    require(liquidity0 == liquidity1, 'P12Factory: liquidities not =');

    // add pair address to Controller,100 is init weight
    IGaugeController(gaugeController).addGauge(pair, 0, 100);
    // new staking pool
    p12Mine.createPool(pair);

    p12Mine.addLpTokenInfoForGameCreator(pair, liquidity1, msg.sender);

    allGameCoins[gameCoinAddress] = gameId;
    emit CreateGameCoin(gameCoinAddress, gameId, amountP12);
    return gameCoinAddress;
  }

  /**
   * @dev if developer want to mint after create coin, developer must declare first
   * @param gameId game's id
   * @param gameCoinAddress game coin's address
   * @param amountGameCoin how many developer want to mint
   * @param success whether the operation success
   */
  function declareMintCoin(
    string memory gameId,
    IP12V0ERC20 gameCoinAddress,
    uint256 amountGameCoin
  ) external virtual override nonReentrant whenNotPaused returns (bool success) {
    require(msg.sender == allGames[gameId], 'FORBIDDEN: have no permission');
    require(compareStrings(allGameCoins[gameCoinAddress], gameId), 'FORBIDDEN');
    // Set the correct unlock time
    uint256 time;
    uint256 currentTimestamp = getBlockTimestamp();
    bytes32 _preMintId = preMintIds[gameCoinAddress];
    uint256 lastUnlockTimestamp = coinMintRecords[gameCoinAddress][_preMintId].unlockTimestamp;
    if (currentTimestamp >= lastUnlockTimestamp) {
      time = currentTimestamp;
    } else {
      time = lastUnlockTimestamp;
    }

    // minting fee for p12
    uint256 p12Fee = getMintFee(gameCoinAddress, amountGameCoin);
    // require(p12Needed < amountP12, "p12 not enough");

    // transfer the p12 to this contract
    IERC20Upgradeable(address(p12)).safeTransferFrom(msg.sender, address(this), p12Fee);

    uint256 delayD = getMintDelay(gameCoinAddress, amountGameCoin);

    bytes32 mintId = _hashOperation(gameCoinAddress, msg.sender, amountGameCoin, time, _initHash);
    coinMintRecords[gameCoinAddress][mintId] = MintCoinInfo(amountGameCoin, delayD + time, false);

    emit DeclareMint(mintId, gameCoinAddress, amountGameCoin, delayD + time, p12Fee);

    return true;
  }

  /**
   * @dev when time is up, anyone can call this function to make the mint executed
   * @param gameCoinAddress address of the game coin
   * @param mintId a unique id to identify a mint, developer can get it after declare
   * @return bool whether the operation success
   */
  function executeMint(IP12V0ERC20 gameCoinAddress, bytes32 mintId)
    external
    virtual
    override
    nonReentrant
    whenNotPaused
    returns (bool)
  {
    // check if it has been executed
    require(!coinMintRecords[gameCoinAddress][mintId].executed, 'this mint has been executed');

    uint256 time = getBlockTimestamp();

    // check that the current time is greater than the unlock time
    require(time > coinMintRecords[gameCoinAddress][mintId].unlockTimestamp, 'Not time to Mint');

    // Modify status
    coinMintRecords[gameCoinAddress][mintId].executed = true;

    // transfer the gameCoin to this contract first

    IP12V0ERC20(gameCoinAddress).mint(address(this), coinMintRecords[gameCoinAddress][mintId].amount);

    emit ExecuteMint(mintId, gameCoinAddress, msg.sender);

    return true;
  }

  /**
   * @notice called when user want to withdraw his game coin from custodian address
   * @param userAddress user's address
   * @param gameCoinAddress gameCoin's address
   * @param amountGameCoin how many user want to withdraw
   */
  function withdraw(
    address userAddress,
    IP12V0ERC20 gameCoinAddress,
    uint256 amountGameCoin
  ) external virtual override onlyRole(SUPER_ADMIN_ROLE) returns (bool) {
    IERC20Upgradeable(address(gameCoinAddress)).safeTransfer(userAddress, amountGameCoin);
    emit Withdraw(userAddress, gameCoinAddress, amountGameCoin);
    return true;
  }

  /**
   * @dev set linear function's K parameter
   * @param newDelayK new K parameter
   */
  function setDelayK(uint256 newDelayK) public virtual override onlyRole(SUPER_ADMIN_ROLE) returns (bool) {
    uint256 oldDelayK = delayK;
    delayK = newDelayK;
    emit SetDelayK(oldDelayK, delayK);
    return true;
  }

  /**
   * @dev set linear function's B parameter
   * @param newDelayB new B parameter
   */
  function setDelayB(uint256 newDelayB) public virtual override onlyRole(SUPER_ADMIN_ROLE) returns (bool) {
    uint256 oldDelayB = delayB;
    delayB = newDelayB;
    emit SetDelayB(oldDelayB, delayB);
    return true;
  }

  /**
   * @dev function to create a game coin contract
   * @param name game coin name
   * @param symbol game coin symbol
   * @param gameId game id
   * @param gameCoinIconUrl game coin icon's url
   * @param amountGameCoin how many for first mint
   */
  function _create(
    string memory name,
    string memory symbol,
    string memory gameId,
    string memory gameCoinIconUrl,
    uint256 amountGameCoin
  ) internal virtual returns (IP12V0ERC20 gameCoinAddress) {
    IP12V0ERC20 gameCoin = new P12V0ERC20(name, symbol, gameId, gameCoinIconUrl, amountGameCoin);
    gameCoinAddress = gameCoin;
  }

  /**
   * @dev hash function to general mintId
   * @param gameCoinAddress game coin address
   * @param declarer address which declare to mint game coin
   * @param amount how much to mint
   * @param timestamp time when declare
   * @param salt a random bytes32
   * @return hash mintId
   */
  function _hashOperation(
    IP12V0ERC20 gameCoinAddress,
    address declarer,
    uint256 amount,
    uint256 timestamp,
    bytes32 salt
  ) internal virtual returns (bytes32 hash) {
    bytes32 preMintId = preMintIds[gameCoinAddress];

    bytes32 preMintIdNew = keccak256(abi.encode(gameCoinAddress, declarer, amount, timestamp, preMintId, salt));
    preMintIds[gameCoinAddress] = preMintIdNew;
    return preMintIdNew;
  }
}
