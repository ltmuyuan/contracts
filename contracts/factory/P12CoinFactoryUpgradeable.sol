// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '../access/SafeOwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import './interfaces/IP12CoinFactoryUpgradeable.sol';
import '../staking/interfaces/IP12MineUpgradeable.sol';
import './P12CoinFactoryStorage.sol';
import '../staking/interfaces/IGaugeController.sol';
import './P12GameCoin.sol';
import './interfaces/IP12GameCoin.sol';

contract P12CoinFactoryUpgradeable is
  P12CoinFactoryStorage,
  UUPSUpgradeable,
  IP12CoinFactoryUpgradeable,
  SafeOwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;

  //============ External ============
  /**
   * @dev set dev address
   * @param newDev new dev address
   */
  function setDev(address newDev) external virtual override onlyOwner {
    require(newDev != address(0), 'P12Factory: address cannot be 0');
    address oldDev = dev;
    dev = newDev;
    emit SetDev(oldDev, newDev);
  }

  /**
   * @dev set p12mine contract address
   * @param newP12Mine new p12mine address
   */
  function setP12Mine(IP12MineUpgradeable newP12Mine) external virtual override onlyOwner {
    require(address(newP12Mine) != address(0), 'P12Factory: address cannot be 0');
    IP12MineUpgradeable oldP12Mine = p12Mine;
    p12Mine = newP12Mine;
    emit SetP12Mine(oldP12Mine, newP12Mine);
  }

  /**
   * @dev set gaugeController contract address
   * @param newGaugeController new gaugeController address
   */
  function setGaugeController(IGaugeController newGaugeController) external virtual override onlyOwner {
    require(address(newGaugeController) != address(0), 'P12Factory: address cannot be 0');
    IGaugeController oldGaugeController = gaugeController;
    gaugeController = newGaugeController;
    emit SetGaugeController(oldGaugeController, newGaugeController);
  }

  /**
   * @dev set p12Token address
   * reserved only during development
   * @param newP12Token new p12Token address
   */
  function setP12Token(address newP12Token) external virtual override onlyOwner {
    require(newP12Token != address(0), 'P12Factory: address cannot be 0');
    address oldP12Token = p12;
    p12 = newP12Token;
    emit SetP12Token(oldP12Token, newP12Token);
  }

  /**
   * @dev set uniswapFactory address
   * reserved only during development
   * @param newUniswapFactory new UniswapFactory address
   */
  function setUniswapFactory(IUniswapV2Factory newUniswapFactory) external virtual override onlyOwner {
    require(address(newUniswapFactory) != address(0), 'P12Factory: address cannot be 0');
    IUniswapV2Factory oldUniswapFactory = uniswapFactory;
    uniswapFactory = newUniswapFactory;
    emit SetUniswapFactory(oldUniswapFactory, newUniswapFactory);
  }

  /**
   * @dev set uniswapRouter address
   * reserved only during development
   * @param newUniswapRouter new uniswapRouter address
   */
  function setUniswapRouter(IUniswapV2Router02 newUniswapRouter) external virtual override onlyOwner {
    require(address(newUniswapRouter) != address(0), 'P12Factory: address cannot be 0');
    IUniswapV2Router02 oldUniswapRouter = uniswapRouter;
    uniswapRouter = newUniswapRouter;
    emit SetUniswapRouter(oldUniswapRouter, newUniswapRouter);
  }

  /**
   * @dev create binding between game and developer, only called by p12 backend
   * @param gameId game id
   * @param developer developer address, who own this game
   */
  function register(string memory gameId, address developer) external virtual override onlyDev {
    require(developer != address(0), 'P12Factory: address cannot be 0');
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
  ) external virtual override nonReentrant whenNotPaused returns (IP12GameCoin gameCoinAddress) {
    require(msg.sender == allGames[gameId], 'P12Factory: no permit to create');
    require(amountP12 > 0, 'P12Factory: not enough p12');
    gameCoinAddress = _create(name, symbol, gameId, gameCoinIconUrl, amountGameCoin);
    uint256 amountGameCoinDesired = amountGameCoin / 2;

    IERC20Upgradeable(p12).safeTransferFrom(msg.sender, address(this), amountP12);

    IERC20Upgradeable(address(gameCoinAddress)).safeApprove(address(uniswapRouter), amountGameCoinDesired);

    uint256 liquidity0;
    (, , liquidity0) = uniswapRouter.addLiquidity(
      p12,
      address(gameCoinAddress),
      amountP12,
      amountGameCoinDesired,
      amountP12,
      amountGameCoinDesired,
      address(p12Mine),
      getBlockTimestamp() + addLiquidityEffectiveTime
    );
    //get pair contract address
    address pair = uniswapFactory.getPair(p12, address(gameCoinAddress));

    // check address
    require(pair != address(0), 'P12Factory: pair address error');

    // get lpToken value
    uint256 liquidity1 = IUniswapV2Pair(pair).balanceOf(address(p12Mine));
    require(liquidity0 == liquidity1, 'P12Factory: liquidities not =');

    // add pair address to Controller,100 is init weight
    gaugeController.addGauge(pair, 0, 100);

    // create a new pool and add staking info
    p12Mine.addLpTokenInfoForGameCreator(pair, liquidity1, msg.sender);

    allGameCoins[gameCoinAddress] = gameId;
    emit CreateGameCoin(gameCoinAddress, gameId, amountP12);
    return IP12GameCoin(gameCoinAddress);
  }

  /**
   * @dev if developer want to mint after create coin, developer must declare first
   * @param gameId game's id
   * @param gameCoinAddress game coin's address
   * @param amountGameCoin how many developer want to mint
   * @param success whether the operation success
   */
  function queueMintCoin(
    string memory gameId,
    IP12GameCoin gameCoinAddress,
    uint256 amountGameCoin
  ) external virtual override nonReentrant whenNotPaused returns (bool success) {
    require(msg.sender == allGames[gameId], 'P12Factory: have no permission');
    require(compareStrings(allGameCoins[gameCoinAddress], gameId), 'P12Factory: wrong game id');
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

    // transfer the p12 to this contract
    IERC20Upgradeable(p12).safeTransferFrom(msg.sender, address(this), p12Fee);

    uint256 delayD = getMintDelay(gameCoinAddress, amountGameCoin);

    bytes32 mintId = _hashOperation(gameCoinAddress, msg.sender, amountGameCoin, time, _initHash);
    coinMintRecords[gameCoinAddress][mintId] = MintCoinInfo(amountGameCoin, delayD + time, false);

    emit QueueMintCoin(mintId, gameCoinAddress, amountGameCoin, delayD + time, p12Fee);

    return true;
  }

  /**
   * @dev when time is up, anyone can call this function to make the mint executed
   * @param gameCoinAddress address of the game coin
   * @param mintId a unique id to identify a mint, developer can get it after declare
   * @return bool whether the operation success
   */
  function executeMintCoin(IP12GameCoin gameCoinAddress, bytes32 mintId)
    external
    virtual
    override
    nonReentrant
    whenNotPaused
    returns (bool)
  {
    require(coinMintRecords[gameCoinAddress][mintId].unlockTimestamp != 0, 'P12Factory: non-existent mint');
    // check if it has been executed
    require(!coinMintRecords[gameCoinAddress][mintId].executed, 'P12Factory: mint executed');

    uint256 time = getBlockTimestamp();

    // check that the current time is greater than the unlock time
    require(time > coinMintRecords[gameCoinAddress][mintId].unlockTimestamp, 'P12Factory: not time to mint');

    // Modify status
    coinMintRecords[gameCoinAddress][mintId].executed = true;

    // transfer the gameCoin to this contract first

    IP12GameCoin(gameCoinAddress).mint(address(this), coinMintRecords[gameCoinAddress][mintId].amount);

    emit ExecuteMintCoin(mintId, gameCoinAddress, msg.sender);

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
    IP12GameCoin gameCoinAddress,
    uint256 amountGameCoin
  ) external virtual override onlyOwner returns (bool) {
    IERC20Upgradeable(address(gameCoinAddress)).safeTransfer(userAddress, amountGameCoin);
    emit Withdraw(userAddress, gameCoinAddress, amountGameCoin);
    return true;
  }

  //============ Public ============
  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function initialize(
    address p12_,
    IUniswapV2Factory uniswapFactory_,
    IUniswapV2Router02 uniswapRouter_,
    uint256 effectiveTime_,
    bytes32 initHash_
  ) public initializer {
    require(p12_ != address(0), 'P12Mine: p12 token cannot be 0');
    require(address(uniswapFactory_) != address(0), 'P12Mine: uniswapF cannot be 0');
    require(address(uniswapRouter_) != address(0), 'P12Mine: uniswapR cannot be 0');

    p12 = p12_;
    uniswapFactory = uniswapFactory_;
    uniswapRouter = uniswapRouter_;
    _initHash = initHash_;
    addLiquidityEffectiveTime = effectiveTime_;
    IERC20Upgradeable(p12).safeApprove(address(uniswapRouter), type(uint256).max);
    __ReentrancyGuard_init_unchained();
    __Pausable_init_unchained();
    __Ownable_init_unchained();
  }

  /**
   * @dev set linear function's K parameter
   * @param newDelayK new K parameter
   */
  function setDelayK(uint256 newDelayK) public virtual override onlyOwner returns (bool) {
    uint256 oldDelayK = delayK;
    delayK = newDelayK;
    emit SetDelayK(oldDelayK, delayK);
    return true;
  }

  /**
   * @dev set linear function's B parameter
   * @param newDelayB new B parameter
   */
  function setDelayB(uint256 newDelayB) public virtual override onlyOwner returns (bool) {
    uint256 oldDelayB = delayB;
    delayB = newDelayB;
    emit SetDelayB(oldDelayB, delayB);
    return true;
  }

  /**
   * @dev calculate the MintFee in P12
   */
  function getMintFee(IP12GameCoin gameCoinAddress, uint256 amountGameCoin)
    public
    view
    virtual
    override
    returns (uint256 amountP12)
  {
    uint256 gameCoinReserved;
    uint256 p12Reserved;
    if (p12 < address(gameCoinAddress)) {
      (p12Reserved, gameCoinReserved, ) = IUniswapV2Pair(uniswapFactory.getPair(address(gameCoinAddress), p12)).getReserves();
    } else {
      (gameCoinReserved, p12Reserved, ) = IUniswapV2Pair(uniswapFactory.getPair(address(gameCoinAddress), p12)).getReserves();
    }

    // overflow when p12Reserved * amountGameCoin > 2^256 ~= 10^77
    amountP12 = (p12Reserved * amountGameCoin) / (gameCoinReserved * 100);

    return amountP12;
  }

  /**
   * @dev linear function to calculate the delay time
   * @dev delayB is the minimum delay period, even someone mint zero token,
   * @dev there still be delayB period before someone can really mint zero token
   * @dev delayK is the parameter to take the ratio of new amount in to account
   * @dev For example, the initial supply of Game Coin is 100k. If developer want
   * @dev to mint 100k, developer needs to real mint it after `delayK + delayB`. If
   * @dev developer want to mint 200k, developer has to real mint it after `2DelayK +
   * @dev delayB`.
          ^
        t +            /
          |          /
          |        /
      2k+b|      /
          |    /
       k+b|  / 
          |/ 
         b|
          0----p---2p---------> amount
            
   */
  function getMintDelay(IP12GameCoin gameCoinAddress, uint256 amountGameCoin)
    public
    view
    virtual
    override
    returns (uint256 time)
  {
    time = (amountGameCoin * delayK) / (IP12GameCoin(gameCoinAddress).totalSupply()) + delayB;
    return time;
  }

  //============ Internal ============

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
  ) internal virtual returns (P12GameCoin gameCoinAddress) {
    P12GameCoin gameCoin = new P12GameCoin(name, symbol, gameId, gameCoinIconUrl, amountGameCoin);
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
    IP12GameCoin gameCoinAddress,
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

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  /**
   * @dev get current block's timestamp
   */
  function getBlockTimestamp() internal view virtual returns (uint256) {
    return block.timestamp;
  }

  /**
   * @dev compare two string and judge whether they are the same
   */
  function compareStrings(string memory a, string memory b) internal pure virtual returns (bool) {
    return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
  }

  // ============= Modifier ================
  modifier onlyDev() {
    require(msg.sender == dev, 'P12Factory: caller must be dev');
    _;
  }
}
