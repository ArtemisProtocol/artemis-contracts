//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;
import "./extensions/IDOWithCollateral/IDOWithCollateral.sol";
import "./extensions/IDOWithWhitelist/IDOWithWhitelist.sol";
contract IDOWithCollateralAndWhitelist is IDOWithCollateral, IDOWithWhitelist {
    constructor(Parameters memory parameters, CollateralInfo memory collateralInfo) IDO(parameters) IDOWithCollateral(collateralInfo) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    function _beforeContribution(address addr, uint256 amount) internal virtual override(IDOWithCollateral, IDOWithWhitelist) {
        super._beforeContribution(addr, amount);
    }
}