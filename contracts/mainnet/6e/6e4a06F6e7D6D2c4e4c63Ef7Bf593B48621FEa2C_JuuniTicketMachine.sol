// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

//   _  _ _  _ _  _  _  _
//  | || | || | || \| || |
//  n_|||U || U || \\ || |
// \__/|___||___||_|\_||_|

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

struct Entry {
    // participant address
    address participantAddress;
    // start index inclusive
    uint64 startIndex;
    // end index inclusive
    uint64 endIndex;
}

struct EntryRequest {
    // participant address
    address participantAddress;
    // quantity of tickets
    uint256 ticketCount;
}

struct Reward {
    address rewardNFTAddress;
    uint256 tokenId;
}

contract JuuniTicketMachine is VRFConsumerBaseV2, Ownable {
    using Counters for Counters.Counter;

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    Counters.Counter private _raffleId;
    // _raffleId => address[] list of winner addresses for a raffle id
    mapping(uint256 => address[]) public winners;
    // address => _raffleId => totalEntries
    mapping(address => mapping(uint256 => uint256)) public raffleEntriesTracker;
    // _raffleId => Entry[]
    mapping(uint256 => Entry[]) private raffleEntries;
    // _raffleId => uint256[] raffle id to list of random numbres
    mapping(uint256 => uint256[]) public randomWordsByRaffle;
    // _raffleId => Reward, a list of reward for raffle
    mapping(uint256 => Reward[]) public raffleRewards;
    // To read past raffles
    uint256[] private finishedRaffles;

    // requestId --> requestStatus
    mapping(uint256 => RequestStatus) public s_requests;
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805;

    uint32 callbackGasLimit = 600000;

    uint16 requestConfirmations = 5;

    error AlreadyRegistered();
    error InvalidEntries();
    error InvalidRaffle();
    error InvalidWinnersCount();
    error NeedMoreRandomNumbers();
    error NoTicketsFound();
    error RaffleAlreadyResolved();
    error RaffleNoEntries();
    error RaffleNotAvailable();
    error RaffleRewardsNotRegistered();
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event RequestSent(uint256 requestId, uint32 numWords);

    modifier ensureRaffleIsOpen() {
        uint256 currentRaffleId = _raffleId.current();

        if (winners[currentRaffleId].length > 0) revert RaffleAlreadyResolved();

        if (raffleRewards[currentRaffleId].length == 0)
            revert RaffleRewardsNotRegistered();

        _;
    }

    constructor(
        uint64 subscriptionId,
        address coordinatorAddress
    ) VRFConsumerBaseV2(coordinatorAddress) {
        COORDINATOR = VRFCoordinatorV2Interface(coordinatorAddress);

        s_subscriptionId = subscriptionId;
    }

    function drawRandomNumbers(
        uint32 winnersCount
    ) external onlyOwner ensureRaffleIsOpen returns (uint256 requestId) {
        if (winnersCount == 0 || winnersCount >= 10)
            revert InvalidWinnersCount();
        uint32 wordsToRequest = winnersCount * 2;

        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            wordsToRequest
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });

        emit RequestSent(requestId, wordsToRequest);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        uint256 currentRaffleId = _raffleId.current();

        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        unchecked {
            for (uint256 i = 0; i < _randomWords.length; i++) {
                randomWordsByRaffle[currentRaffleId].push(_randomWords[i]);
            }
        }

        emit RequestFulfilled(_requestId, _randomWords);
    }

    function drawWinners() external onlyOwner ensureRaffleIsOpen {
        uint256 currentRaffleId = _raffleId.current();

        if (currentRaffleId == 0) revert RaffleNotAvailable();

        Entry[] storage entries = raffleEntries[currentRaffleId];

        if (entries.length == 0) revert RaffleNoEntries();

        uint256[] memory randomWords = randomWordsByRaffle[currentRaffleId];
        uint256 winnersCount = raffleRewards[currentRaffleId].length;
        uint256 selectedWinners;

        for (uint256 i = 0; i < randomWords.length; i++) {
            // safe to convert as entries[entries.length - 1].endIndex is going to be uint64 and we're modding by it
            uint64 randomIndex = uint64(
                randomWords[i] % _totalEntries(currentRaffleId)
            );

            Entry storage foundEntry = _searchRaffleBS(
                entries,
                0,
                uint64(entries.length - 1),
                randomIndex
            );

            if (_isAddressInCurrentWinnersList(foundEntry.participantAddress)) {
                // duplicate let's go to next random word
                continue;
            }

            winners[currentRaffleId].push(foundEntry.participantAddress);
            selectedWinners++;

            // Done selecting
            if (selectedWinners == winnersCount) {
                break;
            }
        }

        if (selectedWinners != winnersCount) revert NeedMoreRandomNumbers();
        finishedRaffles.push(currentRaffleId);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function getRandomWordsByRaffle(
        uint256 raffleId
    ) external view returns (uint256[] memory randomWords) {
        randomWords = randomWordsByRaffle[raffleId];
    }

    function getWinnersByRaffle(
        uint256 raffleId
    ) external view returns (address[] memory winnerAddresses) {
        winnerAddresses = winners[raffleId];
    }

    function getFinishedRaffles()
        external
        view
        returns (uint256[] memory raffles)
    {
        raffles = finishedRaffles;
    }

    function getNumWinnersByRaffle(uint256 id) external view returns (uint256) {
        return winners[id].length;
    }

    function getRaffleRewards(
        uint256 raffleId
    ) external view returns (Reward[] memory rewards) {
        rewards = raffleRewards[raffleId];
    }

    function totalEntries() external view returns (uint256 numEntries) {
        numEntries = _totalEntries(_raffleId.current());
    }

    function currentRaffle() external view returns (uint256) {
        return _raffleId.current();
    }

    function incrementRaffle() public onlyOwner {
        _raffleId.increment();
    }

    function setEntries(
        EntryRequest[] calldata newEntries
    ) external onlyOwner ensureRaffleIsOpen {
        if (newEntries.length == 0) revert InvalidEntries();

        uint256 raffleId = _raffleId.current();

        Entry[] memory currentRaffleEntries = raffleEntries[raffleId];
        uint64 startIndex = 0;

        // If there is already entries, take last one's end + 1 as new start
        if (raffleEntries[raffleId].length > 0) {
            startIndex =
                currentRaffleEntries[currentRaffleEntries.length - 1].endIndex +
                1;
        }

        unchecked {
            for (uint256 i = 0; i < newEntries.length; i++) {
                address participantAddress = newEntries[i].participantAddress;
                uint64 quantity = uint64(newEntries[i].ticketCount);

                if (newEntries[i].ticketCount == 0) {
                    revert NoTicketsFound();
                }

                if (raffleEntriesTracker[participantAddress][raffleId] > 0) {
                    revert AlreadyRegistered();
                }

                raffleEntries[raffleId].push(
                    Entry({
                        startIndex: startIndex,
                        endIndex: startIndex + quantity - 1,
                        participantAddress: participantAddress
                    })
                );

                // move start index
                startIndex = startIndex + quantity;

                raffleEntriesTracker[participantAddress][raffleId] = quantity;
            }
        }
    }

    function setRewards(Reward[] calldata rewards) external onlyOwner {
        raffleRewards[_raffleId.current()] = rewards;
    }

    function _totalEntries(uint256 raffleId) internal view returns (uint256) {
        Entry[] storage entries = raffleEntries[raffleId];

        if (entries.length == 0) return 0;

        return entries[entries.length - 1].endIndex + 1;
    }

    function _isAddressInCurrentWinnersList(
        address addr
    ) internal view returns (bool) {
        uint256 currentRaffleId = _raffleId.current();

        unchecked {
            for (uint256 i = 0; i < winners[currentRaffleId].length; i++) {
                if (winners[currentRaffleId][i] == addr) {
                    return true;
                }
            }

            return false;
        }
    }

    function _searchRaffleBS(
        Entry[] storage entries,
        uint64 start,
        uint64 end,
        uint64 target
    ) internal returns (Entry storage) {
        if (start == end) {
            return entries[start];
        }

        uint64 mid = (start + end) / 2;

        if (
            entries[mid].startIndex <= target && entries[mid].endIndex >= target
        ) {
            return entries[mid];
        }

        if (target < entries[mid].startIndex) {
            return _searchRaffleBS(entries, start, mid - 1, target);
        }

        return _searchRaffleBS(entries, mid + 1, end, target);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}