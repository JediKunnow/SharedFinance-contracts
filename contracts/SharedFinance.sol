// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';
import '../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol';

contract SharedFinance is ERC20 {

  using SafeMath for uint;
  using SafeERC20 for IERC20;

  struct HolderInfo {
    bool exists;
    uint256 hid;
    uint256 totalEarnings;
  }

  IERC20 private collateral = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC
  uint256 public constant fee = 15; // x1000
  address[] private holdersList; // a.k.a. investors
  mapping(address => HolderInfo) holders;
  uint256 private totalHoldersEarnings;

  constructor() ERC20("SharedFinance Dollar","SFD") {
    totalHoldersEarnings = 0;
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }

  /*
    SELL Function.
    Burn SFD.
    Get SFD from sender and give [1 - (fee / 1000)]% of the amount in BUSD.
    The rest goes to the holdersList
  */
  function mint(address to, uint256 _amount) external returns (uint256 mintedAmount) {

    require(_amount > 0, 'ZEROAMOUNT');
    require( getCollateralBalance(to) >= _amount, 'NOT_ENOUGH_COLLATERAL');
    require( collateral.allowance(to, address(this)) >= _amount, 'NOT_ENOUGH_ALLOWANCE');

    uint256 fees = _amount.mul(fee).div(1000);

    collateral.safeTransferFrom(
      to,
      address(this),
      _amount
    );
    
    uint256 distributedFees = distributeEarnings(fees, to);
    mintedAmount = _amount.sub(distributedFees);
    
    _mint(
      to,
      mintedAmount
    );

    if(!holders[to].exists){
      holders[to].exists = true;
      holders[to].hid = holdersList.length;
      holdersList.push(to);
    }

    emit BuySFD(to, _amount);
  }

  /*
    BUY Function.
    Mint SFD.
    Get BUSD from sender and mint 98.5% of the amount in SFD
    The rest goes to the holdersList
  */
  function burn(uint256 _amount) public returns (uint256 collateralAmount) {

    require(_amount > 0, 'ZEROAMOUNT');
    require(_amount <= balanceOf(msg.sender), 'NOT_ENOUGH_SFD');

    uint256 balanceBefore = balanceOf(msg.sender);
    uint256 amount = _amount;
    uint256 fees = _amount.mul(fee).div(1000);

    _burn(
      msg.sender,
      amount
    );

    uint256 distributedFees = distributeEarnings(fees, msg.sender);
    amount = _amount.sub(distributedFees);

    collateral.safeTransfer(
      msg.sender,
      amount
    );
    
    if(_amount == balanceBefore)
      removeHolder(msg.sender);

    collateralAmount = amount;
    emit SellSFD(msg.sender, _amount);
  }

  /*
    Returns the SFR relative share of an holder.
    The return value is expressed with 18 decimals for more precision.
  */
  function contributionPoints(address _account) public view returns(uint256) {
    uint256 balance = balanceOf(_account);
    if(balance == 0){
      return 0;
    }
    uint256 supply = totalSupply();
    return balance.mul(1000000).div(supply);
  }

  /*
    Returns total hoders earnings
  */
  function totalEarnings() public view returns(uint256){
    return totalHoldersEarnings;
  }

  /*
    Returns total earnings for the specified holder address
  */
  
  function holderEarnings(address holder) public view returns (uint256 earns){
    earns = holders[holder].totalEarnings;
  }

  /*
    Returns the BUSD balance of an address
  */
  function getCollateralBalance(address _address) view public returns (uint256) {
    return collateral.balanceOf(_address);
  }

  /*
    Return holdersList.length
  */
  function holdersCount() public view returns(uint256 holdersList_count) {
    holdersList_count = holdersList.length;
  }

  /*
    Remove an holder from the holdersList list.
    Move the last element to the deleted item slot.
  */
  function removeHolder(address holder) private {
      uint256 hid = 0;
      if(holders[holder].exists){

        hid = holders[holder].hid;
        /* Avoiding gaps */
        holdersList[hid] = holdersList[holdersList.length - 1];
        holdersList.pop();

        holders[holder].exists = false;
      }
  }

  /*
    Returns BUSD reserve
  */
  function tvl() public view returns (uint256) {
    return collateral.balanceOf(address(this));
  }

  function distributeEarnings(uint256 amount, address sender) private returns(uint256 distributedFees) {

    require(amount > 0, '!EARNINGS');

    uint256 supply = totalSupply();
    uint256 hshare = 0;
    distributedFees = 0;

    for(uint256 i=0; i < holdersList.length; i++){
      if(holdersList[i] == sender)
        continue;
      if(balanceOf(holdersList[i]) > 0){
        hshare = balanceOf(holdersList[i]).mul(amount).div(supply);
        _mint(holdersList[i], hshare);
        holders[holdersList[i]].totalEarnings += hshare;
        distributedFees += hshare;
      }
    }
    totalHoldersEarnings += distributedFees;
  }

  event BuySFD(address indexed _holder, uint256 amount);
  event SellSFD(address indexed _holder, uint256 amount);

}
