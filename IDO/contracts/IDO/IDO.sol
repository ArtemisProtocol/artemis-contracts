//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "miscsolidity/contracts/fee/FeeTakers.sol";
import "./IIDO.sol";

contract IDO is IIDO, Ownable, ReentrancyGuard, FeeTakers {

    constructor(IERC20 token, uint tokensForSale, IERC20 collateralToken, uint collateralRequired, uint ONEToRaise, uint buyingStartsAt, uint buyingEndsAt, uint vestingStartsAt, uint vestingEndsAt) {
        _token = token;
        _tokensForSale = tokensForSale;
        _collateralToken = collateralToken;
        _collateralRequired = collateralRequired;
        _ONEToRaise = ONEToRaise;
        _buyingStartsAt = buyingStartsAt;
        _buyingEndsAt = buyingEndsAt;
        _vestingStartsAt = vestingStartsAt;
        _vestingEndsAt = vestingEndsAt;
    }

    uint _buyingStartsAt;
    uint _buyingEndsAt;

    uint _vestingStartsAt;
    uint _vestingEndsAt;

    uint _collateralRequired;
    bool _enforceMaximumTokensPerWallet;
    uint _maximumTokensPerWallet;
    uint _tokensForSale;
    uint _ONEToRaise;

    uint _ONERaised;
    uint _tokensSold;

    IERC20 _token;
    IERC20 _collateralToken;

    mapping(address => User) _users;

    function status() public override view returns(STATUS) {
        if(block.timestamp >= _vestingStartsAt) {
            return STATUS.claimable;
        }
        if(block.timestamp > _buyingEndsAt) {
            return STATUS.ended;
        }
        if(block.timestamp >= _buyingStartsAt) {
            return STATUS.inprogress;
        }
        return STATUS.pre;
    }

    receive() external override payable {

        require(status() == STATUS.inprogress, "Can only purchase when ICO is in progress.");
        require(_ONERaised + msg.value <= _ONEToRaise, "Maximum ONE raised reached.");

        User storage _user = _users[msg.sender];

        if(!_user.collateralPaid && _collateralRequired > 0) {
            _collateralToken.transferFrom(msg.sender, address(this), _collateralRequired);
            _user.collateralPaid = true;
        }

        uint toBuy = (msg.value * _tokensForSale) / _ONEToRaise;

        if(_enforceMaximumTokensPerWallet) {
            require(toBuy + _user.tokensBought <= _maximumTokensPerWallet, "Cannot purchase this many tokens.");
        }

        _tokensSold += toBuy;
        _user.tokensBought += toBuy;
        _ONERaised += msg.value;

        _distributeFee(msg.value);
    }

    function getUser(address user) public override view returns(User memory) {
        return _users[user];
    }

    function claimable(address user) public override view returns(uint) {

        User storage _user = _users[user];

        if(status() != STATUS.claimable) {
            return 0;
        }

        uint totalTimeVested = _vestingEndsAt - _vestingStartsAt;
        uint timeVested = block.timestamp - _vestingStartsAt;

        return ((_user.tokensBought * timeVested) / totalTimeVested) - _user.tokensClaimed; 

    }

    function claim() public override {

        User storage _user = _users[msg.sender];

        uint toClaim = claimable(msg.sender);

        _user.tokensClaimed += toClaim;

        _token.transfer(msg.sender, toClaim);

    }
}