//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "miscsolidity/contracts/fee/FeeTakers.sol";
import "./IIDO.sol";

contract IDO is IIDO, Ownable, ReentrancyGuard, FeeTakers {

    bool _lockedIn;

    constructor(IERC20 token, uint tokensForSale, IERC20 collateralToken, uint collateralRequired, uint ONEToRaise, uint buyingStartsAt, uint buyingEndsAt, uint vestingStartsAt, uint vestingEndsAt, uint timeToClaim, uint maximumTokensPerWallet) {
        setParams(token, tokensForSale, collateralToken, collateralRequired, ONEToRaise, buyingStartsAt, buyingEndsAt, vestingStartsAt, vestingEndsAt, timeToClaim, maximumTokensPerWallet);
    }

    uint _timeToClaim;

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

    function isLockedIn() public override view returns(bool) {
        return _lockedIn;
    }

    receive() external override payable {

        require(status() == STATUS.inprogress, "Can only purchase when ICO is in progress.");
        require(_ONERaised + msg.value <= _ONEToRaise, "Maximum ONE raised reached.");

        User storage _user = _users[msg.sender];

        if(!_user.collateralPaid && _collateralRequired > 0) {
            _collateralToken.transferFrom(msg.sender, address(this), _collateralRequired);
            _user.collateralPaid = true;
            emit CollateralPaid(msg.sender);
        }

        uint toBuy = (msg.value * _tokensForSale) / _ONEToRaise;

        if(_enforceMaximumTokensPerWallet) {
            require(toBuy + _user.tokensBought <= _maximumTokensPerWallet, "Cannot purchase this many tokens.");
        }

        require(toBuy + _tokensSold <= _tokensForSale, "Cannot purchase this many tokens.");

        _tokensSold += toBuy;
        _user.tokensBought += toBuy;
        _ONERaised += msg.value;

        _distributeFee(msg.value);

        emit TokensPurchased(msg.sender, msg.value, toBuy);
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
        uint timeSince = block.timestamp - _vestingStartsAt;
        uint timeVested = timeSince > totalTimeVested ? totalTimeVested : timeSince;

        return ((_user.tokensBought * timeVested) / totalTimeVested) - _user.tokensClaimed; 

    }

    function claim() public override {

        require(status() == STATUS.claimable, "Wait until linear vesting begins.");

        User storage _user = _users[msg.sender];

        uint toClaim = claimable(msg.sender);

        _user.tokensClaimed += toClaim;

        _token.transfer(msg.sender, toClaim);

        emit TokensClaimed(msg.sender, toClaim);

    }

    function retrieveCollateral() public override {

        User storage _user = _users[msg.sender];

        require(_user.collateralPaid, "No collateral.");

        _collateralToken.transfer(msg.sender, _collateralRequired);

        emit CollateralRetrieved(msg.sender);
    }

    function withdrawONE(address to, uint value) public override onlyOwner {
        to.call{value: value}("");
    }

    function withdrawTokens(address to, uint value) public override onlyOwner {
        if(_lockedIn) {
            require(block.timestamp > _vestingEndsAt + _timeToClaim, "Must leave time for participants to collect.");
        }
        _token.transfer(to, value);
    }

    function lockIn() public override onlyOwner {
        if(!_lockedIn) {
            _lockedIn = true;
            emit Locked();
        }
    }

    function setParams(IERC20 token, uint tokensForSale, IERC20 collateralToken, uint collateralRequired, uint ONEToRaise, uint buyingStartsAt, uint buyingEndsAt, uint vestingStartsAt, uint vestingEndsAt, uint timeToClaim, uint maximumTokensPerWallet) public override onlyOwner {
        require(!_lockedIn, "Owner has locked in these parameters in the interest of decentralisation.");

        _token = token;
        _tokensForSale = tokensForSale;
        _collateralToken = collateralToken;
        _collateralRequired = collateralRequired;
        _ONEToRaise = ONEToRaise;
        _buyingStartsAt = buyingStartsAt;
        _buyingEndsAt = buyingEndsAt;
        _vestingStartsAt = vestingStartsAt;
        _vestingEndsAt = vestingEndsAt;
        _timeToClaim = timeToClaim;
        _maximumTokensPerWallet = maximumTokensPerWallet;

        if(maximumTokensPerWallet > 0) {
            if(!_enforceMaximumTokensPerWallet) {
                _enforceMaximumTokensPerWallet = true;
            }
        } else if(_enforceMaximumTokensPerWallet) {
            _enforceMaximumTokensPerWallet = false;
        }

        _checkValid();

        emit ParamsSet(token, tokensForSale, collateralToken, collateralRequired, ONEToRaise, buyingStartsAt, buyingEndsAt, vestingStartsAt, vestingEndsAt, timeToClaim);
    }

    function _checkValid() private view {
        
        try _token.balanceOf(address(this)) returns(uint) {
        } catch {
            revert("Token is not valid.");
        }

        try _collateralToken.balanceOf(address(this)) returns(uint) {
        } catch {
            revert("Collateral token is not valid.");
        }

        require(_buyingEndsAt >= _buyingStartsAt, "Buying cannot end before it begins.");

        require(_vestingStartsAt > _buyingEndsAt, "Vesting must begin after buying ends.");

        require(_vestingEndsAt > _vestingStartsAt, "Vesting cannot end before it begins.");

    }

}