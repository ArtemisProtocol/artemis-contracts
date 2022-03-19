//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;
import "./extensions/IDOWithCollateral/IDOWithCollateral.sol";
contract IDOWithJustCollateral is IDOWithCollateral {
    constructor(Parameters memory parameters, CollateralInfo memory collateralInfo) IDO(parameters) IDOWithCollateral(collateralInfo) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}