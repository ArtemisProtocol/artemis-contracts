//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;
import "./extensions/IDOWithWhitelist/IDOWithWhitelist.sol";
contract IDOWithJustWhitelist is IDOWithWhitelist {
    constructor(Parameters memory parameters) IDO(parameters) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}