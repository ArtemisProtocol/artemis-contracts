//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;
import "../../IDO.sol";
import "./IIDOWithWhitelist.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
abstract contract IDOWithWhitelist is IIDOWithWhitelist, IDO, AccessControlEnumerable {
    bytes32 public override WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");
    bytes32 public override WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");
    constructor() {
        _setRoleAdmin(WHITELISTED_ROLE, WHITELISTER_ROLE);
    }
    //Override IDO hook.
    function _beforeContribution(address addr, uint256 amount) internal virtual override {
        //Make sure user is whitelisted in order for the transaction to succeed.
        require(hasRole(WHITELISTED_ROLE, addr), "User has not been whitelisted.");
        super._beforeContribution(addr,amount);
    }
}