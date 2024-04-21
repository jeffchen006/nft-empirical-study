// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../extensions/Burnable.sol";
import "../extensions/WithOperatorRegistry.sol";
import "../extensions/AirDropable.sol";
import "./IERC721LA.sol";
import "../extensions/Pausable.sol";
import "../extensions/Whitelistable.sol";
// import "../extensions/PermissionedTransfers.sol";
import "../extensions/LAInitializable.sol";
import "../libraries/LANFTUtils.sol";
import "../libraries/BPS.sol";
import "../libraries/CustomErrors.sol";
import "../platform/royalties/RoyaltiesState.sol";
import "./ERC721State.sol";
import "./ERC721LACore.sol";
import "../libraries/CustomErrors.sol";

/**
 * @notice LiveArt ERC721 implementation contract
 * Supports multiple edtioned NFTs and gas optimized batch minting
 */
contract ERC721LA is
    ERC721LACore,
    AirDropable,
    Burnable,
    Whitelistable
{
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                            Royalties
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function setRoyaltyRegistryAddress(
        address _royaltyRegistry
    ) public onlyAdmin {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        state._royaltyRegistry = IRoyaltiesRegistry(_royaltyRegistry);
    }

    function royaltyRegistryAddress() public view returns (IRoyaltiesRegistry) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        return state._royaltyRegistry;
    }

    /// @dev see: EIP-2981
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _value
    ) external view returns (address _receiver, uint256 _royaltyAmount) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();

        return
            state._royaltyRegistry.royaltyInfo(address(this), _tokenId, _value);
    }

    function registerCollectionRoyaltyReceivers(
        RoyaltiesState.RoyaltyReceiver[] memory royaltyReceivers
    ) public onlyAdmin {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();

        IRoyaltiesRegistry(state._royaltyRegistry)
            .registerCollectionRoyaltyReceivers(
                address(this),
                msg.sender,
                royaltyReceivers
            );
    }

    function registerEditionRoyaltyReceivers(
        uint256 editionId,
        RoyaltiesState.RoyaltyReceiver[] memory royaltyReceivers
    ) public {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();

        IRoyaltiesRegistry(state._royaltyRegistry)
            .registerEditionRoyaltyReceivers(
                address(this),
                msg.sender,
                editionId,
                royaltyReceivers
            );
    }

    function primaryRoyaltyInfo(
        uint256 tokenId
    ) public view returns (address payable[] memory, uint256[] memory) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();

        return
            IRoyaltiesRegistry(state._royaltyRegistry).primaryRoyaltyInfo(
                address(this),
                tokenId
            );
    }


}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "../libraries/CustomErrors.sol";
import "../libraries/BPS.sol";
import "../tokens/ERC721LACore.sol";
import "../libraries/LANFTUtils.sol";
import "../tokens/ERC721State.sol";

