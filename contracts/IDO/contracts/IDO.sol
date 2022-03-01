//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IIDO.sol";

contract IDO is IIDO, Ownable {

    IERC20 _token;
    IERC20 _collateralToken;
    uint _collateralRequired;
    uint _forSale;

    uint _asking;
    uint _contributed;

    uint _buyingStartsAt;
    uint _buyingEndsAt;

    uint _vestingStartsAt;
    uint _vestingEndsAt;

    uint _unsoldWithdrawn;
    uint _ONEWithdrawn;

    mapping(address => UserStats) _userStats;

    constructor(IERC20 token, IERC20 collateralToken, uint collateralRequired, uint forSale, uint asking, uint buyingStartsAt, uint buyingEndsAt, uint vestingStartsAt, uint vestingEndsAt) {
        token.transferFrom(msg.sender, address(this), forSale);
        _token = token;
        _collateralToken = collateralToken;
        _collateralRequired = collateralRequired;
        _asking = asking;
        _forSale = forSale;
        _buyingStartsAt = buyingStartsAt;
        _buyingEndsAt = buyingEndsAt;
        _vestingStartsAt = vestingStartsAt;
        _vestingEndsAt = vestingEndsAt;
    }

    function getToken() external override view returns(IERC20) {
        return _token;
    }
    function getCollateralToken() external override view returns(IERC20) {
        return _collateralToken;
    }
    function getCollateralRequired() external override view returns(uint) {
        return _collateralRequired;
    }
    function getForSale() external override view returns(uint) {
        return _forSale;
    }
    function getAsking() external override view returns(uint) {
        return _asking;
    }
    function getContributed() external override view returns(uint) {
        return _contributed;
    }
    function getBuyingStartsAt() external override view returns(uint) {
        return _buyingStartsAt;
    }
    function getBuyingEndsAt() external override view returns(uint) {
        return _buyingEndsAt;
    }
    function getVestingStartsAt() external override view returns(uint) {
        return _vestingStartsAt;
    }
    function getVestingEndsAt() external override view returns(uint) {
        return _vestingEndsAt;
    }
    function getTotalOwedOf(address addr) external override view returns(uint) {
        return _getTotalOwedOfStats(_userStats[addr]);
    }
    function getUnsoldTokens() public override view returns(uint unsold) {
        if(_contributed >= _asking) {
            return 0;
        }
        unsold = _forSale - ((_contributed * _asking) / _forSale);
    }
    function getUnsoldTokensWithdrawn() external override view returns(uint) {
        return _unsoldWithdrawn;
    }

    //pay the collateral.
    function payCollateral() external override {
        require(block.timestamp < _buyingStartsAt, "Buying has already begun.");
        UserStats storage userStats = _userStats[msg.sender];
        require(!userStats.collateralPaid);
        _collateralToken.transferFrom(msg.sender, address(this), _collateralRequired);
        userStats.collateralPaid = true;
    }

    //refund the collateral.
    function refundCollateral() external override {
        require(block.timestamp >= _buyingEndsAt, "Buying has not yet ended.");
        UserStats storage userStats = _userStats[msg.sender];
        require(userStats.collateralPaid);
        require(!userStats.collateralRefunded);
        _collateralToken.transfer(msg.sender, _collateralRequired);
        userStats.collateralRefunded = true;
    }

    //purchase tokens.
    function contribute() external override payable {
        //must be during buying period.
        require(block.timestamp >= _buyingStartsAt, "Buying has not yet begun.");
        require(block.timestamp < _buyingEndsAt, "Buying has already ended.");
        UserStats storage userStats = _userStats[msg.sender];
        require(userStats.collateralPaid);
        //update user data based on transaction value.
        _userStats[msg.sender].contributed += msg.value;
    }

    //claim purchased tokens.
    function claim() external override {
        UserStats storage userStats = _userStats[msg.sender];
        //get the claimable amount.
        uint toClaim = _getClaimableOfStats(userStats);
        //transfer the claimable amount.
        _token.transfer(msg.sender, toClaim);
        //update user data.
        userStats.claimed += toClaim;
    }

    //get the data of a certain user.
    function getUserStatsOf(address addr) external override view returns(UserStats memory) {
        return _userStats[addr];
    }

    //get the amount claimable for a user.
    function getClaimableOf(address addr) external override view returns(uint) {
        return _getClaimableOfStats(_userStats[addr]);
    }

    //refund excess ONE in the case of overflow.
    function refund() external override {
        require(block.timestamp >= _buyingEndsAt, "Buying has not yet ended.");

        UserStats storage userStats = _userStats[msg.sender];

        uint toRefund = _getRefundableOfStats(userStats);
        _token.transfer(msg.sender, toRefund);

        userStats.refunded += toRefund;
    }

    //withdraw tokens which did not sell.
    function withdrawUnsoldTokens(address to) external override onlyOwner {
        require(block.timestamp >= _buyingEndsAt, "Buying has not yet ended.");


        uint unsold = getUnsoldTokens();
        uint toWithdraw = unsold - _unsoldWithdrawn;

        _token.transfer(to, toWithdraw);
        _unsoldWithdrawn += toWithdraw;
    }

    //withdraw ONE.
    function withdrawONE(address to) external override onlyOwner {
        require(block.timestamp >= _buyingEndsAt, "Buying has not yet ended.");

        uint totalWithdrawable;
        if(_contributed <= _asking) {
            totalWithdrawable = _contributed;
        } else {
            totalWithdrawable = _asking;
        }
        uint withdrawable = totalWithdrawable - _ONEWithdrawn;
        _ONEWithdrawn -= withdrawable;
        (bool success,) = to.call{value: withdrawable}("");
        require(success);
    }

    //forcefully withdraw tokens.
    function forceWithdrawTokens(address addr, uint amount) external override onlyOwner {
        _token.transfer(addr, amount);
    }

    //forcefully withdraw ONE.
    function forceWithdrawONE(address addr, uint amount) external override onlyOwner {
        (bool success,) = addr.call{value: amount}("");
        require(success);
    }

    function _getClaimableOfStats(UserStats storage userStats) private view returns(uint claimable) {
        //vesting hasnt begun yet.
        if(block.timestamp < _vestingStartsAt) {
            return 0;
        }
        //maximum possible time vested.
        uint maximumTimeVested = _vestingEndsAt - _vestingStartsAt;
        //time since vesting started.
        uint timeSinceVestingStarted = block.timestamp - _vestingStartsAt;
        //time vested, taking into account maximum time vested.
        uint timeVested = timeSinceVestingStarted <= maximumTimeVested ? timeSinceVestingStarted : maximumTimeVested;
        //the amount owed over the entire vesting period.
        uint totalOwed = _getTotalOwedOfStats(userStats);
        //the amount owed if none has been claimed yet.
        uint owedSinceVestingStarted = (totalOwed * timeVested) / maximumTimeVested;
        //the amount after the claimed amount is taken into account.
        claimable = owedSinceVestingStarted - userStats.claimed;
    }

    function _getTotalOwedOfStats(UserStats storage userStats) private view returns(uint totalOwed) {
        if(_contributed > _asking) {
            //when there is overflow we use the amount contributed overall.
            totalOwed = (userStats.contributed * _forSale) / _contributed;
        } else {
            //when there isn't overflow we use the original price.
            totalOwed = (userStats.contributed * _asking) / _forSale; 
        }
    }

    function _getRefundableOfStats(UserStats storage userStats) private view returns(uint refundable) {
        //if there is no overflow there is no ONE to refund. 
        if(_contributed <= _asking) {
            return 0;
        }
        //the amount refundable if none has been refunded yet.
        uint totalRefundable = (userStats.contributed * _contributed) / _asking;
        //the amount refundable after the refunded amount is taken into account.
        refundable = totalRefundable - userStats.refunded;
    }



}