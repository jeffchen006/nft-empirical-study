// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;
pragma abicoder v2;

import './IDelegate.sol';
import './IWETHUpgradable.sol';
import './MarketConsts.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

interface IX2Y2Run {
    function run1(
        Market.Order memory order,
        Market.SettleShared memory shared,
        Market.SettleDetail memory detail
    ) external returns (uint256);
}

contract X2Y2_r1 is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    IX2Y2Run
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event EvProfit(bytes32 itemHash, address currency, address to, uint256 amount);
    event EvAuctionRefund(
        bytes32 indexed itemHash,
        address currency,
        address to,
        uint256 amount,
        uint256 incentive
    );
    event EvInventory(
        bytes32 indexed itemHash,
        address maker,
        address taker,
        uint256 orderSalt,
        uint256 settleSalt,
        uint256 intent,
        uint256 delegateType,
        uint256 deadline,
        IERC20Upgradeable currency,
        bytes dataMask,
        Market.OrderItem item,
        Market.SettleDetail detail
    );
    event EvSigner(address signer, bool isRemoval);
    event EvDelegate(address delegate, bool isRemoval);
    event EvFeeCapUpdate(uint256 newValue);
    event EvCancel(bytes32 indexed itemHash);
    event EvFailure(uint256 index, bytes error);

    mapping(address => bool) public delegates;
    mapping(address => bool) public signers;

    mapping(bytes32 => Market.InvStatus) public inventoryStatus;
    mapping(bytes32 => Market.OngoingAuction) public ongoingAuctions;

    uint256 public constant RATE_BASE = 1e6;
    uint256 public feeCapPct;
    IWETHUpgradable public weth;

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function initialize(uint256 feeCapPct_, address weth_) public initializer {
        feeCapPct = feeCapPct_;
        weth = IWETHUpgradable(weth_);

        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();
        __Ownable_init_unchained();
    }

    function updateFeeCap(uint256 val) public virtual onlyOwner {
        feeCapPct = val;
        emit EvFeeCapUpdate(val);
    }

    function updateSigners(address[] memory toAdd, address[] memory toRemove)
        public
        virtual
        onlyOwner
    {
        for (uint256 i = 0; i < toAdd.length; i++) {
            signers[toAdd[i]] = true;
            emit EvSigner(toAdd[i], false);
        }
        for (uint256 i = 0; i < toRemove.length; i++) {
            delete signers[toRemove[i]];
            emit EvSigner(toRemove[i], true);
        }
    }

    function updateDelegates(address[] memory toAdd, address[] memory toRemove)
        public
        virtual
        onlyOwner
    {
        for (uint256 i = 0; i < toAdd.length; i++) {
            delegates[toAdd[i]] = true;
            emit EvDelegate(toAdd[i], false);
        }
        for (uint256 i = 0; i < toRemove.length; i++) {
            delete delegates[toRemove[i]];
            emit EvDelegate(toRemove[i], true);
        }
    }

    function cancel(
        bytes32[] memory itemHashes,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual nonReentrant whenNotPaused {
        require(deadline > block.timestamp, 'deadline reached');
        bytes32 hash = keccak256(abi.encode(itemHashes.length, itemHashes, deadline));
        address signer = ECDSA.recover(hash, v, r, s);
        require(signers[signer], 'Input signature error');

        for (uint256 i = 0; i < itemHashes.length; i++) {
            bytes32 h = itemHashes[i];
            if (inventoryStatus[h] == Market.InvStatus.NEW) {
                inventoryStatus[h] = Market.InvStatus.CANCELLED;
                emit EvCancel(h);
            }
        }
    }

    function run(Market.RunInput memory input) public payable virtual nonReentrant whenNotPaused {
        require(input.shared.deadline > block.timestamp, 'input deadline reached');
        require(msg.sender == input.shared.user, 'sender does not match');
        _verifyInputSignature(input);

        uint256 amountEth = msg.value;
        if (input.shared.amountToWeth > 0) {
            uint256 amt = input.shared.amountToWeth;
            weth.deposit{value: amt}();
            SafeERC20Upgradeable.safeTransfer(weth, msg.sender, amt);
            amountEth -= amt;
        }
        if (input.shared.amountToEth > 0) {
            uint256 amt = input.shared.amountToEth;
            SafeERC20Upgradeable.safeTransferFrom(weth, msg.sender, address(this), amt);
            weth.withdraw(amt);
            amountEth += amt;
        }

        for (uint256 i = 0; i < input.orders.length; i++) {
            _verifyOrderSignature(input.orders[i]);
        }

        for (uint256 i = 0; i < input.details.length; i++) {
            Market.SettleDetail memory detail = input.details[i];
            Market.Order memory order = input.orders[detail.orderIdx];
            if (input.shared.canFail) {
                try IX2Y2Run(address(this)).run1(order, input.shared, detail) returns (
                    uint256 ethPayment
                ) {
                    amountEth -= ethPayment;
                } catch Error(string memory _err) {
                    emit EvFailure(i, bytes(_err));
                } catch (bytes memory _err) {
                    emit EvFailure(i, _err);
                }
            } else {
                amountEth -= _run(order, input.shared, detail);
            }
        }
        if (amountEth > 0) {
            payable(msg.sender).transfer(amountEth);
        }
    }

    function run1(
        Market.Order memory order,
        Market.SettleShared memory shared,
        Market.SettleDetail memory detail
    ) external virtual returns (uint256) {
        require(msg.sender == address(this), 'unsafe call');

        return _run(order, shared, detail);
    }

    function _hashItem(Market.Order memory order, Market.OrderItem memory item)
        internal
        view
        virtual
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    order.salt,
                    order.user,
                    order.network,
                    order.intent,
                    order.delegateType,
                    order.deadline,
                    order.currency,
                    order.dataMask,
                    item
                )
            );
    }

    function _emitInventory(
        bytes32 itemHash,
        Market.Order memory order,
        Market.OrderItem memory item,
        Market.SettleShared memory shared,
        Market.SettleDetail memory detail
    ) internal virtual {
        emit EvInventory(
            itemHash,
            order.user,
            shared.user,
            order.salt,
            shared.salt,
            order.intent,
            order.delegateType,
            order.deadline,
            order.currency,
            order.dataMask,
            item,
            detail
        );
    }

    function _run(
        Market.Order memory order,
        Market.SettleShared memory shared,
        Market.SettleDetail memory detail
    ) internal virtual returns (uint256) {
        uint256 nativeAmount = 0;

        Market.OrderItem memory item = order.items[detail.itemIdx];
        bytes32 itemHash = _hashItem(order, item);

        {
            require(itemHash == detail.itemHash, 'item hash does not match');
            require(order.network == block.chainid, 'wrong network');
            require(
                address(detail.executionDelegate) != address(0) &&
                    delegates[address(detail.executionDelegate)],
                'unknown delegate'
            );
        }

        bytes memory data = item.data;
        {
            if (order.dataMask.length > 0 && detail.dataReplacement.length > 0) {
                _arrayReplace(data, detail.dataReplacement, order.dataMask);
            }
        }

        if (detail.op == Market.Op.COMPLETE_SELL_OFFER) {
            require(inventoryStatus[itemHash] == Market.InvStatus.NEW, 'order already exists');
            require(order.intent == Market.INTENT_SELL, 'intent != sell');
            _assertDelegation(order, detail);
            require(order.deadline > block.timestamp, 'deadline reached');
            require(detail.price >= item.price, 'underpaid');

            nativeAmount = _takePayment(itemHash, order.currency, shared.user, detail.price);
            require(
                detail.executionDelegate.executeSell(order.user, shared.user, data),
                'delegation error'
            );

            _distributeFeeAndProfit(
                itemHash,
                order.user,
                order.currency,
                detail,
                detail.price,
                detail.price
            );
            inventoryStatus[itemHash] = Market.InvStatus.COMPLETE;
        } else if (detail.op == Market.Op.COMPLETE_BUY_OFFER) {
            require(inventoryStatus[itemHash] == Market.InvStatus.NEW, 'order already exists');
            require(order.intent == Market.INTENT_BUY, 'intent != buy');
            _assertDelegation(order, detail);
            require(order.deadline > block.timestamp, 'deadline reached');
            require(item.price == detail.price, 'price not match');

            require(!_isNative(order.currency), 'native token not supported');

            nativeAmount = _takePayment(itemHash, order.currency, order.user, detail.price);
            require(
                detail.executionDelegate.executeBuy(shared.user, order.user, data),
                'delegation error'
            );

            _distributeFeeAndProfit(
                itemHash,
                shared.user,
                order.currency,
                detail,
                detail.price,
                detail.price
            );
            inventoryStatus[itemHash] = Market.InvStatus.COMPLETE;
        } else if (detail.op == Market.Op.CANCEL_OFFER) {
            require(inventoryStatus[itemHash] == Market.InvStatus.NEW, 'unable to cancel');
            require(order.deadline > block.timestamp, 'deadline reached');
            inventoryStatus[itemHash] = Market.InvStatus.CANCELLED;
            emit EvCancel(itemHash);
        } else if (detail.op == Market.Op.BID) {
            require(order.intent == Market.INTENT_AUCTION, 'intent != auction');
            _assertDelegation(order, detail);
            bool firstBid = false;
            if (ongoingAuctions[itemHash].bidder == address(0)) {
                require(inventoryStatus[itemHash] == Market.InvStatus.NEW, 'order already exists');
                require(order.deadline > block.timestamp, 'auction ended');
                require(detail.price >= item.price, 'underpaid');

                firstBid = true;
                ongoingAuctions[itemHash] = Market.OngoingAuction({
                    price: detail.price,
                    netPrice: detail.price,
                    bidder: shared.user,
                    endAt: order.deadline
                });
                inventoryStatus[itemHash] = Market.InvStatus.AUCTION;

                require(
                    detail.executionDelegate.executeBid(order.user, address(0), shared.user, data),
                    'delegation error'
                );
            }

            Market.OngoingAuction storage auc = ongoingAuctions[itemHash];
            require(auc.endAt > block.timestamp, 'auction ended');

            nativeAmount = _takePayment(itemHash, order.currency, shared.user, detail.price);

            if (!firstBid) {
                require(
                    inventoryStatus[itemHash] == Market.InvStatus.AUCTION,
                    'order is not auction'
                );
                require(
                    detail.price - auc.price >= (auc.price * detail.aucMinIncrementPct) / RATE_BASE,
                    'underbid'
                );

                uint256 bidRefund = auc.netPrice;
                uint256 incentive = (detail.price * detail.bidIncentivePct) / RATE_BASE;
                if (bidRefund + incentive > 0) {
                    _transferTo(order.currency, auc.bidder, bidRefund + incentive);
                    emit EvAuctionRefund(
                        itemHash,
                        address(order.currency),
                        auc.bidder,
                        bidRefund,
                        incentive
                    );
                }

                require(
                    detail.executionDelegate.executeBid(order.user, auc.bidder, shared.user, data),
                    'delegation error'
                );

                auc.price = detail.price;
                auc.netPrice = detail.price - incentive;
                auc.bidder = shared.user;
            }

            if (block.timestamp + detail.aucIncDurationSecs > auc.endAt) {
                auc.endAt += detail.aucIncDurationSecs;
            }
        } else if (
            detail.op == Market.Op.REFUND_AUCTION ||
            detail.op == Market.Op.REFUND_AUCTION_STUCK_ITEM
        ) {
            require(
                inventoryStatus[itemHash] == Market.InvStatus.AUCTION,
                'cannot cancel non-auction order'
            );
            Market.OngoingAuction storage auc = ongoingAuctions[itemHash];

            if (auc.netPrice > 0) {
                _transferTo(order.currency, auc.bidder, auc.netPrice);
                emit EvAuctionRefund(
                    itemHash,
                    address(order.currency),
                    auc.bidder,
                    auc.netPrice,
                    0
                );
            }
            _assertDelegation(order, detail);

            if (detail.op == Market.Op.REFUND_AUCTION) {
                require(
                    detail.executionDelegate.executeAuctionRefund(order.user, auc.bidder, data),
                    'delegation error'
                );
            }
            delete ongoingAuctions[itemHash];
            inventoryStatus[itemHash] = Market.InvStatus.REFUNDED;
        } else if (detail.op == Market.Op.COMPLETE_AUCTION) {
            require(
                inventoryStatus[itemHash] == Market.InvStatus.AUCTION,
                'cannot complete non-auction order'
            );
            _assertDelegation(order, detail);
            Market.OngoingAuction storage auc = ongoingAuctions[itemHash];
            require(block.timestamp >= auc.endAt, 'auction not finished yet');

            require(
                detail.executionDelegate.executeAuctionComplete(order.user, auc.bidder, data),
                'delegation error'
            );
            _distributeFeeAndProfit(
                itemHash,
                order.user,
                order.currency,
                detail,
                auc.price,
                auc.netPrice
            );

            inventoryStatus[itemHash] = Market.InvStatus.COMPLETE;
            delete ongoingAuctions[itemHash];
        } else {
            revert('unknown op');
        }

        _emitInventory(itemHash, order, item, shared, detail);
        return nativeAmount;
    }

    function _assertDelegation(Market.Order memory order, Market.SettleDetail memory detail)
        internal
        view
        virtual
    {
        require(
            detail.executionDelegate.delegateType() == order.delegateType,
            'delegation type error'
        );
    }

    // modifies `src`
    function _arrayReplace(
        bytes memory src,
        bytes memory replacement,
        bytes memory mask
    ) internal view virtual {
        require(src.length == replacement.length);
        require(src.length == mask.length);

        for (uint256 i = 0; i < src.length; i++) {
            if (mask[i] != 0) {
                src[i] = replacement[i];
            }
        }
    }

    function _verifyInputSignature(Market.RunInput memory input) internal view virtual {
        bytes32 hash = keccak256(abi.encode(input.shared, input.details.length, input.details));
        address signer = ECDSA.recover(hash, input.v, input.r, input.s);
        require(signers[signer], 'Input signature error');
    }

    function _verifyOrderSignature(Market.Order memory order) internal view virtual {
        address orderSigner;

        if (order.signVersion == Market.SIGN_V1) {
            bytes32 orderHash = keccak256(
                abi.encode(
                    order.salt,
                    order.user,
                    order.network,
                    order.intent,
                    order.delegateType,
                    order.deadline,
                    order.currency,
                    order.dataMask,
                    order.items.length,
                    order.items
                )
            );
            orderSigner = ECDSA.recover(
                ECDSA.toEthSignedMessageHash(orderHash),
                order.v,
                order.r,
                order.s
            );
        } else {
            revert('unknown signature version');
        }

        require(orderSigner == order.user, 'Order signature does not match');
    }

    function _isNative(IERC20Upgradeable currency) internal view virtual returns (bool) {
        return address(currency) == address(0);
    }

    function _takePayment(
        bytes32 itemHash,
        IERC20Upgradeable currency,
        address from,
        uint256 amount
    ) internal virtual returns (uint256) {
        if (amount > 0) {
            if (_isNative(currency)) {
                return amount;
            } else {
                currency.safeTransferFrom(from, address(this), amount);
            }
        }
        return 0;
    }

    function _transferTo(
        IERC20Upgradeable currency,
        address to,
        uint256 amount
    ) internal virtual {
        if (amount > 0) {
            if (_isNative(currency)) {
                AddressUpgradeable.sendValue(payable(to), amount);
            } else {
                currency.safeTransfer(to, amount);
            }
        }
    }

    function _distributeFeeAndProfit(
        bytes32 itemHash,
        address seller,
        IERC20Upgradeable currency,
        Market.SettleDetail memory sd,
        uint256 price,
        uint256 netPrice
    ) internal virtual {
        require(price >= netPrice, 'price error');

        uint256 payment = netPrice;
        uint256 totalFeePct;

        for (uint256 i = 0; i < sd.fees.length; i++) {
            Market.Fee memory fee = sd.fees[i];
            totalFeePct += fee.percentage;
            uint256 amount = (price * fee.percentage) / RATE_BASE;
            payment -= amount;
            _transferTo(currency, fee.to, amount);
        }

        require(feeCapPct >= totalFeePct, 'total fee cap exceeded');

        _transferTo(currency, seller, payment);
        emit EvProfit(itemHash, address(currency), seller, payment);
    }
}

// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;
pragma abicoder v2;

interface IDelegate {
    function delegateType() external view returns (uint256);

    function executeSell(
        address seller,
        address buyer,
        bytes calldata data
    ) external returns (bool);

    function executeBuy(
        address seller,
        address buyer,
        bytes calldata data
    ) external returns (bool);

    function executeBid(
        address seller,
        address previousBidder,
        address bidder,
        bytes calldata data
    ) external returns (bool);

    function executeAuctionComplete(
        address seller,
        address buyer,
        bytes calldata data
    ) external returns (bool);

    function executeAuctionRefund(
        address seller,
        address lastBidder,
        bytes calldata data
    ) external returns (bool);
}

// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';

interface IWETHUpgradable is IERC20Upgradeable {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;
pragma abicoder v2;

import './IDelegate.sol';
import './IWETHUpgradable.sol';

library Market {
    uint256 constant INTENT_SELL = 1;
    uint256 constant INTENT_AUCTION = 2;
    uint256 constant INTENT_BUY = 3;

    uint8 constant SIGN_V1 = 1;
    uint8 constant SIGN_V3 = 3;

    struct OrderItem {
        uint256 price;
        bytes data;
    }

    struct Order {
        uint256 salt;
        address user;
        uint256 network;
        uint256 intent;
        uint256 delegateType;
        uint256 deadline;
        IERC20Upgradeable currency;
        bytes dataMask;
        OrderItem[] items;
        // signature
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint8 signVersion;
    }

    struct Fee {
        uint256 percentage;
        address to;
    }

    struct SettleDetail {
        Market.Op op;
        uint256 orderIdx;
        uint256 itemIdx;
        uint256 price;
        bytes32 itemHash;
        IDelegate executionDelegate;
        bytes dataReplacement;
        uint256 bidIncentivePct;
        uint256 aucMinIncrementPct;
        uint256 aucIncDurationSecs;
        Fee[] fees;
    }

    struct SettleShared {
        uint256 salt;
        uint256 deadline;
        uint256 amountToEth;
        uint256 amountToWeth;
        address user;
        bool canFail;
    }

    struct RunInput {
        Order[] orders;
        SettleDetail[] details;
        SettleShared shared;
        // signature
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct OngoingAuction {
        uint256 price;
        uint256 netPrice;
        uint256 endAt;
        address bidder;
    }

    enum InvStatus {
        NEW,
        AUCTION,
        COMPLETE,
        CANCELLED,
        REFUNDED
    }

    enum Op {
        INVALID,
        // off-chain
        COMPLETE_SELL_OFFER,
        COMPLETE_BUY_OFFER,
        CANCEL_OFFER,
        // auction
        BID,
        COMPLETE_AUCTION,
        REFUND_AUCTION,
        REFUND_AUCTION_STUCK_ITEM
    }

    enum DelegationType {
        INVALID,
        ERC721,
        ERC1155
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}