//SPDX-License-Identifier: Unlicensed
import "./IFOwithCollateralWithHook.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/AccessControl.sol";
pragma solidity ^0.6.0;
contract IDOwithCollateralWithWhitelist is IFOwithCollateralWithHook, AccessControl {
    bytes32 public override WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");
    bytes32 public override WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(WHITELISTED_ROLE, WHITELISTER_ROLE);
    }
    function _beforeDeposit(address addr, uint amount) internal virtual override {
        require(hasRole(WHITELISTED_ROLE, addr), "User has not been whitelisted.");
        super._beforeContribution(addr,amount);
    }
}