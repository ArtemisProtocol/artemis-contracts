//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Parameters {
    IERC20 token;
    uint256 forSale;
    uint256 asking;
    uint256 buyingStartsAt;
    uint256 buyingEndsAt;
    uint256 vestingStartsAt;
    uint256 vestingEndsAt;
    uint256 withdrawWait;
}
struct UserStats {
    uint256 contributed;
    uint256 claimed;
    uint256 refunded;
}
struct GlobalStats {
    uint256 contributed;
    uint256 claimed;
    uint256 withdrawn;
    uint256 returned;
}

interface IIDO  {

    event Contributed(address addr, uint256 amount);
    event Claimed(address addr, uint256 amount);
    event Refunded(address addr, uint256 amount);

    event Withdrawn(address addr, uint256 amount);
    event Returned(address addr, uint256 amount);

    function getGlobalStats() external view returns(GlobalStats memory);

    function getUserStatsOf(address addr) external view returns(UserStats memory);

    function getParameters() external view returns(Parameters memory);

    function contribute() external payable;

    function claim() external;

    function refund() external;

    function withdraw() external;

    function returnUnsold() external;

    function withdrawable() external view returns(uint256);

    function returnable() external view returns(uint256);

    function claimableOf(address addr) external view returns(uint256 claimable);

    function refundableOf(address addr) external view returns(uint256 refundable);

    function forceWithdraw(uint256 amount) external;

    function forceReturn(uint256 amount) external;

    function pause() external;

    function unpause() external;


}