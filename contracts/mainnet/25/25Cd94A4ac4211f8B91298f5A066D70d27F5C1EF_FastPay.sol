// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Initializable.sol";
import "./OwnableUpgradeable.sol";
import "./TransferHelper.sol";
import "./SafeMath.sol";

contract FastPay is Initializable, OwnableUpgradeable{


    address public manager;

    address public singerManger;

    mapping(address => uint256) totalFeesOf;

    mapping(address => mapping(address => uint256)) public balanceOf;

    mapping(address => address[]) public merchantAddress;

    mapping(string => bool) public ordersOf;


    struct Withdraw {
        uint8 v;
        bytes32 r;
        bytes32 s;
        string orderNo;
        address token;
        address merchant;
        uint256 merchantAmt;
        address proxy;
        uint256 proxyAmt;
        uint256 fee;
        uint256 deadLine;
    }

    constructor(address _singerManger, address _manager) {
        singerManger = _singerManger;
        manager = _manager;
    }

    function initialize()public initializer{
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function getAddressCount(address _merchant) view external returns (uint256){
        return merchantAddress[_merchant].length;
    }

    function addMerchantAddress(
        address _merchant,
        address _addr
    ) external onlyManager {
        require(address(0) != _merchant);
        require(address(0) != _addr);
        merchantAddress[_merchant].push(_addr);
    }

    function cashSweep(
        address _token,
        uint256 _start
    ) external returns (uint256 sweepAmt) {
        sweepAmt = sweep(msg.sender, _token, _start);
        return sweepAmt;
    }

    function cashSweepAndWithdraw(
        Withdraw memory withdraw
    ) external {

        require(address(0) != withdraw.merchant);
        require(msg.sender == withdraw.merchant);
        require(withdraw.merchantAmt > 0);
        require(withdraw.deadLine > getTimes());

        verifyFee(withdraw);

        if(checkBalance(withdraw)) {

            withdrawFromBalance(withdraw);

        } else {

            sweep(withdraw.merchant, withdraw.token, 0);

            require(checkBalance(withdraw));

            withdrawFromBalance(withdraw);

        }

    }

    function checkBalance(
        Withdraw memory withdraw
    ) view internal returns(bool) {
        return balanceOf[withdraw.merchant][withdraw.token] >= withdraw.merchantAmt + withdraw.proxyAmt + withdraw.fee;
    }

    function withdrawFromBalance(
        Withdraw memory withdraw
    ) internal {

        TransferHelper.safeTransfer(withdraw.token, withdraw.merchant, withdraw.merchantAmt);
        balanceOf[withdraw.merchant][withdraw.token] -= withdraw.merchantAmt;

        if(address(0) != withdraw.proxy && 0 < withdraw.proxyAmt) {
            TransferHelper.safeTransfer(withdraw.token, withdraw.proxy, withdraw.proxyAmt);
            balanceOf[withdraw.merchant][withdraw.token] -= withdraw.proxyAmt;
        }

        balanceOf[withdraw.merchant][withdraw.token] -= withdraw.fee;
        totalFeesOf[withdraw.token] += withdraw.fee;

        require(balanceOf[withdraw.merchant][withdraw.token] >= 0);
        require(totalFeesOf[withdraw.token] >= withdraw.fee);

        ordersOf[withdraw.orderNo] = true;

    }

    function sweep(
        address _merchant,
        address _token,
        uint256 _start
    ) internal returns (uint256) {

        address [] memory addresses = merchantAddress[_merchant];
        uint256 sweepAmount = 0;
        uint256 count = 0;

        for(uint256 index = _start; index < addresses.length; index ++) {
            if(count > 500) {
                break;
            }
            count ++;
            if(index > addresses.length || address(0) == addresses[index]) {
                break;
            }

            uint256 balance = IERC20(_token).balanceOf(addresses[index]);
            uint256 allowance = IERC20(_token).allowance(addresses[index], address(this));

            if(balance > 0 && allowance >= balance) {
                TransferHelper.safeTransferFrom(_token, addresses[index], address(this), balance);
                sweepAmount =  SafeMath.add(sweepAmount, balance);
            }

        }

        balanceOf[_merchant][_token] += sweepAmount;

        return (sweepAmount);

    }

    function verifyFee(
        Withdraw memory withdraw
    ) view public {
        bytes32 eip712DomainHash = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("CashSweep")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256("cashSweep(address merchant,uint256 merchantAmt,address proxy,uint256 proxyAmt,uint256 fee,uint256 deadLine)"),
                withdraw.merchant,
                withdraw.merchantAmt,
                withdraw.proxy,
                withdraw.proxyAmt,
                withdraw.fee,
                withdraw.deadLine
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct));
        address signer = ecrecover(hash, withdraw.v, withdraw.r, withdraw.s);
        require(signer == singerManger, "MyFunction: invalid signature");
        require(signer != address(0), "ECDSA: invalid signature");
    }

    function getTimes() view public returns(uint256) {
        return block.timestamp;
    }

    function changeSinger(
        address _newSingerManger
    ) external onlyOwner {
        singerManger = _newSingerManger;
    }

    function changeManager(
        address _newManager
    ) onlyOwner external {
        manager = _newManager;
    }

    function claimFee(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        require(totalFeesOf[_token] >= _amount);
        TransferHelper.safeTransfer(_token, msg.sender, _amount);
        totalFeesOf[_token] -= _amount;
    }

    modifier onlyManager() {
        require(manager == msg.sender, "Manager: caller is not the manager");
        _;
    }
}