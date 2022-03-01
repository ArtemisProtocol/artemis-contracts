//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
struct UserStats {
    bool collateralPaid;
    bool collateralRefunded;
    uint contributed;
    uint refunded;
    uint claimed;
}
interface IIDO {
    function getToken() external view returns(IERC20);
    function getCollateralToken() external view returns(IERC20);
    function getCollateralRequired() external view returns(uint);
    function getForSale() external view returns(uint);
    function getAsking() external view returns(uint);
    function getContributed() external view returns(uint);
    function getBuyingStartsAt() external view returns(uint);
    function getBuyingEndsAt() external view returns(uint);
    function getVestingStartsAt() external view returns(uint);
    function getVestingEndsAt() external view returns(uint);
    function getUnsoldTokens() external view returns(uint unsold);
    function getUnsoldTokensWithdrawn() external view returns(uint);

    function payCollateral() external;
    function refundCollateral() external;

    function contribute() external payable;
    function claim() external;
    function refund() external;
    function getUserStatsOf(address addr) external view returns(UserStats memory);
    function getTotalOwedOf(address addr) external view returns(uint);
    function getClaimableOf(address addr) external view returns(uint);
    function withdrawUnsoldTokens(address to) external;
    function withdrawONE(address to) external;
    function forceWithdrawTokens(address addr, uint amount) external;
    function forceWithdrawONE(address addr, uint amount) external;
}