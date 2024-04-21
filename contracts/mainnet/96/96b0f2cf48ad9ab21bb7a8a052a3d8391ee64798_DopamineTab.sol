// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "../interfaces/Errors.sol";
import { IDopamineTab } from "../interfaces/IDopamineTab.sol";
import { IOpenSeaProxyRegistry } from "../interfaces/IOpenSeaProxyRegistry.sol";

import { ERC721 } from "../erc721/ERC721.sol";
import { ERC721Votable } from "../erc721/ERC721Votable.sol";

/// @title Dopamine Membership Tab
/// @notice Tab holders are first-class members of the Dopamine metaverse.
///  The tabs are minted through seasonal drops of varying sizes and durations,
///  with each drop featuring different sets of attributes. Drop parameters are
///  configurable by the admin address, with emissions controlled by the minter
///  address. A drop is completed once all non-allowlisted tabs are minted.
contract DopamineTab is ERC721Votable, IDopamineTab {

    /// @notice The maximum number of tabs that may be allowlisted per drop.
    uint256 public constant MAX_AL_SIZE = 99;

    /// @notice The minimum number of tabs that can be minted for a drop.
    uint256 public constant MIN_DROP_SIZE = 1;

    /// @notice The maximum number of tabs that can be minted for a drop.
    uint256 public constant MAX_DROP_SIZE = 9999;

    /// @notice The minimum delay required to wait between creations of drops.
    uint256 public constant MIN_DROP_DELAY = 1 days;

    /// @notice The maximum delay required to wait between creations of drops.
    uint256 public constant MAX_DROP_DELAY = 24 weeks;

    /// @notice The address administering drop creation, sizing, and scheduling.
    address public admin;

    /// @notice The temporary address that will become admin once accepted.
    address public pendingAdmin;

    /// @notice The address responsible for controlling tab emissions.
    address public minter;

    /// @notice The OS registry address - allowlisted for gasless OS approvals.
    IOpenSeaProxyRegistry public proxyRegistry;

    /// @notice The URI each tab initially points to for metadata resolution.
    /// @dev Before drop completion, `tokenURI()` resolves to "{baseURI}/{id}".
    string public baseURI;

    /// @notice The minimum time to wait in seconds between drop creations.
    uint256 public dropDelay;

    /// @notice The current drop's ending tab id (exclusive boundary).
    uint256 public dropEndIndex;

    /// @notice The time at which a new drop can start (if last drop completes).
    uint256 public dropEndTime;

    /// @notice Maps a drop to its allowlist (merkle tree root).
    mapping(uint256 => bytes32) public dropAllowlist;

    /// @notice Maps a drop to its provenance hash (concatenated image hash).
    mapping(uint256 => bytes32) public dropProvenanceHash;

    /// @notice Maps a drop to its finalized IPFS / Arweave tab metadata URI.
    mapping(uint256 => string) public dropURI;

    /// @dev Maps a drop id to its ending tab id (exclusive boundary).
    uint256[] private _dropEndIndices;

    /// @dev An internal tracker for the id of the next tab to mint.
    uint256 private _id;

    /// @dev Restricts a function call to address `minter`.
    modifier onlyMinter() {
        if (msg.sender != minter) {
            revert MinterOnly();
        }
        _;
    }

    /// @dev Restricts a function call to address `admin`.
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert AdminOnly();
        }
        _;
    }

    /// @notice Initializes the membership tab with the specified drop settings.
    /// @param minter_ The address which will control tab emissions.
    /// @param proxyRegistry_ The OS proxy registry address.
    /// @param dropDelay_ The minimum delay to wait between drop creations.
    /// @param maxSupply_ The supply for the tab collection.
    constructor(
        string memory baseURI_,
        address minter_,
        address proxyRegistry_,
        uint256 dropDelay_,
        uint256 maxSupply_
    ) ERC721Votable("Dopamine Tabs", "TAB", maxSupply_) {
        admin = msg.sender;
        emit AdminChanged(address(0), admin);

        minter = minter_;
        emit MinterChanged(address(0), minter);

        baseURI = baseURI_;
        emit BaseURISet(baseURI);

        proxyRegistry = IOpenSeaProxyRegistry(proxyRegistry_);

        setDropDelay(dropDelay_);
    }

    /// @inheritdoc IDopamineTab
    function contractURI() external view returns (string memory)  {
        return string(abi.encodePacked(baseURI, "contract"));
    }

    /// @inheritdoc ERC721
    /// @dev Before drop completion, the token URI for tab of id `id` defaults
    ///  to {baseURI}/{id}. Once the drop completes, it is replaced by an IPFS /
    ///  Arweave URI, and `tokenURI()` will resolve to {dropURI[dropId]}/{id}.
    ///  This function reverts if the queried tab of id `id` does not exist.
    /// @param id The id of the NFT being queried.
    function tokenURI(uint256 id)
        external
        view
        override(ERC721)
        returns (string memory)
    {
        if (ownerOf[id] == address(0)) {
            revert TokenNonExistent();
        }

        string memory uri = dropURI[dropId(id)];
        if (bytes(uri).length == 0) {
            uri = baseURI;
        }
        return string(abi.encodePacked(uri, _toString(id)));
    }


    /// @dev Ensures OS proxy is allowlisted for operating on behalf of owners.
    /// @inheritdoc ERC721
    function isApprovedForAll(address owner, address operator)
        external
        view
        override
        returns (bool)
    {
        return
            proxyRegistry.proxies(owner) == operator ||
            _operatorApprovals[owner][operator];
    }

    /// @inheritdoc IDopamineTab
    function mint() external onlyMinter returns (uint256) {
        if (_id >= dropEndIndex) {
            revert DropMaxCapacity();
        }
        return _mint(minter, _id++);
    }

    /// @inheritdoc IDopamineTab
    function claim(bytes32[] calldata proof, uint256 id) external {
        if (id >= _id) {
            revert ClaimInvalid();
        }

        bytes32 allowlist = dropAllowlist[dropId(id)];
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, id));

        if (!_verify(allowlist, proof, leaf)) {
            revert ProofInvalid();
        }

        _mint(msg.sender, id);
    }

    /// @inheritdoc IDopamineTab
    function createDrop(
        uint256 dropId,
        uint256 startIndex,
        uint256 dropSize,
        bytes32 provenanceHash,
        uint256 allowlistSize,
        bytes32 allowlist
    )
        external
        onlyAdmin
    {
        if (_id < dropEndIndex) {
            revert DropOngoing();
        }
        if (startIndex != _id) {
            revert DropStartInvalid();
        }
        if (dropId != _dropEndIndices.length) {
            revert DropInvalid();
        }
        if (block.timestamp < dropEndTime) {
            revert DropTooEarly();
        }
        if (allowlistSize > MAX_AL_SIZE || allowlistSize > dropSize) {
            revert DropAllowlistOverCapacity();
        }
        if (
            dropSize < MIN_DROP_SIZE ||
            dropSize > MAX_DROP_SIZE
        ) {
            revert DropSizeInvalid();
        }
        if (_id + dropSize > maxSupply) {
            revert DropMaxCapacity();
        }

        dropEndIndex = _id + dropSize;
        _id += allowlistSize;
        _dropEndIndices.push(dropEndIndex);

        dropEndTime = block.timestamp + dropDelay;

        dropProvenanceHash[dropId] = provenanceHash;
        dropAllowlist[dropId] = allowlist;

        emit DropCreated(
            dropId,
            startIndex,
            dropSize,
            allowlistSize,
            allowlist,
            provenanceHash
        );
    }

    /// @inheritdoc IDopamineTab
    function setMinter(address newMinter) external onlyAdmin {
        emit MinterChanged(minter, newMinter);
        minter = newMinter;
    }

    /// @inheritdoc IDopamineTab
    function setPendingAdmin(address newPendingAdmin)
        public
        override
        onlyAdmin
    {
        pendingAdmin = newPendingAdmin;
        emit PendingAdminSet(pendingAdmin);
    }

    /// @inheritdoc IDopamineTab
    function acceptAdmin() public override {
        if (msg.sender != pendingAdmin) {
            revert PendingAdminOnly();
        }

        emit AdminChanged(admin, pendingAdmin);
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    /// @inheritdoc IDopamineTab
    function setDropURI(uint256 id, string calldata uri)
        external
        onlyAdmin
    {
        uint256 numDrops = _dropEndIndices.length;
        if (id >= numDrops) {
            revert DropNonExistent();
        }
        dropURI[id] = uri;
        emit DropURISet(id, uri);
    }


    /// @inheritdoc IDopamineTab
    function updateDrop(
        uint256 dropId,
        bytes32 provenanceHash,
        bytes32 allowlist
    ) external onlyAdmin {
        uint256 numDrops = _dropEndIndices.length;
        if (dropId >= numDrops) {
            revert DropNonExistent();
        }

        // Once a drop's URI is set, it may not be modified.
        if (bytes(dropURI[dropId]).length != 0) {
            revert DropImmutable();
        }

        dropProvenanceHash[dropId] = provenanceHash;
        dropAllowlist[dropId] = allowlist;

        emit DropUpdated(
            dropId,
            provenanceHash,
            allowlist
        );
    }

    /// @inheritdoc IDopamineTab
    function setBaseURI(string calldata newBaseURI) public onlyAdmin {
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    /// @inheritdoc IDopamineTab
    function setDropDelay(uint256 newDropDelay) public override onlyAdmin {
        if (newDropDelay < MIN_DROP_DELAY || newDropDelay > MAX_DROP_DELAY) {
            revert DropDelayInvalid();
        }
        dropDelay = newDropDelay;
        emit DropDelaySet(dropDelay);
    }

    /// @inheritdoc IDopamineTab
    function dropId(uint256 id) public view returns (uint256) {
        for (uint256 i = 0; i < _dropEndIndices.length; i++) {
            if (id  < _dropEndIndices[i]) {
                return i;
            }
        }
        revert DropNonExistent();
    }

    /// @dev Checks whether `leaf` is part of merkle tree rooted at `merkleRoot`
    ///  using proof `proof`. Merkle tree generation and proof construction is
    ///  done using the following JS library: github.com/miguelmota/merkletreejs
    /// @param merkleRoot The hexlified merkle root as a bytes32 data type.
    /// @param proof The abi-encoded proof formatted as a bytes32 array.
    /// @param leaf The leaf node being checked (uses keccak-256 hashing).
    /// @return True if `leaf` is in `merkleRoot`-rooted tree, False otherwise.
    function _verify(
        bytes32 merkleRoot,
        bytes32[] memory proof,
        bytes32 leaf
    ) private pure returns (bool)
    {
        bytes32 hash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (hash <= proofElement) {
                hash = keccak256(abi.encodePacked(hash, proofElement));
            } else {
                hash = keccak256(abi.encodePacked(proofElement, hash));
            }
        }
        return hash == merkleRoot;
    }

    /// @dev Converts a uint256 into a string.
    function _toString(uint256 value) private pure returns (string memory) {
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
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

// This file is a shared repository of all errors used in Dopamine's contracts.

////////////////////////////////////////////////////////////////////////////////
///                              Dopamine Tab                                ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Configured drop delay is invalid.
error DropDelayInvalid();

/// @notice Drop identifier is invalid.
error DropInvalid();

/// @notice Drop details may no longer be modified.
error DropImmutable();

/// @notice Drop hit max allocatable capacity.
error DropMaxCapacity();

/// @notice No such drop exists.
error DropNonExistent();

/// @notice Action cannot be completed as a current drop is ongoing.
error DropOngoing();

/// @notice Configured drop size is invalid.
error DropSizeInvalid();

/// @notice Drop starting index is incorrect.
error DropStartInvalid();

/// @notice Insufficient time passed since last drop was created.
error DropTooEarly();

/// @notice Configured allowlist size is too large.
error DropAllowlistOverCapacity();

////////////////////////////////////////////////////////////////////////////////
///                          Dopamine Auction House                          ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Auction has already been settled.
error AuctionAlreadySettled();

/// @notice Operation cannot be performed as auction is already suspended.
error AuctionAlreadySuspended();

/// @notice The NFT specified in the auction bid is invalid.
error AuctionBidInvalid();

/// @notice Bid placed was too low.
error AuctionBidTooLow();

/// @notice Auction duration set is invalid.
error AuctionDurationInvalid();

/// @notice The auction has expired.
error AuctionExpired();

/// @notice Operation cannot be performed as auction is not suspended.
error AuctionNotSuspended();

/// @notice Auction has yet to complete.
error AuctionOngoing();

/// @notice Reserve price set is invalid.
error AuctionReservePriceInvalid();

/// @notice Time buffer set is invalid.
error AuctionBufferInvalid();

/// @notice Treasury split is invalid, must be in range [0, 100].
error AuctionTreasurySplitInvalid();

////////////////////////////////////////////////////////////////////////////////
///                              Miscellaneous                               ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Mismatch between input arrays.
error ArityMismatch();

/// @notice Block number being queried is invalid.
error BlockInvalid();

/// @notice Reentrancy vulnerability.
error FunctionReentrant();

/// @notice Number does not fit in 32 bytes.
error Uint32ConversionInvalid();

////////////////////////////////////////////////////////////////////////////////
///                                 Upgrades                                 ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Contract already initialized.
error ContractAlreadyInitialized();

/// @notice Upgrade requires either admin or vetoer privileges.
error UpgradeUnauthorized();

////////////////////////////////////////////////////////////////////////////////
///                                 EIP-712                                  ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Signature has expired and is no longer valid.
error SignatureExpired();

/// @notice Signature invalid.
error SignatureInvalid();

////////////////////////////////////////////////////////////////////////////////
///                                 EIP-721                                  ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Originating address does not own the NFT.
error OwnerInvalid();

/// @notice Receiving address cannot be the zero address.
error ReceiverInvalid();

/// @notice Receiving contract does not implement the ERC-721 wallet interface.
error SafeTransferUnsupported();

/// @notice Sender is not NFT owner, approved address, or owner operator.
error SenderUnauthorized();

/// @notice NFT supply has hit maximum capacity.
error SupplyMaxCapacity();

/// @notice Token has already minted.
error TokenAlreadyMinted();

/// @notice NFT does not exist.
error TokenNonExistent();

////////////////////////////////////////////////////////////////////////////////
///                              Administrative                              ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Function callable only by the admin.
error AdminOnly();

/// @notice Function callable only by the minter.
error MinterOnly();

/// @notice Function callable only by the owner.
error OwnerOnly();

/// @notice Function callable only by the pending owner.
error PendingAdminOnly();

////////////////////////////////////////////////////////////////////////////////
///                                Governance                                ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Invalid number of actions proposed.
error ProposalActionCountInvalid();

/// @notice Proposal has already been settled.
error ProposalAlreadySettled();

/// @notice Inactive proposals may not be voted for.
error ProposalInactive();

/// @notice Proposal has failed to or has yet to be queued.
error ProposalNotYetQueued();

/// @notice Quorum threshold is invalid.
error ProposalQuorumThresholdInvalid();

/// @notice Proposal threshold is invalid.
error ProposalThresholdInvalid();

/// @notice Proposal has failed to or has yet to be successful.
error ProposalUnpassed();

/// @notice A proposal is currently running and must be settled first.
error ProposalUnsettled();

/// @notice Voting delay set is invalid.
error ProposalVotingDelayInvalid();

/// @notice Voting period set is invalid.
error ProposalVotingPeriodInvalid();

/// @notice Only the proposer may invoke this action.
error ProposerOnly();

/// @notice Function callable only by the vetoer.
error VetoerOnly();

/// @notice Veto power has been revoked.
error VetoPowerRevoked();

/// @notice Proposal already voted for.
error VoteAlreadyCast();

/// @notice Vote type is not valid.
error VoteInvalid();

/// @notice Voting power insufficient.
error VotingPowerInsufficient();

////////////////////////////////////////////////////////////////////////////////
///                                 Timelock                                 ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Invalid set timelock delay.
error TimelockDelayInvalid();

/// @notice Function callable only by the timelock itself.
error TimelockOnly();

/// @notice Duplicate transaction queued.
error TransactionAlreadyQueued();

/// @notice Transaction is not yet queued.
error TransactionNotYetQueued();

/// @notice Transaction executed prematurely.
error TransactionPremature();

/// @notice Transaction execution was reverted.
error TransactionReverted();

/// @notice Transaction is stale.
error TransactionStale();

////////////////////////////////////////////////////////////////////////////////
///                             Merkle Allowlist                             ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Claim drop identifier is invalid.
error ClaimInvalid();

/// @notice Proof for claim is invalid.
error ProofInvalid();

///////////////////////////////////////////////////////////////////////////////
///                           EIP-2981 Royalties                             ///
////////////////////////////////////////////////////////////////////////////////

/// @notice Royalties are set too high.
error RoyaltiesTooHigh();

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "./IDopamineTabEvents.sol";

/// @title Dopamine Membership Tab Interface
interface IDopamineTab is IDopamineTabEvents {

    /// @notice Mints a dopamine tab to the minter address.
    /// @dev This function is only callable by the minter address.
    /// @return Id of the minted tab, which is always equal to `_id`.
    function mint() external returns (uint256);

    /// @notice Mints an allowlisted tab of id `id` to the sender address if
    ///  merkle proof `proof` proves they were allowlisted with that tab id.
    /// @dev Reverts if invalid proof is provided or claimer isn't allowlisted.
    ///  The allowlist is formed using encoded tuple leaves (address, id). The
    ///  Merkle Tree JS library used: https://github.com/miguelmota/merkletreejs
    /// @param proof The Merkle proof of the claim as a bytes32 array.
    /// @param id The id of the Dopamine tab being claimed.
    function claim(bytes32[] calldata proof, uint256 id) external;

    /// @notice Creates a new Dopamine tab drop.
    /// @dev This function is only callable by the admin address, and reverts if
    ///  an ongoing drop exists, drop starting index is invalid, call is too
    //   early, drop identifier is invalid, allowlist size is too large,
    ///  drop size is too small or too large, or max capacity was reached.
    /// @param dropId The drop's id (must 1 + last drop id).
    /// @param startIndex The drop's start index (must be last `dropEndIndex`).
    /// @param dropSize The total number of tabs of the drop (incl. allowlist).
    /// @param provenanceHash An immutable provenance hash equal to the SHA-256
    ///  hash of the concatenation of all SHA-256 image hashes of the drop.
    /// @param allowlistSize The total number of allowlisted tabs of the drop.
    /// @param allowlist Merkle root comprised of allowlisted address-tab pairs.
    function createDrop(
        uint256 dropId,
        uint256 startIndex,
        uint256 dropSize,
        bytes32 provenanceHash,
        uint256 allowlistSize,
        bytes32 allowlist
    ) external;

    /// @notice Gets the admin address, which controls drop settings & creation.
    function admin() external view returns (address);

    /// @notice Gets the minter address, which controls Dopamine tab emissions.
    function minter() external view returns (address);

    /// @notice Gets the time needed to wait in seconds between drop creations.
    function dropDelay() external view returns (uint256);

    /// @notice Gets the last token id of the current drop (exclusive boundary).
    function dropEndIndex() external view returns (uint256);

    /// @notice Gets the time at which a new drop can start (if last completed).
    function dropEndTime() external view returns (uint256);

    /// @notice Retrieves the provenance hash for a drop with id `dropId`.
    /// @param dropId The id of the drop being queried.
    /// @return SHA-256 hash of all sequenced SHA-256 image hashes of the drop.
    function dropProvenanceHash(uint256 dropId) external view returns (bytes32);

    /// @notice Retrieves the metadata URI for a drop with id `dropId`.
    /// @param dropId The id of the drop being queried.
    /// @return URI of the drop's metadata as a string.
    function dropURI(uint256 dropId) external view returns (string memory);

    /// @notice Retrieves the allowlist for a drop with id `dropId`.
    /// @dev See `claim()` for details regarding allowlist generation.
    /// @param dropId The id of the drop being queried.
    /// @return The drop's allowlist, as a bytes32 merkle tree root.
    function dropAllowlist(uint256 dropId) external view returns (bytes32);

    /// @notice Retrieves the drop id of the tab with id `id`.
    /// @dev This function reverts for non-existent drops. For existing drops, 
    ///  the drop id will be returned even if a drop's tab has yet to mint.
    /// @param dropId The id of the drop being queried.
    /// @return The drop id of the queried tab.
    function dropId(uint256 dropId) external view returns (uint256);

    /// @notice Retrieves a URI describing the overall contract-level metadata.
    /// @return A string URI pointing to the tab contract metadata.
    function contractURI() external view returns (string memory);

    /// @notice Sets the minter address to `newMinter`.
    /// @param newMinter The address of the new minter.
    /// @dev This function is only callable by the admin address.
    function setMinter(address newMinter) external;

    /// @notice Sets the pending admin address to  `newPendingAdmin`.
    /// @param newPendingAdmin The address of the new pending admin.
    /// @dev This function is only callable by the admin address.
    function setPendingAdmin(address newPendingAdmin) external;

    /// @notice Assigns the `pendingAdmin` address to the `admin` address.
    /// @dev This function is only callable by the pending admin address.
    function acceptAdmin() external;

    /// @notice Sets the base URI to `newBaseURI`.
    /// @param newBaseURI The new base metadata URI to set for the collection.
    /// @dev This function is only callable by the admin address.
    function setBaseURI(string calldata newBaseURI) external;

    /// @notice Sets the final metadata URI for drop `dropId` to `dropURI`.
    /// @dev This function is only callable by the admin address, and reverts
    ///  if the specified drop `dropId` does not exist.
    /// @param dropId The id of the drop whose final metadata URI is being set.
    /// @param uri The finalized IPFS / Arweave metadata URI.
    function setDropURI(uint256 dropId, string calldata uri) external;

    /// @notice Sets the drop delay `dropDelay` to `newDropDelay`.
    /// @dev This function is only callable by the admin address, and reverts if
    ///  the drop delay is too small or too large.
    /// @param newDropDelay The new drop delay to set, in seconds.
    function setDropDelay(uint256 newDropDelay) external;

    /// @notice Updates the drop provenance hash and allowlist.
    /// @dev This function is only callable by the admin address, and will
    ///  revert when called after drop finalization (when drop URI is set).
    ///  Note: This function should NOT be called unless drop is misconfigured.
    /// @param dropId The id of the drop being queried.
    /// @param provenanceHash The drop's provenance hash (SHA-256 of images).
    /// @param allowlist Merkle root of drop's allowlisted address-NFT pairs.
    function updateDrop(
        uint256 dropId,
        bytes32 provenanceHash,
        bytes32 allowlist
    ) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// @title OpenSea Proxy Registry Interface
interface IOpenSeaProxyRegistry {

    /// @notice Returns the proxy account associated with an OS user address.
    function proxies(address) external view returns (address);

}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// Transfer & minting methods derive from ERC721.sol of Rari Capital's solmate.

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "../interfaces/Errors.sol";
import {IERC2981} from "../interfaces/IERC2981.sol";

/// @title Dopamine Minimal ERC-721 Contract
/// @notice This is a minimal ERC-721 implementation that supports the metadata
///  extension, tracks total supply, and includes a capped maximum supply.
/// @dev This ERC-721 implementation is optimized for mints and transfers of
///  individual tokens (as opposed to bulk). It also includes EIP-712 methods &
///  data structures to allow for signing processes to be built on top of it.
contract ERC721 is IERC721, IERC721Metadata, IERC2981 {

    /// @notice The maximum number of NFTs that can ever exist.
    /// @dev For tabs this is also capped by the emissions plan (e.g. 1 / day).
    uint256 public immutable maxSupply;

    /// @notice The name of the NFT collection.
    string public name;

    /// @notice The abbreviated name of the NFT collection.
    string public symbol;

    /// @notice The total number of NFTs in circulation.
    uint256 public totalSupply;

    /// @notice Gets the number of NFTs owned by an address.
    /// @dev This implementation does not throw for zero-address queries.
    mapping(address => uint256) public balanceOf;

    /// @notice Gets the assigned owner of an address.
    /// @dev This implementation does not throw for NFTs of the zero address.
    mapping(uint256 => address) public ownerOf;

    /// @notice Gets the approved address for an NFT.
    /// @dev This implementation does not throw for zero-address queries.
    mapping(uint256 => address) public getApproved;

    /// @notice Maps an address to a nonce for replay protection.
    /// @dev Nonces are used with EIP-712 signing built on top of this contract.
    mapping(address => uint256) public nonces;

    /// @dev Checks for an owner if an address is an authorized operator.
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    /// @dev EIP-2981 collection-wide royalties information.
    RoyaltiesInfo internal _royaltiesInfo;

    /// @dev EIP-712 immutables for signing messages.
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    /// @dev  EIP-165 identifiers for all supported interfaces.
    bytes4 private constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant _ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant _ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;
    bytes4 private constant _ERC2981_METADATA_INTERFACE_ID = 0x2a55205a;

    /// @notice Instantiates a new ERC-721 contract.
    /// @param name_ The name of the NFT collecton.
    /// @param symbol_ The abbreviated name of the NFT collection.
    /// @param maxSupply_ The maximum supply for the NFT collection.
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) {
        name = name_;
        symbol = symbol_;
        maxSupply = maxSupply_;

        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    /// @notice Sets approved address of NFT of id `id` to address `approved`.
    /// @param approved The new approved address for the NFT.
    /// @param id The id of the NFT to approve.
    function approve(address approved, uint256 id) external {
        address owner = ownerOf[id];

        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) {
            revert SenderUnauthorized();
        }

        getApproved[id] = approved;
        emit Approval(owner, approved, id);
    }

    /// @notice Checks if `operator` is an authorized operator for `owner`.
    /// @param owner The address of the owner.
    /// @param operator The address of the owner's operator.
    /// @return True if `operator` is approved operator of `owner`, else False.
    function isApprovedForAll(address owner, address operator)
        external
        view
        virtual returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    /// @notice Sets the operator for `msg.sender` to `operator`.
    /// @param operator The operator address that will manage the sender's NFTs.
    /// @param approved Whether operator is allowed to operate sender's NFTs.
    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Returns the metadata URI associated with the NFT of id `id`.
    /// @return A string URI pointing to metadata of the queried NFT.
    function tokenURI(uint256) external view virtual returns (string memory) {
        return "";
    }

    /// @notice Checks if interface of identifier `id` is supported.
    /// @param id The ERC-165 interface identifier.
    /// @return True if interface id `id` is supported, false otherwise.
    function supportsInterface(bytes4 id) external pure virtual returns (bool) {
        return
            id == _ERC165_INTERFACE_ID ||
            id == _ERC721_INTERFACE_ID ||
            id == _ERC721_METADATA_INTERFACE_ID ||
            id == _ERC2981_METADATA_INTERFACE_ID;
    }

    /// @inheritdoc IERC2981
    function royaltyInfo(
        uint256,
        uint256 salePrice
    ) external view returns (address, uint256) {
        RoyaltiesInfo memory royaltiesInfo = _royaltiesInfo;
        uint256 royalties = (salePrice * royaltiesInfo.royalties) / 10000;
        return (royaltiesInfo.receiver, royalties);
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  with safety checks ensuring `to` is capable of receiving the NFT.
    /// @dev Safety checks are only performed if `to` is a smart contract.
    /// @param from The existing owner address of the NFT to be transferred.
    /// @param to The new owner address of the NFT being transferred.
    /// @param id The id of the NFT being transferred.
    /// @param data Additional transfer data to pass to the receiving contract.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
                IERC721Receiver(to).onERC721Received(msg.sender, from, id, data)
                !=
                IERC721Receiver.onERC721Received.selector
        ) {
            revert SafeTransferUnsupported();
        }
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  with safety checks ensuring `to` is capable of receiving the NFT.
    /// @dev Safety checks are only performed if `to` is a smart contract.
    /// @param from The existing owner address of the NFT to be transferred.
    /// @param to The new owner address of the NFT being transferred.
    /// @param id The id of the NFT being transferred.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
                IERC721Receiver(to).onERC721Received(msg.sender, from, id, "")
                !=
                IERC721Receiver.onERC721Received.selector
        ) {
            revert SafeTransferUnsupported();
        }
    }

    /// @notice Transfers NFT of id `id` from address `from` to address `to`,
    ///  without performing any safety checks.
    /// @dev Existence of an NFT is inferred by having a non-zero owner address.
    ///  Transfers clear owner approvals, but `Approval` events are omitted.
    /// @param from The existing owner address of the NFT being transferred.
    /// @param to The new owner address of the NFT being transferred.
    /// @param id The id of the NFT being transferred.
    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public {
        if (from != ownerOf[id]) {
            revert OwnerInvalid();
        }

        if (
            msg.sender != from &&
            msg.sender != getApproved[id] &&
            !_operatorApprovals[from][msg.sender]
        ) {
            revert SenderUnauthorized();
        }

        if (to == address(0)) {
            revert ReceiverInvalid();
        }

        _beforeTokenTransfer(from, to, id);

        delete getApproved[id];

        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }

        ownerOf[id] = to;
        emit Transfer(from, to, id);
    }

    /// @dev Mints NFT of id `id` to address `to`. To save gas, it is assumed
    ///  that `maxSupply` < `type(uint256).max` (ex. for tabs, cap is very low).
    /// @param to Address receiving the minted NFT.
    /// @param id Identifier of the NFT being minted.
    /// @return The id of the minted NFT.
    function _mint(address to, uint256 id) internal returns (uint256) {
        if (to == address(0)) {
            revert ReceiverInvalid();
        }
        if (ownerOf[id] != address(0)) {
            revert TokenAlreadyMinted();
        }

        _beforeTokenTransfer(address(0), to, id);

        unchecked {
            totalSupply++;
            balanceOf[to]++;
        }

        if (totalSupply > maxSupply) {
            revert SupplyMaxCapacity();
        }

        ownerOf[id] = to;
        emit Transfer(address(0), to, id);
        return id;
    }

    /// @dev Burns NFT of id `id`, removing it from existence.
    /// @param id Identifier of the NFT being burned
    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];

        if (owner == address(0)) {
            revert TokenNonExistent();
        }

        _beforeTokenTransfer(owner, address(0), id);

        unchecked {
            totalSupply--;
            balanceOf[owner]--;
        }

        delete ownerOf[id];
        emit Transfer(owner, address(0), id);
    }

    /// @notice Pre-transfer hook for embedding additional transfer behavior.
    /// @param from The address of the existing owner of the NFT.
    /// @param to The address of the new owner of the NFT.
    /// @param id The id of the NFT being transferred.
    function _beforeTokenTransfer(address from, address to, uint256 id)
        internal
        virtual
        {}

    /// @dev Generates an EIP-712 domain separator for the NFT collection.
    /// @return A 256-bit domain separator (see EIP-712 for details).
    function _buildDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    /// @dev Returns an EIP-712 encoding of structured data `structHash`.
    /// @param structHash The structured data to be encoded and signed.
    /// @return A bytestring suitable for signing in accordance to EIP-712.
    function _hashTypedData(bytes32 structHash)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("\x19\x01", _domainSeparator(), structHash)
        );
    }

    /// @dev Returns the domain separator tied to the NFT contract.
    /// @return 256-bit domain separator tied to this contract.
    function _domainSeparator() internal view returns (bytes32) {
        if (block.chainid == _CHAIN_ID) {
            return _DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator();
        }
    }

    /// @dev Sets the royalty information for all NFTs in the collection.
    /// @param receiver Address which will receive token royalties.
    /// @param royalties Royalties amount, in bips.
    function _setRoyalties(address receiver, uint96 royalties) internal {
        if (royalties > 10000) {
            revert RoyaltiesTooHigh();
        }
        if (receiver == address(0)) {
            revert ReceiverInvalid();
        }
        _royaltiesInfo = RoyaltiesInfo(receiver, royalties);
    }

}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// ERC721Votable.sol is a modification of Nouns DAO's ERC721Checkpointable.sol.
///
/// Copyright licensing is under the BSD-3-Clause license, as the above contract
/// is itself a modification of Compound Lab's Comp.sol (3-Clause BSD Licensed).
///
/// The following major changes were made from the original Nouns DAO contract:
/// - Numerous safety checks were removed (assumption is max supply < 2^32 - 1)
/// - Voting units were changed: `uint96` -> `uint32` (due to above assumption)
/// - `Checkpoint` struct was modified to pack 4 checkpoints per storage slot
/// - Signing was modularized to abstract away EIP-712 details (see ERC721.sol)

