//SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.13;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
struct CollateralInfo {
    IERC20 token;
    uint256 amount;
}
interface IIDOWithCollateral {
    event Collateralised(address addr);
    event CollateralRefunded(address addr);
    function COLLATERALISED_ROLE() external view returns(bytes32);
    function getCollateralInfo() external view returns(CollateralInfo memory);
    function collateralise() external;
    function refundCollateral() external;
}