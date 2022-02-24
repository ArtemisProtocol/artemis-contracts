//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./IIDO.sol";

struct Participant {
    bool collateralPaid;
    bool collateralRefunded;

    uint bought;
    uint claimed;
}

contract IDO is IIDO, Ownable, Pausable {

    //Parameters for ICO.
    Params _params;

    //How many tokens have sold.
    uint _sold;
    //How many tokens have been claimed.
    uint _claimed;

    //Have paramaters been set yet?
    bool _initialised;

    //Data of participants.
    mapping(address => Participant) _participants;

    function getParams() public override view returns(Params memory) {
        return _params;
    }

    function initialise(Params memory params) public override onlyOwner {

        require(!_initialised, "ICO already initialised.");

        require(block.timestamp >= params.start, "ICO cannot begin before it is initialised.");
        require(params.end >= params.start, "ICO cannot end before it begins.");
        require(params.vestingStart >= params.end, "Vesting cannot start before ICO ends.");
        require(params.vestingEnd >= params.vestingStart, "Vesting cannot end before it begins.");

        require(params.withdrawee != address(0), "Withdrawee cannot be zero address.");

        _params = params;
        _initialised = true;

        emit Initialised();

    }

    /*
        Halts these actions:
        - Depositing collateral
        - Purchasing tokens
        - Claiming tokens

        Users will still be able to retrieve their collateral.
        Once the ICO is underway, and the values are all correct, owner may decide to renounce ownership so that investors won't fear this function.
    */
    function pause() public override onlyOwner {
        _pause();
    }

    /*
        Resumes these actions:
        - Depositing collateral
        - Purchasing tokens
        - Claiming tokens
    */
    function unpause() public override onlyOwner {
        _unpause();
    }

    function status() public override view returns(Status) {

        require(_initialised, "ICO has not been initialised.");

        if(block.timestamp < _params.start) {
            return Status.awaitingstart;
        }

        if(block.timestamp < _params.end) {
            return Status.inprogress;
        }

        if(block.timestamp < _params.vestingStart) {
            return Status.awaitingvesting;
        }

        if(block.timestamp < _params.vestingEnd) {
            return Status.vesting;
        }

        return Status.vestingended;

    }

    function depositCollateral() public override whenNotPaused {

        require(status() == Status.awaitingstart, "ICO has already begun.");

        Participant storage participant = _participants[msg.sender];

        require(!participant.collateralPaid);

        _params.collateralToken.transferFrom(msg.sender, address(this), _params.collateralAmount);
        participant.collateralPaid = true;

        emit CollateralPaid(msg.sender);

    }

    receive() external override whenNotPaused payable {

        require(status() == Status.inprogress, "ICO is not in progress.");

        uint toPurchase = (msg.value * _params.price.inReturn) / _params.price.asking;
        require(toPurchase <= _params.forSale - _sold, "Sold out.");
        _sold += toPurchase;

        Participant storage participant = _participants[msg.sender];

        require(participant.collateralPaid, "Collateral not paid.");

        participant.bought += toPurchase;

        emit TokensPurchased(msg.sender, toPurchase);

    }

    function retrieveCollateral() public override {

        require(_initialised, "ICO has not been initialised.");
        require(block.timestamp >= _params.end, "ICO has not ended yet.");

        Participant storage participant = _participants[msg.sender];

        require(participant.collateralPaid && !participant.collateralRefunded, "No collateral to retrieve.");

        _params.collateralToken.transfer(msg.sender, _params.collateralAmount);
        participant.collateralRefunded = true;

        emit CollateralRefunded(msg.sender);

    }

    function pendingClaimOf(address addr) public override view returns(uint) {

        require(_initialised, "ICO not initialised.");
        require(block.timestamp >= _params.vestingStart, "Vesting not started.");

        Participant storage participant = _participants[addr];

        //Time since vesting began.
        uint timeSince = block.timestamp - _params.vestingStart;
        //Overall time that vesting lasts.
        uint maxTime =_params. vestingEnd - _params.vestingStart;
        //Vested time is the greater value of the two.
        uint vestedTime = timeSince <= maxTime ? timeSince : maxTime;
        //Claimable up until this point in time.
        uint maxClaimable = (participant.bought * vestedTime) / maxTime;
        //Subtract total claimed already.
        uint claimable = maxClaimable - participant.claimed;

        return claimable;

    } 

    function claim() public override whenNotPaused {

        require(_initialised, "ICO not initialised.");
        require(block.timestamp >= _params.vestingStart, "Vesting not started.");

        uint toClaim = pendingClaimOf(msg.sender);

        Participant storage participant = _participants[msg.sender];

        _params.token.transfer(msg.sender, toClaim);
        participant.claimed += toClaim;
        _claimed += toClaim;

        emit TokensClaimed(msg.sender, toClaim);

    }

    //Withdraw all ONE and unsold tokens to withdrawee. Unrestricted, so that nobody can withhold the transfer to the rightful receiver.
    function finalWithdraw() public override {

        require(_initialised, "ICO has not been initialised.");

        require(block.timestamp >= _params.end, "ICO not ended.");

        (bool success,) = _params.withdrawee.call{value: address(this).balance}("");
        require(success);

        _params.token.transfer(_params.withdrawee, _params.token.balanceOf((address(this))) - (_sold - _claimed));

        emit FinalWithdraw();

    }

    //Forcefully withdraw balances. However, once the ICO is underway and the values are all correct, owner may decide to renounce ownership so that investors won't fear this function.
    function forceWithdraw(address to) public override {

        (bool success,) = to.call{value: address(this).balance}("");
        require(success);

        _params.token.transfer(to, _params.token.balanceOf((address(this))) - (_sold - _claimed));

    }

}