import "../interfaces/Errors.sol";
import {IERC721Votable} from "../interfaces/IERC721Votable.sol";

import {ERC721} from "./ERC721.sol";

/// @title Dopamine ERC-721 Voting Contract
/// @notice This voting contract allows any ERC-721 with a maximum supply of
///  under `type(uint32).max` which inherits the contract to be integrated under
///  its Governor Bravo governance framework. This contract is to be inherited
///  by the Dopamine ERC-721 membership tab, allowing tabs to act as governance
///  tokens to be used for proposals, voting, and membership delegation.
contract ERC721Votable is ERC721, IERC721Votable {

    /// @notice Maps an address to a list of all of its created checkpoints.
    mapping(address => Checkpoint[]) public checkpoints;

    /// @dev Maps an address to its currently assigned voting delegate.
    mapping(address => address) internal _delegates;

    /// @notice Typehash used for EIP-712 vote delegation (see `delegateBySig`).
    bytes32 internal constant DELEGATION_TYPEHASH = keccak256('Delegate(address delegator,address delegatee,uint256 nonce,uint256 expiry)');

    /// @notice Instantiates a new ERC-721 voting contract.
    /// @param name_ The name of the ERC-721 NFT collection.
    /// @param symbol_ The abbreviated name of the ERC-721 NFT collection.
    /// @param maxSupply_ The maximum supply of the ERC-721 NFT collection.
    constructor(string memory name_, string memory symbol_, uint256 maxSupply_)
        ERC721(name_, symbol_, maxSupply_) {}

    /// @inheritdoc IERC721Votable
    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }

    /// @inheritdoc IERC721Votable
    function delegateBySig(
        address delegator,
        address delegatee,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > expiry) {
            revert SignatureExpired();
        }
        address signatory = ecrecover(
            _hashTypedData(keccak256(
                abi.encode(
                    DELEGATION_TYPEHASH,
                    delegator,
                    delegatee,
                    nonces[delegator]++,
                    expiry
                )
            )),
            v,
            r,
            s
        );
        if (signatory == address(0) || signatory != delegator) {
            revert SignatureInvalid();
        }
        _delegate(signatory, delegatee);
    }

    /// @inheritdoc IERC721Votable
    function totalCheckpoints(address voter) external view returns (uint256) {
        return checkpoints[voter].length;
    }

    /// @inheritdoc IERC721Votable
    function currentVotes(address voter) external view returns (uint32) {
        uint256 numCheckpoints = checkpoints[voter].length;
        return numCheckpoints == 0 ?
            0 : checkpoints[voter][numCheckpoints - 1].votes;
    }

    /// @inheritdoc IERC721Votable
    function priorVotes(address voter, uint256 blockNumber)
        external
        view
        returns (uint32)
    {
        if (blockNumber >= block.number) {
            revert BlockInvalid();
        }

        uint256 numCheckpoints = checkpoints[voter].length;
        if (numCheckpoints == 0) {
            return 0;
        }

        // Check common case of `blockNumber` being ahead of latest checkpoint.
        if (checkpoints[voter][numCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[voter][numCheckpoints - 1].votes;
        }

        // Check case of `blockNumber` being behind first checkpoint (0 votes).
        if (checkpoints[voter][0].fromBlock > blockNumber) {
            return 0;
        }

        // Run binary search to find 1st checkpoint at or before `blockNumber`.
        uint256 lower = 0;
        uint256 upper = numCheckpoints - 1;
        while (upper > lower) {
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = checkpoints[voter][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[voter][lower].votes;
    }

    /// @inheritdoc IERC721Votable
    function delegates(address delegator) public view returns (address) {
        address current = _delegates[delegator];
        return current == address(0) ? delegator : current;
    }

    /// @notice Delegate voting power of `delegator` to `delegatee`.
    /// @param delegator The address of the delegator.
    /// @param delegatee The address of the delegatee.
    function _delegate(address delegator, address delegatee) internal {
        if (delegatee == address(0)) {
            delegatee = delegator;
        }

        address currentDelegate = delegates(delegator);
        uint256 amount = balanceOf[delegator];

        _delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _transferDelegates(currentDelegate, delegatee, amount);
    }

    /// @notice Transfer `amount` voting power from `srcRep` to `dstRep`.
    /// @param srcRep The delegate whose votes are being transferred away from.
    /// @param dstRep The delegate who is being transferred new votes.
    /// @param amount The number of votes being transferred.
    function _transferDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal {
        if (srcRep == dstRep || amount == 0) {
            return;
        }

        if (srcRep != address(0)) {
            (uint256 oldVotes, uint256 newVotes) =
                _writeCheckpoint(
                    checkpoints[srcRep],
                    _sub,
                    amount
                );
            emit DelegateVotesChanged(srcRep, oldVotes, newVotes);
        }

        if (dstRep != address(0)) {
            (uint256 oldVotes, uint256 newVotes) =
                _writeCheckpoint(
                    checkpoints[dstRep],
                    _add,
                    amount
                );
            emit DelegateVotesChanged(dstRep, oldVotes, newVotes);
        }
    }

    /// @notice Override pre-transfer hook to account for voting power transfer.
    /// @dev By design, a governance NFT corresponds to a single voting unit.
    /// @param from The address from which the gov NFT is being transferred.
    /// @param to The receiving address of the gov NFT.
    /// @param id The identifier of the gov NFT being transferred.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 id
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, id);
        _transferDelegates(delegates(from), delegates(to), 1);
    }

    /// @notice Adds a new checkpoint to `ckpts` by performing `op` of amount
    ///  `delta` on the last known checkpoint of `ckpts` (if it exists).
    /// @param ckpts Storage pointer to the Checkpoint array being modified
    /// @param op Binary operator, either add or subtract.
    /// @param delta Amount in voting units to be added to or subtracted from.
    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldVotes, uint256 newVotes) {
        uint256 numCheckpoints = ckpts.length;
        oldVotes = numCheckpoints == 0 ? 0 : ckpts[numCheckpoints - 1].votes;
        newVotes = op(oldVotes, delta);

        if ( // If latest checkpoint belonged to current block, just reassign.
             numCheckpoints > 0 &&
            ckpts[numCheckpoints - 1].fromBlock == block.number
        ) {
            ckpts[numCheckpoints - 1].votes = _safe32(newVotes);
        } else { // Otherwise, a new Checkpoint must be created.
            ckpts.push(Checkpoint({
                fromBlock: _safe32(block.number),
                votes: _safe32(newVotes)
            }));
        }
    }

    /// @notice Safely downcasts a uint256 `n` into a uint32.
    function _safe32(uint256 n) private  pure returns (uint32) {
        if (n > type(uint32).max) {
            revert Uint32ConversionInvalid();
        }
        return uint32(n);
    }

    /// @notice Binary operator for adding operand `a` to operand `b`.
    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    /// @notice Binary operator for subtracting operand `b` from operand `a`.
    function _sub(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// @title Dopamine Membership Tab Events Interface
interface IDopamineTabEvents {

    /// @notice Emits when the Dopamine tab base URI is set to `baseUri`.
    /// @param baseUri The base URI of the Dopamine tab contract, as a string.
    event BaseURISet(string baseUri);

    /// @notice Emits when a new drop is created by the Dopamine tab admin.
    /// @param dropId The id of the newly created drop.
    /// @param startIndex The id of the first tabincluded in the drop.
    /// @param dropSize The number of tabs to distribute in the drop.
    /// @param allowlistSize The number of allowlisted tabs in the drop.
    /// @param allowlist A merkle root of the included address-tab pairs.
    /// @param provenanceHash SHA-256 hash of combined image hashes in the drop.
    event DropCreated(
        uint256 indexed dropId,
        uint256 startIndex,
        uint256 dropSize,
        uint256 allowlistSize,
        bytes32 allowlist,
        bytes32 provenanceHash
    );

    /// @notice Emits when a new drop delay `dropDelay` is set.
    /// @param dropDelay The new drop delay to set, in seconds.
    event DropDelaySet(uint256 dropDelay);

    /// @notice Emits when a new drop size `dropSize` is set.
    /// @param dropId The id of the queried drop.
    /// @param provenanceHash The drop collection provenance hash.
    /// @param allowlist Merkle root of drop's allowlisted address-tab pairs.
    event DropUpdated(uint256 indexed dropId, bytes32 provenanceHash, bytes32 allowlist);

    /// @notice Emits when the drop of id `id` has its URI set to `dropUr1`.
    /// @param id  The id of the drop whose URI was set.
    /// @param dropUri The metadata URI of the drop, as a string.
    event DropURISet(uint256 indexed id, string dropUri);

    /// @notice Emits when a new pending admin `pendingAdmin` is set.
    /// @param pendingAdmin The new address of the pending admin that was set.
    event PendingAdminSet(address pendingAdmin);

    /// @notice Emits when minter is changed from `oldMinter` to `newMinter`.
    /// @param oldMinter The address of the previous minter.
    /// @param newMinter The address of the new minter.
    event MinterChanged(address indexed oldMinter, address indexed newMinter);

    /// @notice Emits when admin is changed from `oldAdmin` to `newAdmin`.
    /// @param oldAdmin The address of the previous admin.
    /// @param newAdmin The address of the new admin.
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// @title Interface for the ERC-2981 royalties standard.
interface IERC2981 {

/// @notice RoyaltiesInfo stores token royalties information.
struct RoyaltiesInfo {

    /// @notice The address to which royalties will be directed.
    address receiver;

    /// @notice The royalties amount, in bips.
    uint96 royalties;

}

    /// @notice Returns the address to which royalties are received along with
    ///  the royalties amount to be paid to them for a given sale price.
    /// @param id The id of the NFT being queried for royalties information.
    /// @param salePrice The sale price of the NFT, in some unit of exchange.
    /// @return receiver The address of the royalties receiver.
    /// @return royaltyAmount The royalty payment to be made given `salePrice`.
    function royaltyInfo(
        uint256 id,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);

}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

import "./IERC721VotableEvents.sol";

/// @title Dopamine ERC-721 Voting Contract Interface
interface IERC721Votable is IERC721VotableEvents {

    /// @notice Checkpoints hold the vote balance of addresses at given blocks.
    struct Checkpoint {

        /// @notice The block number that the checkpoint was created.
        uint32 fromBlock;

        /// @notice The assigned voting balance.
        uint32 votes;

    }

    /// @notice Delegate assigned votes to `msg.sender` to `delegatee`.
    /// @param delegatee Address of the delegatee being delegated to.
    function delegate(address delegatee) external;

    /// @notice Delegate to `delegatee` on behalf of `delegator` via signature.
    /// @dev Refer to EIP-712 on signature and hashing details. This function
    ///  will revert if the provided signature is invalid or has expired.
    /// @param delegator The address to perform delegation on behalf of.
    /// @param delegatee The address being delegated to.
    /// @param expiry The timestamp at which this signature is set to expire.
    /// @param v Transaction signature recovery identifier.
    /// @param r Transaction signature output component #1.
    /// @param s Transaction signature output component #2.
    function delegateBySig(
        address delegator,
        address delegatee,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Get the total number of checkpoints created for address `voter`.
    /// @param voter Address of the voter being queried.
    /// @return The number of checkpoints tied to `voter`.
    function totalCheckpoints(address voter) external view returns (uint256);

    /// @notice Retrieves the voting weight `votes` and block `fromBlock`
    ///  corresponding to the checkpoint at index `index` of address `voter`.
    /// @param voter The address whose checkpoint we want to query.
    /// @param index The index to query among the voter's list of checkpoints.
    /// @return fromBlock The block number that the checkpoint was created.
    /// @return votes The voting balance assigned to the queried checkpoint.
    function checkpoints(address voter, uint256 index)
        external returns (uint32 fromBlock, uint32 votes);

    /// @notice Get the current number of votes allocated for address `voter`.
    /// @param voter The address of the voter being queried.
    /// @return The number of votes currently tied to address `voter`.
    function currentVotes(address voter) external view returns (uint32);

    /// @notice Get number of votes for `voter` at block number `blockNumber`.
    /// @param voter Address of the voter being queried.
    /// @param blockNumber Block number to tally votes from.
    /// @dev This function reverts if the current or future block is specified.
    /// @return The total tallied votes of `voter` at `blockNumber`.
    function priorVotes(address voter, uint256 blockNumber)
        external view returns (uint32);

    /// @notice Retrieves the currently assigned delegate of `delegator`.
    /// @dev Having no delegate assigned indicates self-delegation.
    /// @param delegator The address of the delegator.
    /// @return Assigned delegate address if it exists, `delegator` otherwise.
    function delegates(address delegator) external view returns (address);

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.13;

////////////////////////////////////////////////////////////////////////////////
///              ░▒█▀▀▄░█▀▀█░▒█▀▀█░█▀▀▄░▒█▀▄▀█░▄█░░▒█▄░▒█░▒█▀▀▀              ///
///              ░▒█░▒█░█▄▀█░▒█▄▄█▒█▄▄█░▒█▒█▒█░░█▒░▒█▒█▒█░▒█▀▀▀              ///
///              ░▒█▄▄█░█▄▄█░▒█░░░▒█░▒█░▒█░░▒█░▄█▄░▒█░░▀█░▒█▄▄▄              ///
////////////////////////////////////////////////////////////////////////////////

/// @title Dopamine ERC-721 Voting Contract Events Interface
interface IERC721VotableEvents {

    /// @notice Emits when address `delegator` has its delegate address changed
    ///  from `fromDelegate` to `toDelegate` (even if they're the same address).
    /// @param delegator Address whose delegate has changed.
    /// @param fromDelegate The original delegate of the delegator.
    /// @param toDelegate The new delegate of the delegator.
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice Emits when `delegate` votes moves from `oldVotes` to `newVotes`.
    /// @param delegate Address of the delegate whose voting weight changed.
    /// @param oldVotes The old voting weight assigned to the delegator.
    /// @param newVotes The new voting weight assigned to the delegator.
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 oldVotes,
        uint256 newVotes
    );

}