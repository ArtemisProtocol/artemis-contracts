//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;

import "../../IDO.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./IIDOWithCollateral.sol";

abstract contract IDOWithCollateral is IIDOWithCollateral, IDO, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    bytes32 public override COLLATERALISED_ROLE = keccak256("COLLATERALISED_ROLE");
    //The details of the collateralisation such as the token and the amount of it.
    CollateralInfo private _collateralInfo;
    constructor(CollateralInfo memory collateralInfo) {
        _collateralInfo = collateralInfo;
    }
    //Get the collateral details.
    function getCollateralInfo() external view override returns(CollateralInfo memory) {
        return _collateralInfo;
    }
    //Pay the collateral.
    function collateralise() external nonReentrant override {
        //Cannot collateralise after buying starts.
        require(block.timestamp < _parameters.buyingStartsAt, "Cannot collateralise after buying starts.");
        //Make sure user is not already collateralised.
        require(!hasRole(COLLATERALISED_ROLE, msg.sender), "Already collateralised.");
        //Take payment.
        _collateralInfo.token.safeTransferFrom(msg.sender, address(this), _collateralInfo.amount);
        //Mark user as not collateralised.
        _grantRole(COLLATERALISED_ROLE, msg.sender);
        emit Collateralised(msg.sender);
    }
    //Refund the collateral.
    function refundCollateral() external nonReentrant override {
        //Cannot refund collateral before buying ends.
        require(block.timestamp >= _parameters.buyingEndsAt, "Buying has not ended yet.");
        //Check if user is even collateralised.
        require(hasRole(COLLATERALISED_ROLE, msg.sender), "Not collateralised.");
        //Refund the user.
        _collateralInfo.token.safeTransfer(msg.sender, _collateralInfo.amount);
        //Mark user as not collateralised.
        _revokeRole(COLLATERALISED_ROLE, msg.sender);
        emit CollateralRefunded(msg.sender);
    }
    //The hook of the IDO contract overridden.
    function _beforeContribution(address addr, uint256 amount) internal virtual override {
        //Make sure user is collateralised for the transaction to succeed.
        require(hasRole(COLLATERALISED_ROLE, addr), "User has not collateralised.");
        super._beforeContribution(addr, amount);
    }
}