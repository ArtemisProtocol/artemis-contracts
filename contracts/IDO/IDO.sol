//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IIDO.sol";
contract IDO is IIDO, Ownable, Pausable, ReentrancyGuard {

    using SafeERC20 for IERC20;

    //The rules of the IDO as well as the token being sold.
    Parameters internal _parameters;

    //Statistics including number of tokens sold.
    GlobalStats internal _globalStats;
    mapping(address=>UserStats) internal _userStats;

    constructor(Parameters memory parameters) {
        _parameters = parameters;
    }

    function getGlobalStats() external override view returns(GlobalStats memory) {
        return _globalStats;
    }

    function getUserStatsOf(address addr) external override view returns(UserStats memory) {
        return _userStats[addr];
    }

    function getParameters() external override view returns(Parameters memory) {
        return _parameters;
    }

    //Purchase tokens.
    function contribute() external override whenNotPaused payable {
        //Cannot contribute before and after the buying period. 
        require(block.timestamp >= _parameters.buyingStartsAt, "Buying has not begun yet.");
        require(block.timestamp < _parameters.buyingEndsAt, "Buying has ended.");
        //Call the hook function before contribution takes place.
        _beforeContribution(msg.sender, msg.value);
        //Update user's contribution.
        _userStats[msg.sender].contributed += msg.value;
        //Update global contribution amount.
        _globalStats.contributed += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    //Claim tokens released via vesting.
    function claim() external override nonReentrant whenNotPaused {
        //Cannot claim before vesting has begun.
        require(block.timestamp >= _parameters.vestingStartsAt, "Vesting has not begun yet.");
        UserStats storage userStats = _userStats[msg.sender];
        //Get claimable amount.
        uint256 toClaim = _claimableOfUserStats(userStats);
        //Update user's claimed amount.
        userStats.claimed += toClaim;
        //Update global claimed amount.
        _globalStats.claimed += toClaim;
        //Transfer tokens to user.
        _parameters.token.safeTransfer(msg.sender, toClaim);
        emit Claimed(msg.sender, toClaim);
    }

    //Refund excess ONE in the vent of overflow.
    function refund() external override nonReentrant whenNotPaused {
        //Cannot refund before the buying period ends.
        require(block.timestamp >= _parameters.buyingEndsAt, "Buying has not ended yet.");
        //Cannot refund unless there is overflow.
        require(_isOverflow(), "There was no overflow.");
        UserStats storage userStats = _userStats[msg.sender];
        //Get refundable amount.
        uint256 toRefund = _refundableOfUserStats(userStats);
        //Update user's refunded amount.
        userStats.refunded += toRefund;
        //Transfer ONE to user.
        (bool success,) = msg.sender.call{value: toRefund}("");
        require(success);
        emit Refunded(msg.sender, toRefund);
    }

    //Withdraw the ONE raised during the IDO.
    function withdraw() external override onlyOwner {
        //Require the buying period has ended.
        require(block.timestamp >= _parameters.buyingEndsAt + _parameters.withdrawWait, "Cannot withdraw yet.");
        //Get withdrawable amount.
        uint256 toWithdraw = withdrawable();
        //Update withdrawn amount.
        _globalStats.withdrawn += toWithdraw;
        //Transfer ONE to sender.
        (bool success,) = msg.sender.call{value: toWithdraw}("");
        require(success);
        emit Withdrawn(msg.sender, toWithdraw);
    }

    //Withdraw the tokens that were not sold during the IDO.
    function returnUnsold() external override onlyOwner {
        //Cannot withdraw until buying period ends.
        require(block.timestamp >= _parameters.buyingEndsAt, "Buying has not ended yet.");
        //Get returnable amount.
        uint256 toReturn = returnable();
        //Update returned amount.
        _globalStats.returned += toReturn;
        //Transfer tokens to sender.
        _parameters.token.safeTransfer(msg.sender, toReturn);
        emit Returned(msg.sender, toReturn);
    }

    //Get claimable amount of user.
    function claimableOf(address addr) external override view returns(uint256 claimable) {
        claimable = _claimableOfUserStats(_userStats[addr]);
    }

    //Get refundable amount of ONE of user.
    function refundableOf(address addr) external override view returns(uint256 refundable) {
        refundable = _refundableOfUserStats(_userStats[addr]);
    }

    //Forcefully withdraw ONE in the instance of emergency.
    function forceWithdraw(uint256 amount) external override onlyOwner {
        (bool success,) = msg.sender.call{value: amount}("");
        require(success);
    }

    //Forcefully withdraw tokens in the instance of emergency.
    function forceReturn(uint256 amount) external override onlyOwner {
        _parameters.token.safeTransfer(msg.sender, amount);
    }

    //Pause main functions of IDO.
    function pause() external override onlyOwner {
        _pause();
    }

    //Resume main functions of IDO.
    function unpause() external override onlyOwner {
        _unpause();
    }

    //Calculate the withdrawable amount of ONE due to overflow.
    function withdrawable() public override view returns(uint256) {
        if(block.timestamp < _parameters.buyingEndsAt) {
            return 0;
        }
        if(_isOverflow()) {
            return _parameters.asking - _globalStats.withdrawn;
        } 
        return _globalStats.contributed - _globalStats.withdrawn;
    }

    //Calculate the withdrawable amount of tokens due to lack of overflow.
    function returnable() public override view returns(uint256) {
        if(block.timestamp < _parameters.buyingEndsAt) {
            return 0;
        }
        if(_isOverflow()) {
            return 0;
        }
        return _parameters.forSale - ((_parameters.forSale * _globalStats.contributed) / _parameters.asking) - _globalStats.returned;
    }

    //Hook.
    function _beforeContribution(address addr, uint256 amount) internal virtual {

    }

    //Calculate claimable.
    function _claimableOfUserStats(UserStats storage userStats) private view returns(uint256 claimable) {
        //If vesting hasn't begun we know there is none to claim.
        if(block.timestamp < _parameters.vestingStartsAt) {
            return 0;
        }

        //Calculate the time vested within the vesting period.
        uint256 timeSinceVestingStarted = block.timestamp - _parameters.vestingStartsAt;
        uint256 maxTimeSinceVestingStarted = _parameters.vestingEndsAt - _parameters.vestingStartsAt;
        uint256 timeVested = timeSinceVestingStarted <= maxTimeSinceVestingStarted ? timeSinceVestingStarted : maxTimeSinceVestingStarted;

        uint256 maxClaimableSinceVestingStarted;

        if(_isOverflow()) {
            //Price is based on overflow.
            maxClaimableSinceVestingStarted = (userStats.contributed * _parameters.forSale) / _globalStats.contributed;
        } else {
            //Price is based on asking amount and amount for sale.
            maxClaimableSinceVestingStarted = (userStats.contributed * _parameters.asking) / _parameters.forSale;
        }

        //Calculate the amount claimable since the vesting period started.
        uint256 claimableSinceVestingStarted = (maxClaimableSinceVestingStarted * timeVested) / maxTimeSinceVestingStarted;

        //Subtract the amount the user has already claimed.
        claimable = claimableSinceVestingStarted - userStats.claimed;
    }

    //Calculate refundable.
    function _refundableOfUserStats(UserStats storage userStats) private view returns(uint256 refundable) {
        //If buying hasn't ended we know there is none to refund.
        if(block.timestamp < _parameters.buyingEndsAt) {
            return 0;
        }
        //If there is no overflow there is none to refund.
        if(!_isOverflow()) {
            return 0;
        }
        //Subtract the amount the user has already refunded.
        refundable = userStats.contributed - ((userStats.contributed * _parameters.asking) / _globalStats.contributed) - userStats.refunded;
    }


    //Check whether there is overflow.
    function _isOverflow() private view returns(bool) {
        //Contribution is higher than asking amount.
        return _globalStats.contributed > _parameters.asking;
    }
}