abstract contract Burnable is ERC721LACore {

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               BURNABLE
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function burn(uint256 tokenId) public {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        
        address owner = ownerOf(tokenId);

        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert CustomErrors.TransferError();
        }
        _transferCore(owner, ERC721LACore.burnAddress, tokenId);

        // Looksrare and other marketplace require the owner to be null address
        emit Transfer(owner, address(0), tokenId);
        (uint256 editionId, ) = parseEditionFromTokenId(tokenId);

        // Update the number of tokens burned for this edition
        state._editions[editionId].burnedSupply += 1;
    }


    function burnRedeemEditionTokens(
        uint256 _editionId,
        uint24 _quantity,
        uint256[] calldata tokenIdsToBurn
    ) public whenPublicMintOpened(_editionId) whenNotPaused {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();

        ERC721State.Edition memory edition = getEdition(_editionId);

        if (edition.burnableEditionId == 0 || tokenIdsToBurn.length == 0) {
            revert CustomErrors.BurnRedeemNotAvailable();
        }

        uint256 mintableAmount = tokenIdsToBurn.length / edition.amountToBurn; 

        if (mintableAmount < _quantity) {
            revert CustomErrors.BurnRedeemNotAvailable();
        } 

        // Check max mint per wallet restrictions (if maxMintPerWallet is 0, no restriction apply)
        uint256 mintedCountKey = uint256(
            keccak256(abi.encodePacked(_editionId, msg.sender))
        );

        if (edition.maxMintPerWallet != 0 ) {
            if (
                state._mintedPerWallet[mintedCountKey] + _quantity >
                edition.maxMintPerWallet
            ) {
                revert CustomErrors.MaximumMintAmountReached();
            }
        }
        state._mintedPerWallet[mintedCountKey] += _quantity;


        // We iterate and burn only the required amount of tokens (preventing burning more than necessary)
        // burn will revert if the sender is not the owner of a given token
        for(uint256 i; i<edition.amountToBurn * _quantity;i++) {
            burn(tokenIdsToBurn[i]);
        }

        _safeMint(_editionId, _quantity, msg.sender);
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "../libraries/CustomErrors.sol";
import "./WithOperatorRegistryState.sol";
import "../libraries/LANFTUtils.sol";
import "../extensions/AccessControl.sol";
import "operator-filter-registry/src/IOperatorFilterRegistry.sol";
import {CANONICAL_CORI_SUBSCRIPTION} from "operator-filter-registry/src/lib/Constants.sol";

 contract WithOperatorRegistry is AccessControl  {
    address constant DEFAULT_OPERATOR_REGISTRY_ADDRESS =
        0x000000000000AAeB6D7670E522A718067333cd4E;

    /// @dev The upgradeable initialize function that should be called when the contract is being upgraded.
    function _initOperatorRegsitry(
    ) internal {
        WithOperatorRegistryState.OperatorRegistryState
            storage registryState = WithOperatorRegistryState
                ._getOperatorRegistryState();
        IOperatorFilterRegistry registry = IOperatorFilterRegistry(
            DEFAULT_OPERATOR_REGISTRY_ADDRESS
        );

        registryState.operatorFilterRegistry = registry;

        if (address(registry).code.length > 0) {
                registry.registerAndSubscribe(
                    address(this),
                    CANONICAL_CORI_SUBSCRIPTION
                );
        }
    }


    function initOperatorRegsitry(
    ) public onlyAdmin {
        _initOperatorRegsitry();
    }

    /**
     * @dev A helper modifier to check if the operator is allowed.
     */
    modifier onlyAllowedOperator(address from) virtual {
        // Allow spending tokens from addresses with balance
        // Note that this still allows listings and marketplaces with escrow to transfer tokens if transferred
        // from an EOA.
        if (from != msg.sender) {
            _checkFilterOperator(msg.sender);
        }
        _;
    }

    /**
     * @dev A helper modifier to check if the operator approval is allowed.
     */
    modifier onlyAllowedOperatorApproval(address operator) virtual {
        _checkFilterOperator(operator);
        _;
    }

    /**
     * @dev A helper function to check if the operator is allowed.
     */
    function _checkFilterOperator(address operator) internal view virtual {
        WithOperatorRegistryState.OperatorRegistryState
            storage registryState = WithOperatorRegistryState
                ._getOperatorRegistryState();
        // Check registry code length to facilitate testing in environments without a deployed registry.
        if (address(registryState.operatorFilterRegistry).code.length > 0) {
            // under normal circumstances, this function will revert rather than return false, but inheriting or
            // upgraded contracts may specify their own OperatorFilterRegistry implementations, which may behave
            // differently
            if (
                !registryState.operatorFilterRegistry.isOperatorAllowed(
                    address(this),
                    operator
                )
            ) {
                revert CustomErrors.NotAllowed();
            }
        }
    }


    /**
     * @notice Update the address that the contract will make OperatorFilter checks against. When set to the zero
     *         address, checks will be bypassed. OnlyOwner.
     */
    function updateOperatorFilterRegistryAddress(address newRegistry) public onlyAdmin {
        WithOperatorRegistryState.OperatorRegistryState
            storage registryState = WithOperatorRegistryState
                ._getOperatorRegistryState();
        IOperatorFilterRegistry registry = IOperatorFilterRegistry(
            newRegistry
        );
        registryState.operatorFilterRegistry = registry;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "../libraries/CustomErrors.sol";
import "../libraries/BPS.sol";
import "../libraries/CustomErrors.sol";
import "../libraries/LANFTUtils.sol";
import "../tokens/ERC721State.sol";
import "../tokens/ERC721LACore.sol";
import "./IAirDropable.sol";
import "../platform/royalties/RoyaltiesState.sol";

abstract contract AirDropable is IAirDropable, ERC721LACore {
    uint256 public constant AIRDROP_MAX_BATCH_SIZE = 100;

    function airdrop(
        uint256 editionId,
        address[] calldata recipients,
        uint24 quantityPerAddress
    ) external onlyAdmin {
        if (recipients.length > AIRDROP_MAX_BATCH_SIZE) {
            revert TooManyAddresses();
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            _safeMint(editionId, quantityPerAddress, recipients[i]);
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
import "../libraries/BitMaps/BitMaps.sol";
import "../platform/royalties/IRoyaltiesRegistry.sol";
import "./IERC721Events.sol";
import "./ERC721State.sol";
pragma solidity ^0.8.4;

/**
 * @dev Interface of an ERC721LA compliant contract.
 */
abstract contract IERC721LA is IERC721Events {
    using BitMaps for BitMaps.BitMap;

    // ==============================
    //            IERC165
    // ==============================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId)
        external
        view
        virtual
        returns (bool);

    // ==============================
    //            IERC721
    // ==============================

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     *
     * Burned tokens are calculated here, use `_totalMinted()` if you want to count just minted tokens.
     */
    function totalSupply() external view virtual returns (uint256);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    // function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId)
        external
        view
        virtual
        returns (address owner);

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
    ) external virtual;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual;

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
    ) external virtual;

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
    function approve(address to, uint256 tokenId) external virtual;

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
    function setApprovalForAll(address operator, bool _approved)
        external
        virtual;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId)
        external
        view
        virtual
        returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator)
        external
        view
        virtual
        returns (bool);



    // ==============================
    //        IERC721Metadata
    // ==============================

    /**
     * @dev Returns the token collection name.
     */
    function name() external view virtual returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view virtual returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId)
        external
        view
        virtual
        returns (string memory);

    // ==============================
    //        Editions
    // ==============================

    /**
     * @dev fetch edition struct data by editionId
     */
    function getEdition(uint256 _editionId)
        external
        view
        virtual
        returns (ERC721State.Edition memory);

    /**
     * @dev fetch edition struct data by editionId
     */
    function getEditionWithURI(uint256 _editionId)
        external
        view
        virtual
        returns (ERC721State.EditionWithURI memory);
    // ==============================
    //        Helpers
    // ==============================

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
contract Pausable {
    event Paused(address account);
    event Unpaused(address account);

    struct PausableState {
        bool _paused;
    }

    function _getPausableState()
        internal
        pure
        returns (PausableState storage state)
    {
        bytes32 position = keccak256("liveart.Pausable");
        assembly {
            state.slot := position
        }
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               MODIFIERS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        PausableState storage state = _getPausableState();
        return state._paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal whenNotPaused {
        PausableState storage state = _getPausableState();
        state._paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal whenPaused {
        PausableState storage state = _getPausableState();
        state._paused = false;
        emit Unpaused(msg.sender);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "../libraries/BPS.sol";
import "../libraries/CustomErrors.sol";
import "../libraries/LANFTUtils.sol";
import "../tokens/ERC721State.sol";
import "../tokens/ERC721LACore.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./IWhitelistable.sol";
import "./WhitelistableState.sol";

abstract contract Whitelistable is IWhitelistable, ERC721LACore {
    /**
     * Create a Whitelist configuration
     * @param _editionId the edition ID
     * @param amount How many mint allowed per Whitelist spot
     * @param mintPriceInFinney Price of the whitelist mint in Finney
     * @param mintStartTS Starting time of the Whitelist mint
     * @param mintEndTS Starting time of the Whitelist mint
     * @param merkleRoot The whitelist merkle root
     *
     */
    function setWLConfig(
        uint256 _editionId,
        uint8 amount,
        uint24 mintPriceInFinney,
        uint32 mintStartTS,
        uint32 mintEndTS,
        bytes32 merkleRoot
    ) public onlyAdmin {

        WhitelistableState.WLState storage state = WhitelistableState
            ._getWhitelistableState();

        // This reverts if edition does not exist
        getEdition(_editionId);

        uint256 wlId = uint256(
            keccak256(abi.encodePacked(_editionId, amount, mintPriceInFinney))
        );

        if (state._whitelistConfig[wlId].amount != 0) {
            revert WhiteListAlreadyExists();
        }

        if (mintEndTS != 0 && mintEndTS < mintStartTS) {
            revert InvalidMintDuration();
        }

        WhitelistableState.WhitelistConfig
            memory whitelistConfig = WhitelistableState.WhitelistConfig({
                merkleRoot: merkleRoot,
                amount: amount,
                mintPriceInFinney: mintPriceInFinney,
                mintStartTS: mintStartTS,
                mintEndTS: mintEndTS
            });

        state._whitelistConfig[wlId] = whitelistConfig;
    }

    /**
     * Update a Whitelist configuration
     * @param _editionId Edition ID of the WL to be updated
     * @param _amount Amount of the WL to be updated
     * @param mintPriceInFinney Price of the WL to be updated
     * @param newAmount New Amount
     * @param newMintPriceInFinney New mint price in Finney
     * @param newMintStartTS New Mint time
     * @param newMerkleRoot New Merkle root
     * 
     * Note: When changing a single property of the WL config, 
     * make sure to also pass the value of the property that did not change.
     *
     */
    function updateWLConfig(
        uint256 _editionId,
        uint8 _amount,
        uint24 mintPriceInFinney,
        uint8 newAmount,
        uint24 newMintPriceInFinney,
        uint32 newMintStartTS,
        uint32 newMintEndTS,
        bytes32 newMerkleRoot
    ) public onlyAdmin {

        WhitelistableState.WLState storage state = WhitelistableState
            ._getWhitelistableState();

        // This reverts if edition does not exist
        getEdition(_editionId);

        uint256 wlId = uint256(
            keccak256(abi.encodePacked(_editionId, _amount, mintPriceInFinney))
        );
        WhitelistableState.WhitelistConfig memory whitelistConfig;

        // If amount or price differ, then set previous WL config key to amount 0, which effectively disable the WL
        if (_amount != newAmount || mintPriceInFinney != newMintPriceInFinney) {
            state._whitelistConfig[wlId] = WhitelistableState.WhitelistConfig({
                merkleRoot: newMerkleRoot,
                amount: 0,
                mintPriceInFinney: newMintPriceInFinney,
                mintStartTS: newMintStartTS,
                mintEndTS: newMintEndTS
            });
            wlId = uint256(
                keccak256(
                    abi.encodePacked(_editionId, newAmount, newMintPriceInFinney)
                )
            );
            state._whitelistConfig[wlId] = whitelistConfig;
        }

        if (newMintEndTS != 0 && newMintEndTS < newMintStartTS) {
            revert InvalidMintDuration();
        }
    
        whitelistConfig = WhitelistableState.WhitelistConfig({
            merkleRoot: newMerkleRoot,
            amount: newAmount,
            mintPriceInFinney: newMintPriceInFinney,
            mintStartTS: newMintStartTS,
            mintEndTS: newMintEndTS
        });

        state._whitelistConfig[wlId] = whitelistConfig;
    }

    /**
     * Whitelist mint function
     * @param _editionId the edition ID
     * @param maxAmount How many mint allowed per Whitelist spot
     * @param merkleProof the merkle proof of the minter
     * @param _quantity How many NFTs to mint
     */
    function whitelistMint(
        uint256 _editionId,
        uint8 maxAmount,
        uint24 mintPriceInFinney,
        bytes32[] calldata merkleProof,
        uint24 _quantity,
        address _recipient
    ) public payable  {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        ERC721State.Edition memory edition = getEdition(_editionId);

        // This reverts if WL does not exist (or is disabled)
        WhitelistableState.WhitelistConfig memory whitelistConfig = getWLConfig(
            _editionId,
            maxAmount,
            mintPriceInFinney
        );

        // Check for allowed mint count
        uint256 mintCountKey = uint256(
            keccak256(abi.encodePacked(_editionId, msg.sender))
        );

        if (
            state._mintedPerWallet[mintCountKey] + _quantity >
            whitelistConfig.amount
        ) {
            revert CustomErrors.MaximumMintAmountReached();
        }

        if (whitelistConfig.mintStartTS == 0 || block.timestamp < whitelistConfig.mintStartTS) {
            revert CustomErrors.MintClosed();
        }

        if (whitelistConfig.mintEndTS != 0 && block.timestamp > whitelistConfig.mintEndTS) {
            revert CustomErrors.MintClosed();
        }

        // We use msg.sender for the WL merkle root
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        if (
            !MerkleProof.verify(merkleProof, whitelistConfig.merkleRoot, leaf)
        ) {
            revert NotWhitelisted();
        }

        // Finney to Wei
        uint256 mintPriceInWei = uint256(whitelistConfig.mintPriceInFinney) *
            10e14;
        if (mintPriceInWei * _quantity > msg.value ) {
            revert CustomErrors.InsufficientFunds();
        } 

        state._mintedPerWallet[mintCountKey] += _quantity;
        uint256 firstTokenId  = _safeMint(_editionId, _quantity, _recipient);

        // Send primary royalties
        (
            address payable[] memory wallets,
            uint256[] memory primarySalePercentages
        ) = state._royaltyRegistry.primaryRoyaltyInfo(
                address(this),
                firstTokenId
            );

        uint256 nReceivers = wallets.length;

        for (uint256 i = 0; i < nReceivers; i++) {
            uint256 royalties = BPS._calculatePercentage(
                msg.value,
                primarySalePercentages[i]
            );
            (bool sent, ) = wallets[i].call{value: royalties}("");

            if (!sent) {
                revert CustomErrors.FundTransferError();
            }
        }
    }

    /**
     * Get WL config for given editionId, amout, and mintPrice.
     * Should not be used internally when trying to modify the state as it returns a memory copy of the structs
     */
    function getWLConfig(
        uint256 editionId,
        uint8 amount,
        uint24 mintPriceInFinney
    ) public view returns (WhitelistableState.WhitelistConfig memory) {
        WhitelistableState.WLState storage state = WhitelistableState
            ._getWhitelistableState();

        // This reverts if edition does not exist
        getEdition(editionId);

        uint256 wlId = uint256(
            keccak256(abi.encodePacked(editionId, amount, mintPriceInFinney))
        );
        WhitelistableState.WhitelistConfig storage whitelistConfig = state
            ._whitelistConfig[wlId];

        if (whitelistConfig.amount == 0) {
            revert CustomErrors.NotFound();
        }

        return whitelistConfig;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

abstract contract LAInitializable {
    error AlreadyInitialized();

    struct InitializableState {
        bool _initialized;
    }

    function _getInitializableState() internal pure returns (InitializableState storage state) {
        bytes32 position = keccak256("liveart.Initializable");
        assembly {
            state.slot := position
        }
    }

    modifier notInitialized() {
        InitializableState storage state = _getInitializableState();
        if (state._initialized) {
            revert AlreadyInitialized();
        }
        _;
        state._initialized = true;
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "./CustomErrors.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

library LANFTUtils {
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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

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
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is an EOA
     *
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal returns (bool) {
        if (LANFTUtils.isContract(to)) {
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert CustomErrors.NotERC721Receiver();
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library BPS {
    function _calculatePercentage(uint256 number, uint256 percentage)
        internal
        pure
        returns (uint256)
    {
        // https://ethereum.stackexchange.com/a/55702
        // https://www.investopedia.com/terms/b/basispoint.asp
        return (number * percentage) / 10000;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library CustomErrors {
    /**
     * Raised when trying to manipulate editions (CRUD) with invalid data
     */
    error InvalidEditionData();

    error MaxSupplyError();

    error InvalidEditionId();
    /**
     * Raised when trying to mint with invalid data
     */
    error InvalidMintData();

    /**
     * Raised when trying to transfer an NFT to a non ERC721Receiver
     */
    error NotERC721Receiver();

    /**
     * Raised when trying to query a non minted token
     */
    error TokenNotFound();

    /**
     * Raised when transfer fail
     */
    error TransferError();

    /**
     * Generic Not Allowed action
     */
    error NotAllowed();

    /**
     * Generic Not Found error 
     */
    error NotFound();

    /**
     * Raised when direct minting with insufficient funds
     */
    error InsufficientFunds();

    /**
     * Raised when fund transfer fails
     */
    error FundTransferError();

    error MintClosed();
    error MaximumMintAmountReached();
    error BurnRedeemNotAvailable();

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library RoyaltiesState {
    struct RoyaltyReceiver {
        address payable wallet;
        uint48 primarySalePercentage;
        uint48 secondarySalePercentage;
    }

    /**
     * @dev Storage layout
     * This pattern allow us to extend current contract using DELETGATE_CALL
     * without worrying about storage slot conflicts
     */
    struct RoyaltiesRegistryState {
        // contractAddress => RoyaltyReceiver
        mapping(address => RoyaltyReceiver[]) _collectionRoyaltyReceivers;
        // contractAddress => editionId => RoyaltyReceiver
        mapping(address => mapping(uint256 => RoyaltyReceiver[])) _editionRoyaltyReceivers;
        // contractAddress => editionId => tokenNumber => RoyaltyReceiver
        mapping(address => mapping(uint256 => mapping(uint256 => RoyaltyReceiver[]))) _tokenRoyaltyReceivers;
    }

    /**
     * @dev Get storage data from dedicated slot.
     * This pattern avoids storage conflict during proxy upgrades
     * and give more flexibility when creating extensions
     */
    function _getRoyaltiesState()
        internal
        pure
        returns (RoyaltiesRegistryState storage state)
    {
        bytes32 storageSlot = keccak256("liveart.RoyalitiesState");
        assembly {
            state.slot := storageSlot
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "../libraries/BitMaps/BitMaps.sol";
import "../platform/royalties/IRoyaltiesRegistry.sol";

library ERC721State {
    using BitMaps for BitMaps.BitMap;

    struct Edition {
        // Max. number of token mintable per edition
        uint24 maxSupply;

        // Currently minted token coutner
        uint24 currentSupply;

        // Burned token counter
        uint24 burnedSupply;

        // Public mint price
        uint24 publicMintPriceInFinney;

        // Public mint start time in seconds
        uint32 publicMintStartTS;

        // Public mint ending time in seconds
        uint32 publicMintEndTS;

        // Max mint per wallet. If 0, no limit
        uint8 maxMintPerWallet;

        // If perTokenMetadata == false, all tokens in this edition will have the same metadata
        bool perTokenMetadata;

        // An edition Id associated with this collection that is approved to be burned in order to mint on the current edition.
        uint24 burnableEditionId;
        
        // Amount to burn
        uint24 amountToBurn;
    }


    struct EditionWithURI {
        Edition data;
        string baseURI;
    }

    /**
     * @dev Storage layout
     * This pattern allow us to extend current contract using DELETGATE_CALL
     * without worrying about storage slot conflicts
     */
    struct ERC721LAState {
        // The number of edition created, indexed from 1
        uint64 _editionCounter;

        // Max token by edition. Defines the number of 0 in token Id (see editions)
        uint24 _edition_max_tokens;

        // Contract Name
        string _name;

        // Ticker
        string _symbol;

        // Edtion by editionId
        mapping(uint256 => Edition) _editions;

        // Owner by tokenId
        mapping(uint256 => address) _owners;

        // Token Id to operator address
        mapping(uint256 => address) _tokenApprovals;

        // Owned token count by address
        mapping(address => uint256) _balances;

        // Allower to allowee
        mapping(address => mapping(address => bool)) _operatorApprovals;

        // Tracking of batch heads
        BitMaps.BitMap _batchHead;

        // LiveArt global royalty registry address
        IRoyaltiesRegistry _royaltyRegistry;

        // Amount of ETH withdrawn by edition
        mapping(uint256 => uint256) _withdrawnBalancesByEdition;

        // EditionID => Base URI
        mapping(uint256 => string) _baseURIByEdition;

        // Minted counter per wallet/edition. hash(address, editionId) => counter
        mapping(uint256 => uint256) _mintedPerWallet;
    }

    /**
     * @dev Get storage data from dedicated slot.
     * This pattern avoids storage conflict during proxy upgrades
     * and give more flexibility when creating extensions
     */
    function _getERC721LAState()
        internal
        pure
        returns (ERC721LAState storage state)
    {
        bytes32 storageSlot = keccak256("liveart.ERC721LA");
        assembly {
            state.slot := storageSlot
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../extensions/AccessControl.sol";
import "../extensions/Winter.sol";
import "./IERC721LA.sol";
import "../extensions/Pausable.sol";
import "../extensions/IERC4906.sol";
import "../extensions/Ownable.sol";
import "../extensions/LAInitializable.sol";
import "../libraries/LANFTUtils.sol";
import "../libraries/BPS.sol";
import "../libraries/CustomErrors.sol";
import "./IERC721Events.sol";
import "./ERC721State.sol";
import "../extensions/WithOperatorRegistry.sol";

/**
 * @notice LiveArt ERC721 implementation contract
 * Supports multiple edtioned NFTs and gas optimized batch minting
 */
abstract contract ERC721LACore is
    LAInitializable,
    AccessControl,
    WithOperatorRegistry,
    Winter,
    Pausable,
    Ownable,
    IERC721LA,
    IERC4906
{
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               LIBRARIES
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    using BitMaps for BitMaps.BitMap;
    using ERC721State for ERC721State.ERC721LAState;

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               CONSTANTS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    bytes32 public constant IERC721METADATA_INTERFACE = hex"5b5e139f";
    bytes32 public constant IERC721_INTERFACE = hex"80ac58cd";
    bytes32 public constant IERC2981_INTERFACE = hex"2a55205a";
    bytes32 public constant IERC165_INTERFACE = hex"01ffc9a7";
    bytes32 public constant IERC4906_INTERFACE = hex"49064906";

    // Used for separating editionId and tokenNumber from the tokenId (cf. createEdition)
    uint24 public constant DEFAULT_EDITION_TOKEN_MULTIPLIER = 10e5;

    // Used to differenciate burnt tokens in the bitmap logic (Null address being used for unminted tokens)
    address public constant burnAddress = address(0xDEAD);

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               INITIALIZERS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /**
     * @dev Initialize function. Should be called by the factory when deploying new instances.
     * @param _collectionAdmin is the address of the default admin for this contract
     */
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _collectionAdmin,
        address _royaltyRegistry
    ) external notInitialized {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        state._name = _name;
        state._symbol = _symbol;
        state._royaltyRegistry = IRoyaltiesRegistry(_royaltyRegistry);
        state._editionCounter = 1;
        state._edition_max_tokens = DEFAULT_EDITION_TOKEN_MULTIPLIER;
        _grantRole(COLLECTION_ADMIN_ROLE, _collectionAdmin);
        _setOwner(_collectionAdmin);
        _setWinterWallet(0xdAb1a1854214684acE522439684a145E62505233);
        _initOperatorRegsitry();
    }

    /**
     * @dev Overload `initialize` function with `_edition_max_tokens` argument
     */
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _collectionAdmin,
        address _royaltyRegistry,
        uint24 _edition_max_tokens
    ) external notInitialized {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        state._name = _name;
        state._symbol = _symbol;
        state._royaltyRegistry = IRoyaltiesRegistry(_royaltyRegistry);
        state._editionCounter = 1;
        state._edition_max_tokens = _edition_max_tokens;
        _grantRole(COLLECTION_ADMIN_ROLE, _collectionAdmin);
        _setOwner(_collectionAdmin);
        _setWinterWallet(0xdAb1a1854214684acE522439684a145E62505233);
        _initOperatorRegsitry();
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == IERC4906_INTERFACE ||
            interfaceId == IERC2981_INTERFACE ||
            interfaceId == IERC721_INTERFACE ||
            interfaceId == IERC721METADATA_INTERFACE ||
            interfaceId == IERC165_INTERFACE;
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                           IERC721Metadata
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    function name() external view override returns (string memory) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        return state._name;
    }

    function symbol() external view override returns (string memory) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        return state._symbol;
    }
    function setName(string calldata _name) onlyAdmin public  {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        state._name = _name;
    }

    function setSymbol(string calldata _symbol) onlyAdmin public  {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        state._symbol = _symbol;
    }

    function tokenURI(
        uint256 tokenId
    ) external view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert CustomErrors.TokenNotFound();
        }

        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        (uint256 editionId, ) = parseEditionFromTokenId(tokenId);
        ERC721State.Edition memory edition = getEdition(editionId);
        if (edition.perTokenMetadata) {
            return
                string(
                    abi.encodePacked(
                        state._baseURIByEdition[editionId],
                        LANFTUtils.toString(tokenId)
                    )
                );
        }
        return state._baseURIByEdition[editionId];
    }

    function totalSupply() external view override returns (uint256) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        uint256 _count;
        for (uint256 i = 1; i < state._editionCounter; i += 1) {
            _count += editionMintedTokens(i);
        }
        return _count;
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               EDITIONS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /**
     * @notice Backward compatibility with the frontend
     */
    function EDITION_TOKEN_MULTIPLIER() public view returns (uint24) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        return state._edition_max_tokens;
    }

    function EDITION_MAX_SIZE() public view returns (uint24) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        return state._edition_max_tokens - 1;
    }

    /**
     * @notice Creates a new Edition
     * Editions can be seen as collections within a collection.
     * The token Ids for the a given edition have the following format:
     * `[editionId][tokenNumber]`
     * eg.: The Id of the 2nd token of the 5th edition is: `5000002`
     *
     */
    function createEdition(
        string calldata _baseURI,
        uint24 _maxSupply,
        uint24 _publicMintPriceInFinney,
        uint32 _publicMintStartTS,
        uint32 _publicMintEndTS,
        uint8 _maxMintPerWallet,
        bool _perTokenMetadata,
        uint8 _burnableEditionId,
        uint8 _amountToBurn
    ) public onlyAdmin returns (uint256) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        if (_maxSupply >= state._edition_max_tokens - 1) {
            revert CustomErrors.MaxSupplyError();
        }

        state._editions[state._editionCounter] = ERC721State.Edition({
            maxSupply: _maxSupply,
            burnedSupply: 0,
            currentSupply: 0,
            publicMintPriceInFinney: _publicMintPriceInFinney,
            publicMintStartTS: _publicMintStartTS,
            publicMintEndTS: _publicMintEndTS,
            maxMintPerWallet: _maxMintPerWallet,
            perTokenMetadata: _perTokenMetadata,
            burnableEditionId: _burnableEditionId,
            amountToBurn: _amountToBurn
        });

        state._baseURIByEdition[state._editionCounter] = _baseURI;
        emit EditionCreated(
            address(this),
            state._editionCounter,
            _maxSupply,
            _baseURI,
            _publicMintPriceInFinney,
            _perTokenMetadata
        );

        emit BatchMetadataUpdate(
           editionedTokenId(state._editionCounter, 1),
           editionedTokenId(state._editionCounter, _maxSupply)
        );        

        state._editionCounter += 1;

        // -1 because we return the current edition Id
        return state._editionCounter - 1;
    }

    /**
     * @notice updates an edition base URI
     */
    function updateEditionBaseURI(
        uint256 editionId,
        string calldata _baseURI
    ) external onlyAdmin {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        if (editionId > state._editionCounter) {
            revert CustomErrors.InvalidEditionId();
        }

        ERC721State.Edition storage edition = state._editions[editionId];
        state._baseURIByEdition[editionId] = _baseURI;
        emit EditionUpdated(
            address(this),
            editionId,
            edition.maxSupply,
            _baseURI
        );
        emit BatchMetadataUpdate(
           editionedTokenId(editionId, 1),
           editionedTokenId(editionId,  state._editions[editionId].maxSupply)
        );     
    }

    /**
     * @notice updates edition parameter. Careful: This will overwrite all previously set values on that edition.
     */
    function updateEdition(
        uint256 editionId,
        uint24 _publicMintPriceInFinney,
        uint32 _publicMintStartTS,
        uint32 _publicMintEndTS,
        uint8 _maxMintPerWallet,
        uint24 _maxSupply
    ) external onlyAdmin {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        if (editionId > state._editionCounter) {
            revert CustomErrors.InvalidEditionId();
        }

        ERC721State.Edition storage edition = state._editions[editionId];
        if (_maxSupply < edition.currentSupply - edition.burnedSupply) {
            revert CustomErrors.MaxSupplyError();
        }
        edition.publicMintPriceInFinney = _publicMintPriceInFinney;
        edition.publicMintStartTS = _publicMintStartTS;
        edition.publicMintEndTS = _publicMintEndTS;
        edition.maxMintPerWallet = _maxMintPerWallet;
        edition.maxSupply = _maxSupply;
    }

    /**
     * @notice fetch edition struct data by editionId
     */
    function getEdition(
        uint256 _editionId
    ) public view override returns (ERC721State.Edition memory) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        if (_editionId > state._editionCounter) {
            revert CustomErrors.InvalidEditionId();
        }
        return state._editions[_editionId];
    }

    /**
     * @notice fetch edition struct data by editionId
     */
    function getEditionWithURI(
        uint256 _editionId
    )
        public
        view
        override
        returns (ERC721State.EditionWithURI memory editionWithURI)
    {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        if (_editionId > state._editionCounter) {
            revert CustomErrors.InvalidEditionId();
        }
        editionWithURI = ERC721State.EditionWithURI({
            data: state._editions[_editionId],
            baseURI: state._baseURIByEdition[_editionId]
        });
    }

    /**
     * @notice Returns the total number of editions
     */
    function totalEditions() external view returns (uint256 total) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        total = state._editionCounter - 1;
    }

    /**
     * @notice Returns the current supply of a given edition
     */
    function editionMintedTokens(
        uint256 editionId
    ) public view returns (uint256 supply) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        ERC721State.Edition memory edition = state._editions[editionId];
        return edition.currentSupply - edition.burnedSupply;
    }

    /**
     * @dev Given an editionId and  tokenNumber, returns tokenId in the following format:
     * `[editionId][tokenNumber]` where `tokenNumber` is between 1 and state._edition_max_tokens  - 1
     * eg.: The second token from the 5th edition would be `500002`
     *
     */
    function editionedTokenId(
        uint256 editionId,
        uint256 tokenNumber
    ) public view returns (uint256 tokenId) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        uint256 paddedEditionID = editionId * state._edition_max_tokens;
        tokenId = paddedEditionID + tokenNumber;
    }

    /**
     * @dev Given a tokenId return editionId and tokenNumber.
     * eg.: 3000005 => editionId 3 and tokenNumber 5
     */
    function parseEditionFromTokenId(
        uint256 tokenId
    ) public view returns (uint256 editionId, uint256 tokenNumber) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        // Divide first to lose the decimal. ie. 1000001 / 1000000 = 1
        editionId = tokenId / state._edition_max_tokens;
        tokenNumber = tokenId - (editionId * state._edition_max_tokens);
    }

    /// @dev Is public mint open for given edition
    function isPublicMintStarted(uint256 editionId) public view returns (bool) {
        ERC721State.Edition memory edition = getEdition(editionId);
        bool started = (edition.publicMintStartTS != 0 &&
            edition.publicMintStartTS <= block.timestamp) &&
            (edition.publicMintEndTS == 0 ||
                edition.publicMintEndTS > block.timestamp);
        return started;
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               MODIFIERS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    modifier whenPublicMintOpened(uint256 editionId) {
        if (!isPublicMintStarted(editionId)) {
            revert CustomErrors.MintClosed();
        }
        _;
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               MINTABLE
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    /**
     * @dev Internal batch minting function
     */
    function _safeMint(
        uint256 _editionId,
        uint24 _quantity,
        address _recipient
    ) internal virtual returns (uint256 firstTokenId) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        ERC721State.Edition storage edition = state._editions[_editionId];

        uint256 tokenNumber = edition.currentSupply + 1;

        if (_editionId > state._editionCounter) {
            revert CustomErrors.InvalidEditionId();
        }

        if (_quantity == 0 || _recipient == address(0)) {
            revert CustomErrors.InvalidMintData();
        }

        if (tokenNumber > edition.maxSupply) {
            revert CustomErrors.MaxSupplyError();
        }

        firstTokenId = editionedTokenId(_editionId, tokenNumber);

        if (edition.currentSupply + _quantity > edition.maxSupply) {
            revert CustomErrors.MaxSupplyError();
        }

        edition.currentSupply += _quantity;
        state._owners[firstTokenId] = _recipient;
        state._batchHead.set(firstTokenId);
        state._balances[_recipient] += _quantity;

        // Emit events
        for (
            uint256 tokenId = firstTokenId;
            tokenId < firstTokenId + _quantity;
            tokenId++
        ) {
            emit Transfer(address(0), _recipient, tokenId);
            LANFTUtils._checkOnERC721Received(
                address(0),
                _recipient,
                tokenId,
                ""
            );
        }
    }

    function mintEditionTokens(
        uint256 _editionId,
        uint24 _quantity,
        address _recipient
    ) public payable whenPublicMintOpened(_editionId) whenNotPaused {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();

        ERC721State.Edition memory edition = getEdition(_editionId);

        // Check max mint per wallet restrictions (if maxMintPerWallet is 0, no restriction apply)
        if (edition.maxMintPerWallet != 0 && !_isWinterWallet()) {
            uint256 mintedCountKey = uint256(
                keccak256(abi.encodePacked(_editionId, msg.sender))
            );
            if (
                state._mintedPerWallet[mintedCountKey] + _quantity >
                edition.maxMintPerWallet
            ) {
                revert CustomErrors.MaximumMintAmountReached();
            }
            state._mintedPerWallet[mintedCountKey] += _quantity;
        }

        // Finney to Wei
        uint256 mintPriceInWei = uint256(edition.publicMintPriceInFinney) *
            10e14;

        // Check if sufficiant
        if (msg.value < mintPriceInWei * _quantity) {
            revert CustomErrors.InsufficientFunds();
        }

        uint256 firstTokenId = _safeMint(_editionId, _quantity, _recipient);

        // Send primary royalties
        (
            address payable[] memory wallets,
            uint256[] memory primarySalePercentages
        ) = state._royaltyRegistry.primaryRoyaltyInfo(
                address(this),
                firstTokenId
            );

        uint256 nReceivers = wallets.length;

        for (uint256 i = 0; i < nReceivers; i++) {
            uint256 royalties = BPS._calculatePercentage(
                msg.value,
                primarySalePercentages[i]
            );
            (bool sent, ) = wallets[i].call{value: royalties}("");

            if (!sent) {
                revert CustomErrors.FundTransferError();
            }
        }
    }

    function adminMint(
        uint256 _editionId,
        uint24 _quantity,
        address _recipient
    ) public onlyAdmin {
        _safeMint(_editionId, _quantity, _recipient);
    }

    function getMintedCount(
        uint256 _editionId,
        address _recipient
    ) public view returns (uint256) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        uint256 mintedCountKey = uint256(
            keccak256(abi.encodePacked(_editionId, _recipient))
        );
        return state._mintedPerWallet[mintedCountKey];
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               PAUSABLE
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    function pauseContract() public onlyAdmin {
        _pause();
    }

    function unpauseContract() public onlyAdmin {
        _unpause();
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                                   ERC721
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /// @dev See {IERC721-approve}.
    function approve(
        address to,
        uint256 tokenId
    ) external override onlyAllowedOperatorApproval(to) {
        address owner = ownerOf(tokenId);
        if (
            msg.sender == to ||
            (msg.sender != owner && !isApprovedForAll(owner, msg.sender))
        ) {
            revert CustomErrors.NotAllowed();
        }

        _approve(to, tokenId);
    }

    /// @dev See {IERC721-transferFrom}.
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override onlyAllowedOperator(from) {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert CustomErrors.TransferError();
        }

        _transfer(from, to, tokenId);
    }

    /// @dev See {IERC721-ownerOf}.
    function ownerOf(uint256 tokenId) public view override returns (address) {
        (address owner, ) = _ownerAndBatchHeadOf(tokenId);
        return owner;
    }

    /// @dev Returns the number of tokens in ``owner``'s account.
    function balanceOf(
        address owner
    ) external view returns (uint256 tokenBalance) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        tokenBalance = state._balances[owner];
    }

    /// @dev See {IERC721-getApproved}.
    function getApproved(
        uint256 tokenId
    ) public view override returns (address) {
        if (!_exists(tokenId)) {
            revert CustomErrors.TokenNotFound();
        }
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        return state._tokenApprovals[tokenId];
    }

    /// @dev See {IERC721-isApprovedForAll}.
    function isApprovedForAll(
        address owner,
        address operator
    ) public view override returns (bool) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        return state._operatorApprovals[owner][operator];
    }

    /// @dev See {IERC721-setApprovalForAll}.
    function setApprovalForAll(
        address operator,
        bool approved
    ) external override onlyAllowedOperatorApproval(operator) {
        if (operator == msg.sender) {
            revert CustomErrors.NotAllowed();
        }

        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        state._operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @dev See {IERC721-safeTransferFrom}.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override onlyAllowedOperator(from) {
        safeTransferFrom(from, to, tokenId, "");
    }

    /// @dev See {IERC721-safeTransferFrom}.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override onlyAllowedOperator(from) {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert CustomErrors.NotAllowed();
        }
        _safeTransfer(from, to, tokenId, _data);
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                         INTERNAL / PUBLIC HELPERS
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /// @dev Returns whether `tokenId` exists.
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        (uint256 editionId, uint256 tokenNumber) = parseEditionFromTokenId(
            tokenId
        );
        if (isBurned(tokenId)) {
            return false;
        }
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        ERC721State.Edition memory edition = state._editions[editionId];
        return tokenNumber <= edition.currentSupply;
    }

    /**
     * @dev Returns the index of the batch for a given token.
     * If the token was not bought in a batch tokenId == tokenIdBatchHead
     */
    function _getBatchHead(
        uint256 tokenId
    ) internal view returns (uint256 tokenIdBatchHead) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        (uint256 editionId, ) = parseEditionFromTokenId(tokenId);
        tokenIdBatchHead = state._batchHead.scanForward(
            tokenId,
            editionId * state._edition_max_tokens
        );
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();

        state._tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Returns the index of the batch for a given token.
     * and the batch owner address
     */
    function _ownerAndBatchHeadOf(
        uint256 tokenId
    ) internal view returns (address owner, uint256 tokenIdBatchHead) {
        if (!_exists(tokenId)) {
            revert CustomErrors.TokenNotFound();
        }

        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        tokenIdBatchHead = _getBatchHead(tokenId);
        owner = state._owners[tokenIdBatchHead];
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view returns (bool) {
        if (!_exists(tokenId)) {
            revert CustomErrors.TokenNotFound();
        }

        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     * Internal function intened to split the logic for different transfer use cases
     * Emits a {Transfer} event.
     */
    function _transferCore(address from, address to, uint256 tokenId) internal {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        (, uint256 tokenIdBatchHead) = _ownerAndBatchHeadOf(tokenId);

        address owner = ownerOf(tokenId);

        if (owner != from) {
            revert CustomErrors.TransferError();
        }

        // We check if the token after the one being transfer
        // belong to the batch, if it does, we have to update it's owner
        // while being careful to not overflow the edition maxSupply
        uint256 nextTokenId = tokenId + 1;
        (, uint256 nextTokenNumber) = parseEditionFromTokenId(nextTokenId);
        (uint256 currentEditionId, ) = parseEditionFromTokenId(tokenId);

        ERC721State.Edition memory edition = state._editions[currentEditionId];
        if (
            nextTokenNumber <= edition.maxSupply &&
            !state._batchHead.get(nextTokenId)
        ) {
            state._owners[nextTokenId] = from;
            state._batchHead.set(nextTokenId);
        }

        // Finaly we update the owners and balances
        state._owners[tokenId] = to;
        if (tokenId != tokenIdBatchHead) {
            state._batchHead.set(tokenId);
        }

        state._balances[to] += 1;
        state._balances[from] -= 1;
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        _beforeTokenTransfer(from, to, tokenId);
        // Remove approval
        _approve(address(0), tokenId);
        emit Transfer(from, to, tokenId);
        _transferCore(from, to, tokenId);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        LANFTUtils._checkOnERC721Received(from, to, tokenId, _data);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    function isBurned(uint256 tokenId) public view returns (bool) {
        ERC721State.ERC721LAState storage state = ERC721State
            ._getERC721LAState();
        address owner = state._owners[tokenId];
        return owner == burnAddress;
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     *                               ETHER
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawAmount(
        address payable recipient,
        uint256 amount
    ) external onlyAdmin {
        (bool succeed, ) = recipient.call{value: amount}("");
        if (!succeed) {
            revert CustomErrors.FundTransferError();
        }
    }

    function withdrawAll(address payable recipient) external onlyAdmin {
        (bool succeed, ) = recipient.call{value: balance()}("");
        if (!succeed) {
            revert CustomErrors.FundTransferError();
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "./IAccessControl.sol";

abstract contract AccessControl is IAccessControl{

    bytes32 public constant COLLECTION_ADMIN_ROLE =
        keccak256("COLLECTION_ADMIN_ROLE");

    function _getAccessControlState()
        internal
        pure
        returns (RoleState storage state)
    {
        bytes32 position = keccak256("liveart.AccessControl");
        assembly {
            state.slot := position
        }
    }

    /**
     * @notice Checks that msg.sender has a specific role.
     * Reverts with a AccessControlNotAllowed.
     *
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @notice Checks that msg.sender has COLLECTION_ADMIN_ROLE
     * Reverts with a AccessControlNotAllowed.
     *
     */
    modifier onlyAdmin() {
        _checkRole(COLLECTION_ADMIN_ROLE);
        _;
    }


    function isAdmin(address theAddress) public view returns (bool) {
        return hasRole(COLLECTION_ADMIN_ROLE, theAddress);
    }

    /**
     * @notice Checks if role is assigned to account
     *
     */
    function hasRole(bytes32 role, address account) public view returns (bool) {
        RoleState storage state = _getAccessControlState();
        return state._roles[role][account];
    }

    /**
     * @notice Revert with a AccessControlNotAllowed message if `msg.sender` is missing `role`.
     *
     */
    function _checkRole(bytes32 role) internal view virtual {
        if (!hasRole(role, msg.sender)) {
            revert AccessControlNotAllowed();
        }
    }

    /**
     * @notice Grants `role` to `account`.
     *
     * @dev If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account)
        public
        onlyAdmin
    {
        _grantRole(role, account);
    }

    /**
     * @notice Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have COLLECTION_ADMIN_ROLE role.
     */
    function revokeRole(bytes32 role, address account)
        public
        onlyAdmin
    {
        _revokeRole(role, account);
    }

    /**
     * @notice Revokes `role` from the calling account.
     *
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual {
        if (account != msg.sender) {
            revert AccessControlNotAllowed();
        }

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal {
        RoleState storage state = _getAccessControlState();
        if (!hasRole(role, account)) {
            state._roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal {
        RoleState storage state = _getAccessControlState();
        if (hasRole(role, account)) {
            state._roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "../extensions/AccessControl.sol";

/**
 * Used to set Winter whitelisted minting addresses
 */
contract Winter is AccessControl {

    struct WinterState {
        address[] winterAddresses;
    }

    function _getWinterState()
        internal
        pure
        returns (WinterState storage state)
    {
        bytes32 position = keccak256("liveart.Winter");
        assembly {
            state.slot := position
        }
    }

    function addWinterWallets(address[] calldata newAddresses) public onlyAdmin {
        for(uint256 i; i < newAddresses.length; i += 1) {
            _setWinterWallet(newAddresses[i]);
        }
    }

    function addWinterWallet(address newAddress) public onlyAdmin {
        _setWinterWallet(newAddress);
    }

    function _setWinterWallet(address newAddress) internal  {
        WinterState storage state = _getWinterState();
        state.winterAddresses.push(newAddress);
    }

    function deleteWinterWallet(address newAddress) public onlyAdmin {
        WinterState storage state = _getWinterState();
        for(uint256 i; i < state.winterAddresses.length; i += 1) {
            if(newAddress == state.winterAddresses[i]) {
                delete state.winterAddresses[i];
            }
        }
        state.winterAddresses.push(newAddress);
    }

    function _isWinterWallet() internal view returns (bool) {
        WinterState storage state = _getWinterState();

        for(uint256 i; i < state.winterAddresses.length; i += 1) {
            if(msg.sender == state.winterAddresses[i]) {
                return true;
            }
        }
        return false;
    }
}

/// @title EIP-721 Metadata Update Extension
interface IERC4906  {
    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.    
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

abstract contract Ownable {
    error CallerIsNotOwner();
    error NewOwnerIsZeroAddress();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct OwnableState {
        address owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view returns(address){
        OwnableState storage state = _getOwnableState();
        return state.owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if(newOwner == address(0)){
            revert NewOwnerIsZeroAddress();
        }
        _transferOwnership(newOwner);
    }


    function _getOwnableState()
        internal
        pure
        returns (OwnableState storage state)
    {
        bytes32 position = keccak256("liveart.Ownable");
        assembly {
            state.slot := position
        }
    }


    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if(owner() != msg.sender) {
            revert CallerIsNotOwner();
        } 
    }


    function _setOwner(address newOwner) internal {
        OwnableState storage state = _getOwnableState();
        state.owner = newOwner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal {
        address previousOwner = owner();
        _setOwner(newOwner);
        emit OwnershipTransferred(previousOwner, newOwner);
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "../libraries/BitMaps/BitMaps.sol";
import "../platform/royalties/IRoyaltiesRegistry.sol";

interface IERC721Events {
    event EditionCreated(
        address indexed contractAddress,
        uint256 editionId,
        uint24 maxSupply,
        string baseURI,
        uint24 contractMintPrice,
        bool perTokenMetadata

    );
    event EditionUpdated(
        address indexed contractAddress,
        uint256 editionId,
        uint256 maxSupply,
        string baseURI
    );
    
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IAccessControl {
    error AccessControlNotAllowed();



    struct RoleState {
        mapping(bytes32 => mapping(address => bool)) _roles;
    }

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     */
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );


    /**
     * @notice Checks if role is assigned to account
     *
     */
    function hasRole(bytes32 role, address account) external returns (bool);


    /**
     * @notice Grants `role` to `account`.
     *
     * @dev If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account)
        external;
    /**
     * @notice Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have COLLECTION_ADMIN_ROLE role.
     */
    function revokeRole(bytes32 role, address account)
        external;

    /**
     * @notice Revokes `role` from the calling account.
     *
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;

   function isAdmin(address theAddress) external view returns (bool);

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./BitScan.sol";
/**
 * Derived from: https://github.com/estarriolvetch/solidity-bits
 */
/**
 * @dev This Library is a modified version of Openzeppelin's BitMaps library.
 * Functions of finding the index of the closest set bit from a given index are added.
 * The indexing of each bucket is modifed to count from the MSB to the LSB instead of from the LSB to the MSB.
 * The modification of indexing makes finding the closest previous set bit more efficient in gas usage.
 */

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, providing the keys are sequential.
 * Largelly inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 */

error BitMapHeadNotFound();

library BitMaps {
    using BitScan for uint256;
    uint256 private constant MASK_INDEX_ZERO = (1 << 255);
    struct BitMap {
        mapping(uint256 => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    function get(BitMap storage bitmap, uint256 index)
        internal
        view
        returns (bool)
    {
        uint256 bucket = index >> 8;
        uint256 mask = MASK_INDEX_ZERO >> (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    function setTo(
        BitMap storage bitmap,
        uint256 index,
        bool value
    ) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = MASK_INDEX_ZERO >> (index & 0xff);
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = MASK_INDEX_ZERO >> (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }

    /**
     * @dev Find the closest index of the set bit before `index`.
     */
    function scanForward(
        BitMap storage bitmap,
        uint256 index,
        uint256 lowerBound
    ) internal view returns (uint256 matchedIndex) {
        uint256 bucket = index >> 8;
        uint256 lowerBoundBucket = lowerBound >> 8;

        // index within the bucket
        uint256 bucketIndex = (index & 0xff);

        // load a bitboard from the bitmap.
        uint256 bb = bitmap._data[bucket];

        // offset the bitboard to scan from `bucketIndex`.
        bb = bb >> (0xff ^ bucketIndex); // bb >> (255 - bucketIndex)

        if (bb > 0) {
            unchecked {
                return (bucket << 8) | (bucketIndex - bb.bitScanForward256());
            }
        } else {
            while (true) {
                // require(bucket > lowerBound, "BitMaps: The set bit before the index doesn't exist.");
                if (bucket < lowerBoundBucket) {
                    revert BitMapHeadNotFound();
                }
                unchecked {
                    bucket--;
                }
                // No offset. Always scan from the least significiant bit now.
                bb = bitmap._data[bucket];

                if (bb > 0) {
                    unchecked {
                        return (bucket << 8) | (255 - bb.bitScanForward256());
                    }
                }
            }
        }
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./specs/IRarible.sol";
import "./RoyaltiesState.sol";

/// @dev Royalty registry interface
interface IRoyaltiesRegistry is IERC165 {
    /// @dev Raised when trying to set a royalty override for a token
    error NotApproved();
    error NotOwner();

    /// @dev Raised when providing multiple royalty overrides when only one is expected
    error MultipleRoyaltyRecievers();

    /// @dev Raised when sales percentage is not between 0 and 100
    error PrimarySalePercentageOutOfRange();
    error SecondarySalePercentageOutOfRange();

    /// @dev Raised accumulated primary royalty percentage is not 100
    error PrimarySalePercentageNotEqualToMax();

    /**
     * Raised trying to set edition or token royalties
     */
    error NotEditionCreator();

    // ==============================
    //            EVENTS
    // ==============================
    event RoyaltyOverride(
        address owner,
        address tokenAddress,
        address royaltyAddress
    );

    event RoyaltyTokenOverride(
        address owner,
        address tokenAddress,
        uint256 tokenId,
        address royaltyAddress
    );

    // ==============================
    //            IERC165
    // ==============================

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        external
        view
        override
        returns (bool);

    // ==============================
    //            SECONDARY ROYALTY
    // ==============================

    /*
    @notice Called with the sale price to determine how much royalty is owed and to whom.
    @param _contractAddress - The collection address
    @param _tokenId - the NFT asset queried for royalty information
    @param _value - the sale price of the NFT asset specified by _tokenId
    @return _receiver - address of who should be sent the royalty payment
    @return _royaltyAmount - the royalty payment amount for value sale price
    */
    function royaltyInfo(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _value
    ) external view returns (address _receiver, uint256 _royaltyAmount);

    /**
     *  Return RoyaltyReceivers for primary sales
     *
     */
    function primaryRoyaltyInfo(address collectionAddress, uint256 tokenId)
        external
        view
        returns (address payable[] memory, uint256[] memory);

    /**
     *  @dev CreatorCore - Supports Manifold, ArtBlocks
     *
     *  getRoyalties
     */
    function getRoyalties(address collectionAddress, uint256 tokenId)
        external
        view
        returns (address payable[] memory, uint256[] memory);

    /**
     *  @dev Foundation
     *
     *  getFees
     */
    function getFees(address collectionAddress, uint256 editionId)
        external
        view
        returns (address payable[] memory, uint256[] memory);

    /**
     *  @dev Rarible: RoyaltiesV1
     *
     *  getFeeBps
     */
    function getFeeBps(address collectionAddress, uint256 tokenId)
        external
        view
        returns (uint256[] memory);

    /**
     *  @dev Rarible: RoyaltiesV1
     *
     *  getFeeRecipients
     */
    function getFeeRecipients(address collectionAddress, uint256 editionId)
        external
        view
        returns (address payable[] memory);

    /**
     *  @dev Rarible: RoyaltiesV2
     *
     *  getRaribleV2Royalties
     */
    function getRaribleV2Royalties(address collectionAddress, uint256 tokenId)
        external
        view
        returns (IRaribleV2.Part[] memory);

    /**
     *  @dev CreatorCore - Support for KODA
     *
     *  getKODAV2RoyaltyInfo
     */
    function getKODAV2RoyaltyInfo(address collectionAddress, uint256 tokenId)
        external
        view
        returns (address payable[] memory recipients_, uint256[] memory bps);

    /**
     *  @dev CreatorCore - Support for Zora
     *
     *  convertBidShares
     */
    function convertBidShares(address collectionAddress, uint256 tokenId)
        external
        view
        returns (address payable[] memory recipients_, uint256[] memory bps);

    /*
    @notice Called from a collection contract to set a primary royalty override
    @param collectionAddress - The collection address
    @param sender - The address of the caller
    @param RoyaltyReceiver[] - The royalty receivers details
    */
    function registerCollectionRoyaltyReceivers(
        address collectionAddress,
        address sender,
        RoyaltiesState.RoyaltyReceiver[] memory royaltyReceivers
    ) external;

    /*
    @notice Called from a collection contract to set a primary royalty override
    @param collectionAddress - The collection address
    @param sender - The address of the caller
    @param tokenId - The token id
    @param RoyaltyReceiver[] - The royalty receivers details
    */
    function registerEditionRoyaltyReceivers(
        address collectionAddress,
        address sender,
        uint256 tokenId,
        RoyaltiesState.RoyaltyReceiver[] memory royaltyReceivers
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
/**
   _____       ___     ___ __           ____  _ __      
  / ___/____  / (_)___/ (_) /___  __   / __ )(_) /______
  \__ \/ __ \/ / / __  / / __/ / / /  / __  / / __/ ___/
 ___/ / /_/ / / / /_/ / / /_/ /_/ /  / /_/ / / /_(__  ) 
/____/\____/_/_/\__,_/_/\__/\__, /  /_____/_/\__/____/  
                           /____/                        

- npm: https://www.npmjs.com/package/solidity-bits
- github: https://github.com/estarriolvetch/solidity-bits

 */

pragma solidity ^0.8.4;


library BitScan {
    uint256 constant private DEBRUIJN_256 = 0x818283848586878898a8b8c8d8e8f929395969799a9b9d9e9faaeb6bedeeff;
    bytes constant private LOOKUP_TABLE_256 = hex"0001020903110a19042112290b311a3905412245134d2a550c5d32651b6d3a7506264262237d468514804e8d2b95569d0d495ea533a966b11c886eb93bc176c9071727374353637324837e9b47af86c7155181ad4fd18ed32c9096db57d59ee30e2e4a6a5f92a6be3498aae067ddb2eb1d5989b56fd7baf33ca0c2ee77e5caf7ff0810182028303840444c545c646c7425617c847f8c949c48a4a8b087b8c0c816365272829aaec650acd0d28fdad4e22d6991bd97dfdcea58b4d6f29fede4f6fe0f1f2f3f4b5b6b607b8b93a3a7b7bf357199c5abcfd9e168bcdee9b3f1ecf5fd1e3e5a7a8aa2b670c4ced8bbe8f0f4fc3d79a1c3cde7effb78cce6facbf9f8";

    /**
        @dev Isolate the least significant set bit.
     */ 
    function isolateLS1B256(uint256 bb) pure internal returns (uint256) {
        require(bb > 0);
        unchecked {
            return bb & (0 - bb);
        }
    } 

    /**
        @dev Isolate the most significant set bit.
     */ 
    function isolateMS1B256(uint256 bb) pure internal returns (uint256) {
        require(bb > 0);
        unchecked {
            bb |= bb >> 256;
            bb |= bb >> 128;
            bb |= bb >> 64;
            bb |= bb >> 32;
            bb |= bb >> 16;
            bb |= bb >> 8;
            bb |= bb >> 4;
            bb |= bb >> 2;
            bb |= bb >> 1;
            
            return (bb >> 1) + 1;
        }
    } 

    /**
        @dev Find the index of the lest significant set bit. (trailing zero count)
     */ 
    function bitScanForward256(uint256 bb) pure internal returns (uint8) {
        unchecked {
            return uint8(LOOKUP_TABLE_256[(isolateLS1B256(bb) * DEBRUIJN_256) >> 248]);
        }   
    }

    /**
        @dev Find the index of the most significant set bit.
     */ 
    function bitScanReverse256(uint256 bb) pure internal returns (uint8) {
        unchecked {
            return 255 - uint8(LOOKUP_TABLE_256[((isolateMS1B256(bb) * DEBRUIJN_256) >> 248)]);
        }   
    }

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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

interface IRaribleV1 {
    /*
     * bytes4(keccak256('getFeeBps(uint256)')) == 0x0ebd4c7f
     * bytes4(keccak256('getFeeRecipients(uint256)')) == 0xb9c4d9fb
     *
     * => 0x0ebd4c7f ^ 0xb9c4d9fb == 0xb7799584
     */
    function getFeeBps(uint256 id) external view returns (uint256[] memory);

    function getFeeRecipients(uint256 id)
        external
        view
        returns (address payable[] memory);
}

interface IRaribleV2 {
    /*
     *  bytes4(keccak256('getRaribleV2Royalties(uint256)')) == 0xcad96cca
     */
    struct Part {
        address payable account;
        uint96 value;
    }

    function getRaribleV2Royalties(uint256 id)
        external
        view
        returns (Part[] memory);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
import "operator-filter-registry/src/IOperatorFilterRegistry.sol";

library WithOperatorRegistryState {


    struct OperatorRegistryState {
      IOperatorFilterRegistry operatorFilterRegistry;
    }


    /**
     * @dev Get storage data from dedicated slot.
     * This pattern avoids storage conflict during proxy upgrades
     * and give more flexibility when creating extensions
     */
    function _getOperatorRegistryState()
        internal
        pure
        returns (OperatorRegistryState storage state)
    {
        bytes32 storageSlot = keccak256("liveart.OperatorRegistryState");
        assembly {
            state.slot := storageSlot
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IOperatorFilterRegistry {
    /**
     * @notice Returns true if operator is not filtered for a given token, either by address or codeHash. Also returns
     *         true if supplied registrant address is not registered.
     */
    function isOperatorAllowed(address registrant, address operator) external view returns (bool);

    /**
     * @notice Registers an address with the registry. May be called by address itself or by EIP-173 owner.
     */
    function register(address registrant) external;

    /**
     * @notice Registers an address with the registry and "subscribes" to another address's filtered operators and codeHashes.
     */
    function registerAndSubscribe(address registrant, address subscription) external;

    /**
     * @notice Registers an address with the registry and copies the filtered operators and codeHashes from another
     *         address without subscribing.
     */
    function registerAndCopyEntries(address registrant, address registrantToCopy) external;

    /**
     * @notice Unregisters an address with the registry and removes its subscription. May be called by address itself or by EIP-173 owner.
     *         Note that this does not remove any filtered addresses or codeHashes.
     *         Also note that any subscriptions to this registrant will still be active and follow the existing filtered addresses and codehashes.
     */
    function unregister(address addr) external;

    /**
     * @notice Update an operator address for a registered address - when filtered is true, the operator is filtered.
     */
    function updateOperator(address registrant, address operator, bool filtered) external;

    /**
     * @notice Update multiple operators for a registered address - when filtered is true, the operators will be filtered. Reverts on duplicates.
     */
    function updateOperators(address registrant, address[] calldata operators, bool filtered) external;

    /**
     * @notice Update a codeHash for a registered address - when filtered is true, the codeHash is filtered.
     */
    function updateCodeHash(address registrant, bytes32 codehash, bool filtered) external;

    /**
     * @notice Update multiple codeHashes for a registered address - when filtered is true, the codeHashes will be filtered. Reverts on duplicates.
     */
    function updateCodeHashes(address registrant, bytes32[] calldata codeHashes, bool filtered) external;

    /**
     * @notice Subscribe an address to another registrant's filtered operators and codeHashes. Will remove previous
     *         subscription if present.
     *         Note that accounts with subscriptions may go on to subscribe to other accounts - in this case,
     *         subscriptions will not be forwarded. Instead the former subscription's existing entries will still be
     *         used.
     */
    function subscribe(address registrant, address registrantToSubscribe) external;

    /**
     * @notice Unsubscribe an address from its current subscribed registrant, and optionally copy its filtered operators and codeHashes.
     */
    function unsubscribe(address registrant, bool copyExistingEntries) external;

    /**
     * @notice Get the subscription address of a given registrant, if any.
     */
    function subscriptionOf(address addr) external returns (address registrant);

    /**
     * @notice Get the set of addresses subscribed to a given registrant.
     *         Note that order is not guaranteed as updates are made.
     */
    function subscribers(address registrant) external returns (address[] memory);

    /**
     * @notice Get the subscriber at a given index in the set of addresses subscribed to a given registrant.
     *         Note that order is not guaranteed as updates are made.
     */
    function subscriberAt(address registrant, uint256 index) external returns (address);

    /**
     * @notice Copy filtered operators and codeHashes from a different registrantToCopy to addr.
     */
    function copyEntriesOf(address registrant, address registrantToCopy) external;

    /**
     * @notice Returns true if operator is filtered by a given address or its subscription.
     */
    function isOperatorFiltered(address registrant, address operator) external returns (bool);

    /**
     * @notice Returns true if the hash of an address's code is filtered by a given address or its subscription.
     */
    function isCodeHashOfFiltered(address registrant, address operatorWithCode) external returns (bool);

    /**
     * @notice Returns true if a codeHash is filtered by a given address or its subscription.
     */
    function isCodeHashFiltered(address registrant, bytes32 codeHash) external returns (bool);

    /**
     * @notice Returns a list of filtered operators for a given address or its subscription.
     */
    function filteredOperators(address addr) external returns (address[] memory);

    /**
     * @notice Returns the set of filtered codeHashes for a given address or its subscription.
     *         Note that order is not guaranteed as updates are made.
     */
    function filteredCodeHashes(address addr) external returns (bytes32[] memory);

    /**
     * @notice Returns the filtered operator at the given index of the set of filtered operators for a given address or
     *         its subscription.
     *         Note that order is not guaranteed as updates are made.
     */
    function filteredOperatorAt(address registrant, uint256 index) external returns (address);

    /**
     * @notice Returns the filtered codeHash at the given index of the list of filtered codeHashes for a given address or
     *         its subscription.
     *         Note that order is not guaranteed as updates are made.
     */
    function filteredCodeHashAt(address registrant, uint256 index) external returns (bytes32);

    /**
     * @notice Returns true if an address has registered
     */
    function isRegistered(address addr) external returns (bool);

    /**
     * @dev Convenience method to compute the code hash of an arbitrary contract
     */
    function codeHashOf(address addr) external returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

address constant CANONICAL_OPERATOR_FILTER_REGISTRY_ADDRESS = 0x000000000000AAeB6D7670E522A718067333cd4E;
address constant CANONICAL_CORI_SUBSCRIPTION = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;


interface IAirDropable {

    error TooManyAddresses();

    function airdrop(uint256 editionId, address[] calldata recipients, uint24 quantityPerAddres) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     *
     * _Available since v4.7._
     */
    function verifyCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     *
     * _Available since v4.7._
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be simultaneously proven to be a part of a merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and sibling nodes in `proof`. The reconstruction
     * proceeds by incrementally reconstructing all inner nodes by combining a leaf/inner node with either another
     * leaf/inner node or a proof sibling node, depending on whether each `proofFlags` item is true or false
     * respectively.
     *
     * CAUTION: Not all merkle trees admit multiproofs. To use multiproofs, it is sufficient to ensure that: 1) the tree
     * is complete (but not necessarily perfect), 2) the leaves to be proven are in the opposite order they are in the
     * tree (i.e., as seen from right to left starting at the deepest layer and continuing at the next layer).
     *
     * _Available since v4.7._
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IWhitelistable {
    /**
     * Raised when trying create a WhiteList config that already exisit (mint amounts are the same)
     */
    error WhiteListAlreadyExists();
    error NotWhitelisted();
    error InvalidMintDuration();

    function whitelistMint(
        uint256 editionId,
        uint8 maxAmount,
        uint24 mintPriceInFinney,
        bytes32[] calldata merkleProof,
        uint24 quantity,
        address receiver
    ) external payable;

    function setWLConfig(
        uint256 editionId,
        uint8 amount,
        uint24 mintPriceInFinney,
        uint32 mintStartTS,
        uint32 mintEndTS,
        bytes32 merkleRoot
    ) external;

    function updateWLConfig(
        uint256 editionId,
        uint8 amount,
        uint24 mintPriceInFinney,
        uint8 newAmount,
        uint24 newMintPriceInFinney,
        uint32 newMintStartTS,
        uint32 newMintEndTS,
        bytes32 newMerkleRoot
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library WhitelistableState {
    struct WhitelistConfig {
        bytes32 merkleRoot;
        uint8 amount;
        uint24 mintPriceInFinney;
        uint32 mintStartTS;
        uint32 mintEndTS;
    }

    struct WLState {
        // hash(EditionId + mintable amount + price)
        mapping(uint256 => WhitelistConfig) _whitelistConfig;
    }


    /**
     * @dev Get storage data from dedicated slot.
     * This pattern avoids storage conflict during proxy upgrades
     * and give more flexibility when creating extensions
     */
    function _getWhitelistableState()
        internal
        pure
        returns (WLState storage state)
    {
        bytes32 storageSlot = keccak256("liveart.Whitelistable");
        assembly {
            state.slot := storageSlot
        }
    }
}