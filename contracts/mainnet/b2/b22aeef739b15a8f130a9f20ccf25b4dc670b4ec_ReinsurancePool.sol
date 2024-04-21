/**
 *Submitted for verification at Etherscan.io on 2022-10-18
*/

//SPDX-License-Identifier: MIT Licensed
pragma solidity ^0.8.6;

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external;

    function transfer(address to, uint256 value) external;

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external;

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ReinsurancePool {
    IERC20 public BizTrust = IERC20(0x95dA70f3CDd10b858A0440091d4917d9A9d7D50f);
    address public owner = 0xE0BbD92e506043B942a25B7DfE6321E6aFFFf9B9;

    uint256 public LockedToken;
    uint256 public UnlockTime;
    uint256 public unLockedToken;

    modifier onlyOwner() {
        require(msg.sender == owner, "PRESALE: Not an owner");
        _;
    }

    event LockToken(uint256 indexed _amount);
    event UnLockToken(uint256 indexed _amount);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {}

    // to Lock Tokens

    function LockBizTrust(uint256 _amount) public {
        BizTrust.transferFrom(msg.sender, address(this), _amount);
        LockedToken += _amount;
        UnlockTime = block.timestamp + 1 days;
    }

    // to UnLock Tokens
    function UnLockBizTrust(uint256 _amount) public onlyOwner {
        require(block.timestamp >= UnlockTime, "Time not reached yet");
        BizTrust.transfer(owner, _amount);
        LockedToken -= _amount;
        unLockedToken += _amount;
    }

    //to change  time
    function changeTime(uint256 _UnlockTime) public onlyOwner {
        UnlockTime = _UnlockTime;
    }

    // transfer ownership
    function changeOwner(address payable _newOwner) external onlyOwner {
        require(
            _newOwner != address(0),
            "_newOwner wallet cannot be address zero"
        );
        owner = _newOwner;
        emit OwnershipTransferred(owner, _newOwner);
    }   
}