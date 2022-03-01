//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


enum Status {

    awaitingstart,
    inprogress,
    awaitingvesting,
    vesting,
    vestingended

}

struct Price {
    uint asking;
    uint inReturn;
}

struct Params {

    //When tokens start being purchaseable.
    uint start;
    //When tokens stop being purchaseable.
    uint end;

    //When tokens start being linearly released.
    uint vestingStart;
    //When tokens stop being linearly released.
    uint vestingEnd;

    //How many tokens are for sale.
    uint forSale;

    //Price ratio from ONE to tokens.
    Price price;

    //Amount of collateral to lock in during ICO.
    uint collateralAmount;

    //Receiver of final withdraw
    address withdrawee;

}

interface IICO {

    function initialise(Params memory params) external;

    function pause() external;

    function unpause() external;

    function status() external view returns(Status);

    function depositCollateral() external;

    receive() external payable;

    function retrieveCollateral() external;

    function pendingClaimOf(address addr) external view returns(uint);

    function claim() external;

    function finalWithdraw() external;

    function forceWithdraw(address to) external;

}