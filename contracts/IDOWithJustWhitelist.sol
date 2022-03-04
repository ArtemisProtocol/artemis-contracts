//SPDX-License-Identifier: Unlicensed
import "./extensions/IDOWithWhitelist/IDOWithWhitelist.sol";
pragma solidity ^0.8.0;
contract IDOWithJustCollateral is IDOWithWhitelist {
    constructor(Parameters memory parameters) IDO(parameters) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}