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

    function withdrawONE(address to, uint value) external;

    function withdrawTokens(address to, uint value) external;

    function setParams(IERC20 token, uint tokensForSale, IERC20 collateralToken, uint collateralRequired, uint ONEToRaise, uint buyingStartsAt, uint buyingEndsAt, uint vestingStartsAt, uint vestingEndsAt, uint timeToClaim) external;

    function isLockedIn() external view returns(bool);

    function lockIn() external;
}