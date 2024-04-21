// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MINTYSWAPMIGRATION {

    event OwnershipTransferred (address indexed previousOwner, address indexed newOwner);
    event TokenSwapped (address indexed account, uint256 indexed amount, uint256 indexed swapTime);

    address public owner;

    IERC20 public mintySwapV1;
    IERC20 public mintySwapV2;

    modifier onlyOwner {
        require(msg.sender == owner, "Ownable: caller is not a owner");
        _;
    }

    constructor (IERC20 _mintySwapV1, IERC20 _mintySwapV2) {
        owner = msg.sender;
        mintySwapV1 = _mintySwapV1;
        mintySwapV2 = _mintySwapV2;
    }

    function swapToken(uint256 amount) external returns(bool) {
        require(amount != 0,"Swapping: amount shouldn't be zero");
        mintySwapV1.transferFrom(msg.sender, address(this), amount);
        mintySwapV2.transfer(msg.sender, amount);
        emit TokenSwapped(msg.sender, amount, block.timestamp);
        return true;
    }

    function transferOwnership(address newOwner) external onlyOwner returns(bool) {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        return true;
    }

    function recoverETH(uint256 amount) external onlyOwner {
        payable(owner).transfer(amount);
    }

    function recoverToken(address tokenAddress,uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner, amount);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}