//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./structs/User.sol";
import "./enums/Status.sol";

interface IIDO {

    function status() external view returns(STATUS);

    receive() external payable;

    function getUser(address user) external view returns(User memory);

    function claimable(address user) external view returns(uint);

    function claim() external;

}