/**
 *Submitted for verification at Etherscan.io on 2023-03-20
*/

// File: ethereum/contracts/interfaces/IVesting.sol


pragma solidity ^0.8.0;

interface IVesting{

    function setSaleId(uint256 saleId) external returns(bool);
    function claimAllocation(uint256 saleId, uint256 tokenIndex) external;
}

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: ethereum/contracts/icco/contributor/ContributorStructs.sol

// contracts/Structs.sol


pragma solidity ^0.8.0;

contract ContributorStructs {
    struct Sale {
        /// sale ID
        uint256 saleID;
        /// address of the token - left-zero-padded if shorter than 32 bytes
        bytes32 tokenAddress;
        /// chain ID of the token
        uint16 tokenChain;
        /// token decimals
        uint8 tokenDecimals;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// unlock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;        
        /// accepted Tokens
        uint16[] acceptedTokensChains;
        bytes32[] acceptedTokensAddresses;
        uint128[] acceptedTokensConversionRates;
        bool[] disabledAcceptedTokens;

        /// recipient of proceeds
        bytes32 recipient;

        /// KYC authority public key
        address authority;

        bool isSealed;
        bool isAborted;

        uint256[] allocations;
        uint256[] excessContributions;

        /// vesting
        bool isVested;
    }
}

// File: ethereum/contracts/icco/contributor/ContributorState.sol

// contracts/State.sol


pragma solidity ^0.8.0;


contract ContributorEvents {
    event EventSaleInit (
        uint256 saleId
    );

    event EventContribute (
        uint256 saleId,
        uint256 tokenIndex,
        uint256 amount
    );

    event EventAttestContribution (
        uint256 saleId
    );

    event EventSaleSealed (
        uint256 saleId
    );

    event EventClaimAllocation (
        uint256 saleId,
        uint256 tokenIndex,
        uint256 amount
    );

    event EventClaimRefund (
        uint256 saleId,
        uint256 tokenIndex,
        uint256 amount
    );

    event EventClaimExcessContribution (
        uint256 saleId,
        uint256 tokenIndex,
        uint256 amount
    );
}

contract ContributorStorage {
    struct Provider {
        uint16 chainId;
        uint16 conductorChainId;
        bytes32 conductorContract;
        address payable wormhole;
        address tokenBridge;
    }

    struct State {
        Provider provider;

        /// deployer of the contracts
        address owner;

        /// intermediate state when transfering contract ownership
        address pendingOwner;

        /// number of confirmations for wormhole messages
        uint8 consistencyLevel;

        /// mapping of initialized implementations
        mapping(address => bool) initializedImplementations;

        /// mapping of Sales
        mapping(uint256 => ContributorStructs.Sale) sales;

        /// sale id > token id > contributor > contribution
        mapping(uint256 => mapping(uint256 => mapping(address => uint256))) contributions;

        /// sale id > token id > contribution
        mapping(uint256 => mapping(uint256 => uint256)) totalContributions;

        /// sale id > token id > contributor > isClaimed
        mapping(uint256 => mapping(uint256 => mapping(address => bool))) allocationIsClaimed;

        /// sale id > [token id > contributor > isClaimed
        mapping(uint256 => mapping(uint256 => mapping(address => bool))) refundIsClaimed;

        /// sale id > [token id > contributor > isClaimed
        mapping(uint256 => mapping(uint256 => mapping(address => bool))) excessContributionIsClaimed;

        /// mapping of vesting contracts (tokenId => chainId => contractAddress)
        mapping(uint256 => mapping(uint16 => bytes32)) vestingContracts;

        /// @dev storage gap 
        uint256[50] ______gap;
    }
}

contract ContributorState {
    ContributorStorage.State _state;    
}
// File: ethereum/contracts/icco/contributor/ContributorSetters.sol

// contracts/Setters.sol


pragma solidity ^0.8.0;



contract ContributorSetters is ContributorState, Context {
    function setInitialized(address implementatiom) internal {
        _state.initializedImplementations[implementatiom] = true;
    }

    function setOwner(address owner_) internal {
        _state.owner = owner_;
    }

    function setPendingOwner(address newOwner) internal {
        _state.pendingOwner = newOwner;
    }

    function setNewAuthority(uint256 saleId, address newAuthority) internal {
        _state.sales[saleId].authority = newAuthority;
    }

    function setChainId(uint16 chainId) internal {
        _state.provider.chainId = chainId;
    }

    function setConductorChainId(uint16 chainId) internal {
        _state.provider.conductorChainId = chainId;
    }

    function setConductorContract(bytes32 conductorContract) internal {
        _state.provider.conductorContract = conductorContract;
    }

    function setWormhole(address wh) internal {
        _state.provider.wormhole = payable(wh);
    }

    function setTokenBridge(address tb) internal {
        _state.provider.tokenBridge = payable(tb);
    } 

    function setConsistencyLevel(uint8 level) internal {
        _state.consistencyLevel = level;
    }

    function setSale(uint256 saleId, ContributorStructs.Sale memory sale) internal {
        _state.sales[saleId] = sale;
    }

    function setSaleContribution(uint256 saleId, address contributor, uint256 tokenIndex, uint256 contribution) internal {
        _state.contributions[saleId][tokenIndex][contributor] += contribution;
        _state.totalContributions[saleId][tokenIndex] += contribution;
    }

    function setSaleSealed(uint256 saleId) internal {
        _state.sales[saleId].isSealed = true;
    }

    function setSaleAborted(uint256 saleId) internal {
        _state.sales[saleId].isAborted = true;
    }

    function setRefundClaimed(uint256 saleId, uint256 tokenIndex, address contributor) internal {
        _state.refundIsClaimed[saleId][tokenIndex][contributor] = true;
    }

    function setAllocationClaimed(uint256 saleId, uint256 tokenIndex, address contributor) internal {
        _state.allocationIsClaimed[saleId][tokenIndex][contributor] = true;
    }

    function setExcessContributionClaimed(uint256 saleId, uint256 tokenIndex, address contributor) internal {
        _state.excessContributionIsClaimed[saleId][tokenIndex][contributor] = true;
    }

    function setSaleAllocation(uint256 saleId, uint256 tokenIndex, uint256 allocation) internal {
        _state.sales[saleId].allocations[tokenIndex] = allocation;
    }

    function setExcessContribution(uint256 saleId, uint256 tokenIndex, uint256 excessContribution) internal {
        _state.sales[saleId].excessContributions[tokenIndex] = excessContribution;
    }

    function setVestingContract(uint256 saleId, uint16 chainId, bytes32 contractAddress) internal {
        _state.vestingContracts[saleId][chainId] = contractAddress;
    }
}
// File: ethereum/contracts/interfaces/ITokenBridge.sol

// contracts/Bridge.sol


pragma solidity ^0.8.0;


interface ITokenBridge {
    function transferTokens(address token, uint256 amount, uint16 recipientChain, bytes32 recipient, uint256 arbiterFee, uint32 nonce) external payable returns (uint64 sequence);

    function wrappedAsset(uint16 tokenChainId, bytes32 tokenAddress) external view returns (address);
}

// File: ethereum/contracts/interfaces/IWormhole.sol

// contracts/Messages.sol


pragma solidity ^0.8.0;

interface IWormhole {
    struct Provider {
		uint16 chainId;
		uint16 governanceChainId;
		bytes32 governanceContract;
	}

	struct GuardianSet {
		address[] keys;
		uint32 expirationTime;
	}

	struct Signature {
		bytes32 r;
		bytes32 s;
		uint8 v;
		uint8 guardianIndex;
	}

	struct VM {
		uint8 version;
		uint32 timestamp;
		uint32 nonce;
		uint16 emitterChainId;
		bytes32 emitterAddress;
		uint64 sequence;
		uint8 consistencyLevel;
		bytes payload;

		uint32 guardianSetIndex;
		Signature[] signatures;

		bytes32 hash;
	}

    event LogMessagePublished(address indexed sender, uint64 sequence, uint32 nonce, bytes payload, uint8 consistencyLevel);

    function publishMessage(
        uint32 nonce,
        bytes memory payload,
        uint8 consistencyLevel
    ) external payable returns (uint64 sequence);

    function parseAndVerifyVM(bytes calldata encodedVM) external view returns (VM memory vm, bool valid, string memory reason);

    function verifyVM(VM memory vm) external view returns (bool valid, string memory reason);

    function verifySignatures(bytes32 hash, Signature[] memory signatures, GuardianSet memory guardianSet) external pure returns (bool valid, string memory reason) ;

    function parseVM(bytes memory encodedVM) external pure returns (VM memory vm);

    function getGuardianSet(uint32 index) external view returns (GuardianSet memory) ;

    function getCurrentGuardianSetIndex() external view returns (uint32) ;

    function getGuardianSetExpiry() external view returns (uint32) ;

    function governanceActionIsConsumed(bytes32 hash) external view returns (bool) ;

    function isInitialized(address impl) external view returns (bool) ;

    function chainId() external view returns (uint16) ;

    function governanceChainId() external view returns (uint16);

    function governanceContract() external view returns (bytes32);

    function messageFee() external view returns (uint256) ;
}

// File: ethereum/contracts/libraries/external/BytesLib.sol


/*
 * @title Solidity Bytes Arrays Utils
 * @author Gonçalo Sá <[email protected]>
 *
 * @dev Bytes tightly packed arrays utility library for ethereum contracts written in Solidity.
 *      The library lets you concatenate, slice and type cast bytes arrays both in memory and storage.
 */
pragma solidity >=0.8.0 <0.9.0;


library BytesLib {
    function concat(
        bytes memory _preBytes,
        bytes memory _postBytes
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory tempBytes;

        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(tempBytes, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, length)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                // Write the _preBytes data into the tempBytes memory 32 bytes
                // at a time.
                mstore(mc, mload(cc))
            }

            // Add the length of _postBytes to the current length of tempBytes
            // and store it as the new length in the first 32 bytes of the
            // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            // Move the memory counter back from a multiple of 0x20 to the
            // actual end of the _preBytes data.
            mc := end
            // Stop copying when the memory counter reaches the new combined
            // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            // Update the free-memory pointer by padding our last write location
            // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
            // next 32 byte block, then round down to the nearest multiple of
            // 32. If the sum of the length of the two arrays is zero then add
            // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(0x40, and(
              add(add(end, iszero(add(length, mload(_preBytes)))), 31),
              not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }

    function concatStorage(bytes storage _preBytes, bytes memory _postBytes) internal {
        assembly {
            // Read the first 32 bytes of _preBytes storage, which is the length
            // of the array. (We don't need to use the offset into the slot
            // because arrays use the entire slot.)
            let fslot := sload(_preBytes.slot)
            // Arrays of 31 bytes or less have an even value in their slot,
            // while longer arrays have an odd value. The actual length is
            // the slot divided by two for odd values, and the lowest order
            // byte divided by two for even values.
            // If the slot is even, bitwise and the slot with 255 and divide by
            // two to get the length. If the slot is odd, bitwise and the slot
            // with -1 and divide by two.
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)
            let newlength := add(slength, mlength)
            // slength can contain both the length and contents of the array
            // if length < 32 bytes so let's prepare for that
            // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
            switch add(lt(slength, 32), lt(newlength, 32))
            case 2 {
                // Since the new array still fits in the slot, we just need to
                // update the contents of the slot.
                // uint256(bytes_storage) = uint256(bytes_storage) + uint256(bytes_memory) + new_length
                sstore(
                    _preBytes.slot,
                    // all the modifications to the slot are inside this
                    // next block
                    add(
                        // we can just add to the slot contents because the
                        // bytes we want to change are the LSBs
                        fslot,
                        add(
                            mul(
                                div(
                                    // load the bytes from memory
                                    mload(add(_postBytes, 0x20)),
                                    // zero all bytes to the right
                                    exp(0x100, sub(32, mlength))
                                ),
                                // and now shift left the number of bytes to
                                // leave space for the length in the slot
                                exp(0x100, sub(32, newlength))
                            ),
                            // increase length by the double of the memory
                            // bytes length
                            mul(mlength, 2)
                        )
                    )
                )
            }
            case 1 {
                // The stored value fits in the slot, but the combined value
                // will exceed it.
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // The contents of the _postBytes array start 32 bytes into
                // the structure. Our first read should obtain the `submod`
                // bytes that can fit into the unused space in the last word
                // of the stored array. To get this, we read 32 bytes starting
                // from `submod`, so the data we read overlaps with the array
                // contents by `submod` bytes. Masking the lowest-order
                // `submod` bytes allows us to add that value directly to the
                // stored value.

                let submod := sub(32, slength)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(
                    sc,
                    add(
                        and(
                            fslot,
                            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00
                        ),
                        and(mload(mc), mask)
                    )
                )

                for {
                    mc := add(mc, 0x20)
                    sc := add(sc, 1)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
            default {
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes.slot)
                // Start copying to the last used word of the stored array.
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))

                // save new length
                sstore(_preBytes.slot, add(mul(newlength, 2), 1))

                // Copy over the first `submod` bytes of the new data as in
                // case 1 above.
                let slengthmod := mod(slength, 32)
                let mlengthmod := mod(mlength, 32)
                let submod := sub(32, slengthmod)
                let mc := add(_postBytes, submod)
                let end := add(_postBytes, mlength)
                let mask := sub(exp(0x100, submod), 1)

                sstore(sc, add(sload(sc), and(mload(mc), mask)))

                for {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }

                mask := exp(0x100, sub(mc, end))

                sstore(sc, mul(div(mload(mc), mask), mask))
            }
        }
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    )
        internal
        pure
        returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_bytes.length >= _start + 20, "toAddress_outOfBounds");
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
        require(_bytes.length >= _start + 1 , "toUint8_outOfBounds");
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    function toUint16(bytes memory _bytes, uint256 _start) internal pure returns (uint16) {
        require(_bytes.length >= _start + 2, "toUint16_outOfBounds");
        uint16 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }

        return tempUint;
    }

    function toUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32) {
        require(_bytes.length >= _start + 4, "toUint32_outOfBounds");
        uint32 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x4), _start))
        }

        return tempUint;
    }

    function toUint64(bytes memory _bytes, uint256 _start) internal pure returns (uint64) {
        require(_bytes.length >= _start + 8, "toUint64_outOfBounds");
        uint64 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x8), _start))
        }

        return tempUint;
    }

    function toUint96(bytes memory _bytes, uint256 _start) internal pure returns (uint96) {
        require(_bytes.length >= _start + 12, "toUint96_outOfBounds");
        uint96 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0xc), _start))
        }

        return tempUint;
    }

    function toUint128(bytes memory _bytes, uint256 _start) internal pure returns (uint128) {
        require(_bytes.length >= _start + 16, "toUint128_outOfBounds");
        uint128 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x10), _start))
        }

        return tempUint;
    }

    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        require(_bytes.length >= _start + 32, "toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function toBytes32(bytes memory _bytes, uint256 _start) internal pure returns (bytes32) {
        require(_bytes.length >= _start + 32, "toBytes32_outOfBounds");
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }

    function equal(bytes memory _preBytes, bytes memory _postBytes) internal pure returns (bool) {
        bool success = true;

        assembly {
            let length := mload(_preBytes)

            // if lengths don't match the arrays are not equal
            switch eq(length, mload(_postBytes))
            case 1 {
                // cb is a circuit breaker in the for loop since there's
                //  no said feature for inline assembly loops
                // cb = 1 - don't breaker
                // cb = 0 - break
                let cb := 1

                let mc := add(_preBytes, 0x20)
                let end := add(mc, length)

                for {
                    let cc := add(_postBytes, 0x20)
                // the next line is the loop condition:
                // while(uint256(mc < end) + cb == 2)
                } eq(add(lt(mc, end), cb), 2) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // if any of these checks fails then arrays are not equal
                    if iszero(eq(mload(mc), mload(cc))) {
                        // unsuccess:
                        success := 0
                        cb := 0
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }

    function equalStorage(
        bytes storage _preBytes,
        bytes memory _postBytes
    )
        internal
        view
        returns (bool)
    {
        bool success = true;

        assembly {
            // we know _preBytes_offset is 0
            let fslot := sload(_preBytes.slot)
            // Decode the length of the stored array like in concatStorage().
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)

            // if lengths don't match the arrays are not equal
            switch eq(slength, mlength)
            case 1 {
                // slength can contain both the length and contents of the array
                // if length < 32 bytes so let's prepare for that
                // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
                if iszero(iszero(slength)) {
                    switch lt(slength, 32)
                    case 1 {
                        // blank the last byte which is the length
                        fslot := mul(div(fslot, 0x100), 0x100)

                        if iszero(eq(fslot, mload(add(_postBytes, 0x20)))) {
                            // unsuccess:
                            success := 0
                        }
                    }
                    default {
                        // cb is a circuit breaker in the for loop since there's
                        //  no said feature for inline assembly loops
                        // cb = 1 - don't breaker
                        // cb = 0 - break
                        let cb := 1

                        // get the keccak hash to get the contents of the array
                        mstore(0x0, _preBytes.slot)
                        let sc := keccak256(0x0, 0x20)

                        let mc := add(_postBytes, 0x20)
                        let end := add(mc, mlength)

                        // the next line is the loop condition:
                        // while(uint256(mc < end) + cb == 2)
                        for {} eq(add(lt(mc, end), cb), 2) {
                            sc := add(sc, 1)
                            mc := add(mc, 0x20)
                        } {
                            if iszero(eq(sload(sc), mload(mc))) {
                                // unsuccess:
                                success := 0
                                cb := 0
                            }
                        }
                    }
                }
            }
            default {
                // unsuccess:
                success := 0
            }
        }

        return success;
    }
}

// File: ethereum/contracts/icco/shared/ICCOStructs.sol

// contracts/Structs.sol


pragma solidity ^0.8.0;


library ICCOStructs {
    using BytesLib for bytes;

    struct Token {
        uint16 tokenChain;
        bytes32 tokenAddress;
        uint128 conversionRate;
    }

    struct SolanaToken {
        uint8 tokenIndex;
        bytes32 tokenAddress;
    }

    struct Contribution {
        /// index in acceptedTokens array
        uint8 tokenIndex;
        uint256 contributed;
    }

    struct Allocation {
        /// index in acceptedTokens array
        uint8 tokenIndex;
        /// amount of sold tokens allocated to contributors on this chain
        uint256 allocation;
        /// excess contributions refunded to contributors on this chain
        uint256 excessContribution;
    }

    struct Raise {
        /// fixed-price sale boolean
        bool isFixedPrice;
        /// isVesting Enabled
        bool isVested;
        /// sale token address
        bytes32 token;
        /// sale token chainId
        uint16 tokenChain;
        /// token amount being sold
        uint256 tokenAmount;
        /// min raise amount
        uint256 minRaise;
        /// max token amount
        uint256 maxRaise;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// unlock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;
        /// recipient of proceeds
        address recipient;
        /// refund recipient in case the sale is aborted
        address refundRecipient;
        /// public key of kyc authority 
        address authority; 
    }

    struct Vesting {
        /// vesting contract address
        bytes32 vestingContractAddress;
        /// vesting contract address wormhole chainId
        uint16 vestingContractChain;
    }

    struct SaleInit {
        /// payloadID uint8 = 1
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// address of the token - left-zero-padded if shorter than 32 bytes
        bytes32 tokenAddress;
        /// chain ID of the token
        uint16 tokenChain;
        /// token decimals 
        uint8 tokenDecimals;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// accepted Tokens
        Token[] acceptedTokens;
        /// recipient of proceeds
        bytes32 recipient;
        /// public key of kyc authority 
        address authority;
        /// unlock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;
        /// vesting status
        uint8 isVested;
        /// vesting details
        Vesting[] vestings;
    }

    struct SolanaSaleInit {
        /// payloadID uint8 = 5
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// address of the token - left-zero-padded if shorter than 32 bytes
        bytes32 tokenAddress;
        /// chain ID of the token
        uint16 tokenChain;
        /// token decimals 
        uint8 tokenDecimals;
        /// timestamp raise start
        uint256 saleStart;
        /// timestamp raise end
        uint256 saleEnd;
        /// accepted Tokens
        SolanaToken[] acceptedTokens;  
        /// recipient of proceeds
        bytes32 recipient;
        /// public key of kyc authority 
        address authority;
        /// unlock timestamp (when tokens can be claimed)
        uint256 unlockTimestamp;
        /// vesting status
        uint8 isVested;
        /// vesting details
        bytes32 vestingContractAddress;
    }

    struct ContributionsSealed {
        /// payloadID uint8 = 2
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// chain ID
        uint16 chainID;
        /// solana ATA (bytes32(0) from contributors that aren't on Solana)
        bytes32 solanaTokenAccount;
        /// sealed contributions for this sale
        Contribution[] contributions;
    }

    struct SaleSealed {
        /// payloadID uint8 = 3
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// allocations
        Allocation[] allocations;
    }

    struct SaleAborted {
        /// payloadID uint8 = 4
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
    }

    struct AuthorityUpdated {
        /// payloadID uint8 = 6
        uint8 payloadID;
        /// sale ID
        uint256 saleID;
        /// address of new authority
        address newAuthority; 
    }

    struct WormholeFees {
        /// wormhole messaging fees
        uint256 valueSent;
        uint256 messageFee;
        uint256 accumulatedFees;
        uint256 refundAmount;
        uint8 bridgeCount;
    }

    function normalizeAmount(uint256 amount, uint8 decimals) public pure returns(uint256){
        if (decimals > 8) {
            amount /= 10 ** (decimals - 8);
        }
        return amount;
    }

    function deNormalizeAmount(uint256 amount, uint8 decimals) public pure returns(uint256){
        if (decimals > 8) {
            amount *= 10 ** (decimals - 8);
        }
        return amount;
    }

    function encodeSaleInit(SaleInit memory saleInit) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(1),
            saleInit.saleID,
            saleInit.tokenAddress,
            saleInit.tokenChain,
            saleInit.tokenDecimals,
            saleInit.saleStart,
            saleInit.saleEnd,
            encodeTokens(saleInit.acceptedTokens),
            saleInit.recipient,
            saleInit.authority,
            saleInit.unlockTimestamp,
            saleInit.isVested,
            encodeVestings(saleInit.vestings)
        );
    }

    function encodeSolanaSaleInit(SolanaSaleInit memory solanaSaleInit) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(5),
            solanaSaleInit.saleID,
            solanaSaleInit.tokenAddress,
            solanaSaleInit.tokenChain,
            solanaSaleInit.tokenDecimals,
            solanaSaleInit.saleStart,
            solanaSaleInit.saleEnd,
            encodeSolanaTokens(solanaSaleInit.acceptedTokens),
            solanaSaleInit.recipient,
            solanaSaleInit.authority,
            solanaSaleInit.unlockTimestamp,
            solanaSaleInit.isVested,
            solanaSaleInit.vestingContractAddress
        );
    }

    function parseSaleInit(bytes memory encoded) public pure returns (SaleInit memory saleInit) {
        uint256 index = 0;

        saleInit.payloadID = encoded.toUint8(index);
        index += 1;

        require(saleInit.payloadID == 1, "invalid payloadID");

        saleInit.saleID = encoded.toUint256(index);
        index += 32;

        saleInit.tokenAddress = encoded.toBytes32(index);
        index += 32;

        saleInit.tokenChain = encoded.toUint16(index);
        index += 2;

        saleInit.tokenDecimals = encoded.toUint8(index);
        index += 1;

        saleInit.saleStart = encoded.toUint256(index);
        index += 32;

        saleInit.saleEnd = encoded.toUint256(index);
        index += 32;

        uint256 len = 1 + 50 * uint256(uint8(encoded[index]));
        saleInit.acceptedTokens = parseTokens(encoded.slice(index, len));
        index += len;

        saleInit.recipient = encoded.toBytes32(index);
        index += 32;

        saleInit.authority = encoded.toAddress(index);
        index += 20;

        saleInit.unlockTimestamp = encoded.toUint256(index);
        index += 32;

        saleInit.isVested = encoded.toUint8(index);
        index += 1;

        uint256 len2 = 1 + 34 * uint256(uint8(encoded[index]));
        saleInit.vestings = parseVestings(encoded.slice(index, len2));
        index += len2;

        require(encoded.length == index, "invalid SaleInit");
    }

    function encodeVestings(Vesting[] memory vestings) public pure returns(bytes memory encoded){
        uint256 vestingsLength = vestings.length;
        encoded = abi.encodePacked(uint8(vestingsLength));

        for (uint256 i = 0; i < vestingsLength;) {
            encoded = abi.encodePacked(
                encoded,
                vestings[i].vestingContractAddress,
                vestings[i].vestingContractChain
            );
            unchecked { i += 1; }
        } 
    }

    function encodeTokens(Token[] memory tokens) public pure returns (bytes memory encoded) {
        uint256 tokensLength = tokens.length;
        encoded = abi.encodePacked(uint8(tokensLength));

        for (uint256 i = 0; i < tokensLength;) {
            encoded = abi.encodePacked(
                encoded,
                tokens[i].tokenAddress,
                tokens[i].tokenChain,
                tokens[i].conversionRate
            );
            unchecked { i += 1; }
        }
    }

    function encodeSolanaTokens(SolanaToken[] memory tokens) public pure returns (bytes memory encoded) {
        uint256 tokensLength = tokens.length;
        encoded = abi.encodePacked(uint8(tokensLength));

        for (uint256 i = 0; i < tokensLength;) {
            encoded = abi.encodePacked(
                encoded,
                tokens[i].tokenIndex,
                tokens[i].tokenAddress
            );
            unchecked { i += 1; }
        }
    }

    function parseTokens(bytes memory encoded) public pure returns (Token[] memory tokens) {
        require(encoded.length % 50 == 1, "invalid Token[]");

        uint8 len = uint8(encoded[0]);

        tokens = new Token[](len);

        for (uint256 i = 0; i < len;) {
            tokens[i].tokenAddress   = encoded.toBytes32( 1 + i * 50);
            tokens[i].tokenChain     = encoded.toUint16( 33 + i * 50);
            tokens[i].conversionRate = encoded.toUint128(35 + i * 50);
            unchecked { i += 1; }
        }
    }

    function parseVestings(bytes memory encoded) public pure returns(Vesting[] memory vestings) {
        require(encoded.length % 34 == 1, "invalid Vesting[]");

        uint8 len = uint8(encoded[0]);

        vestings = new Vesting[](len);

        for (uint256 i = 0; i < len;) {
            vestings[i].vestingContractAddress   = encoded.toBytes32( 1 + i * 34);
            vestings[i].vestingContractChain  = encoded.toUint16( 33 + i * 34);
            unchecked { i += 1; }
        }
    }

    function encodeContributionsSealed(ContributionsSealed memory cs) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(2),
            cs.saleID,
            cs.chainID,
            cs.solanaTokenAccount,
            encodeContributions(cs.contributions)
        );
    }

    function parseContributionsSealed(bytes memory encoded) public pure returns (ContributionsSealed memory consSealed) {
        uint256 index = 0;

        consSealed.payloadID = encoded.toUint8(index);
        index += 1;

        require(consSealed.payloadID == 2, "invalid payloadID");

        consSealed.saleID = encoded.toUint256(index);
        index += 32;

        consSealed.chainID = encoded.toUint16(index);
        index += 2;

        consSealed.solanaTokenAccount = encoded.toBytes32(index);
        index += 32;

        uint256 len = 1 + 33 * uint256(uint8(encoded[index]));
        consSealed.contributions = parseContributions(encoded.slice(index, len));
        index += len;

        require(encoded.length == index, "invalid ContributionsSealed");
    }

    function encodeContributions(Contribution[] memory contributions) public pure returns (bytes memory encoded) {
        uint256 contributionsLength = contributions.length;
        encoded = abi.encodePacked(uint8(contributionsLength));

        for (uint256 i = 0; i < contributionsLength;) {
            encoded = abi.encodePacked(
                encoded,
                contributions[i].tokenIndex,
                contributions[i].contributed
            );
            unchecked { i += 1; }
        }
    }

    function parseContributions(bytes memory encoded) public pure returns (Contribution[] memory cons) {
        require(encoded.length % 33 == 1, "invalid Contribution[]");

        uint8 len = uint8(encoded[0]);

        cons = new Contribution[](len);

        for (uint256 i = 0; i < len;) {
            cons[i].tokenIndex  = encoded.toUint8(1 + i * 33);
            cons[i].contributed = encoded.toUint256(2 + i * 33);
            unchecked { i += 1; }
        }
    }

    function encodeSaleSealed(SaleSealed memory ss) public pure returns (bytes memory encoded) {
        return abi.encodePacked(
            uint8(3),
            ss.saleID,
            encodeAllocations(ss.allocations)
        );
    }

    function parseSaleSealed(bytes memory encoded) public pure returns (SaleSealed memory ss) {
        uint256 index = 0;
        ss.payloadID = encoded.toUint8(index);
        index += 1;

        require(ss.payloadID == 3, "invalid payloadID");

        ss.saleID = encoded.toUint256(index);
        index += 32;

        uint256 len = 1 + 65 * uint256(uint8(encoded[index]));
        ss.allocations = parseAllocations(encoded.slice(index, len));
        index += len;

        require(encoded.length == index, "invalid SaleSealed");
    }

    function encodeAllocations(Allocation[] memory allocations) public pure returns (bytes memory encoded) {
        uint256 allocationsLength = allocations.length;
        encoded = abi.encodePacked(uint8(allocationsLength));

        for (uint256 i = 0; i < allocationsLength;) {
            encoded = abi.encodePacked(
                encoded,
                allocations[i].tokenIndex,
                allocations[i].allocation,
                allocations[i].excessContribution
            );
            unchecked { i += 1; }
        }
    }

    function parseAllocations(bytes memory encoded) public pure returns (Allocation[] memory allos) {
        require(encoded.length % 65 == 1, "invalid Allocation[]");

        uint8 len = uint8(encoded[0]);

        allos = new Allocation[](len);

        for (uint256 i = 0; i < len;) {
            allos[i].tokenIndex = encoded.toUint8(1 + i * 65);
            allos[i].allocation = encoded.toUint256(2 + i * 65);
            allos[i].excessContribution = encoded.toUint256(34 + i * 65);
            unchecked { i += 1; }
        }
    }

    function encodeSaleAborted(SaleAborted memory ca) public pure returns (bytes memory encoded) {
        return abi.encodePacked(uint8(4), ca.saleID);
    } 

    function parseSaleAborted(bytes memory encoded) public pure returns (SaleAborted memory sa) {
        uint256 index = 0;
        sa.payloadID = encoded.toUint8(index);
        index += 1;

        require(sa.payloadID == 4, "invalid payloadID");

        sa.saleID = encoded.toUint256(index);
        index += 32;

        require(encoded.length == index, "invalid SaleAborted");
    }

     function encodeAuthorityUpdated(AuthorityUpdated memory update) public pure returns (bytes memory encoded) {
        return abi.encodePacked(uint8(6), update.saleID, update.newAuthority);
    }

    function parseAuthorityUpdated(bytes memory encoded) public pure returns (AuthorityUpdated memory update) {
        uint256 index = 0;
        update.payloadID = encoded.toUint8(index);
        index += 1;

        require(update.payloadID == 6, "invalid payloadID");

        update.saleID = encoded.toUint256(index);
        index += 32;

        update.newAuthority = encoded.toAddress(index);
        index += 20; 

        require(encoded.length == index, "invalid AuthorityUpdated");
    }

    /// @dev duplicate method from Contributor.sol 
    function verifySignature(bytes memory encodedHashData, bytes memory sig, address authority) public pure returns (bool) {
        require(sig.length == 65, "incorrect signature length"); 
        require(encodedHashData.length > 0, "no hash data");

        /// compute hash from encoded data
        bytes32 hash_ = keccak256(encodedHashData);  
        
        /// parse v, r, s
        uint8 index = 0;

        bytes32 r = sig.toBytes32(index);
        index += 32;

        bytes32 s = sig.toBytes32(index);
        index += 32;

        uint8 v = sig.toUint8(index) + 27;

        /// recovered key
        address key = ecrecover(hash_, v, r, s);

        /// confirm that the recovered key is the authority
        if (key == authority) {
            return true;
        } else {
            return false;
        }
    }
}
// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: ethereum/contracts/icco/contributor/ContributorGetters.sol

// contracts/Getters.sol


pragma solidity ^0.8.0;





contract ContributorGetters is ContributorState {
    function owner() public view returns (address) {
        return _state.owner;
    }

    function pendingOwner() public view returns (address) {
        return _state.pendingOwner;
    }

    function authority(uint256 saleId_) public view returns (address) {
        return _state.sales[saleId_].authority;
    }

    function isInitialized(address impl) public view returns (bool) {
        return _state.initializedImplementations[impl];
    }

    function wormhole() public view returns (IWormhole) {
        return IWormhole(_state.provider.wormhole);
    }

    function tokenBridge() public view returns (ITokenBridge) {
        return ITokenBridge(payable(_state.provider.tokenBridge));
    }

    function consistencyLevel() public view returns (uint8) {
        return _state.consistencyLevel;
    }

    function chainId() public view returns (uint16){
        return _state.provider.chainId;
    }

    function conductorChainId() public view returns (uint16){
        return _state.provider.conductorChainId;
    }

    function conductorContract() public view returns (bytes32){
        return _state.provider.conductorContract;
    }

    function sales(uint256 saleId_) public view returns (ContributorStructs.Sale memory sale){
        return _state.sales[saleId_];
    }

    function getSaleAcceptedTokenInfo(uint256 saleId_, uint256 tokenIndex) public view returns (uint16 tokenChainId, bytes32 tokenAddress, uint128 conversionRate){
        return (
            _state.sales[saleId_].acceptedTokensChains[tokenIndex],
            _state.sales[saleId_].acceptedTokensAddresses[tokenIndex],
            _state.sales[saleId_].acceptedTokensConversionRates[tokenIndex]
        );
    }

    function getSaleTimeframe(uint256 saleId_) public view returns (uint256 start, uint256 end, uint256 unlockTimestamp){
        return (
            _state.sales[saleId_].saleStart,
            _state.sales[saleId_].saleEnd,
            _state.sales[saleId_].unlockTimestamp
        );
    }

    function getSaleStatus(uint256 saleId_) public view returns (bool isSealed, bool isAborted){
        return (
            _state.sales[saleId_].isSealed,
            _state.sales[saleId_].isAborted
        );
    }

    function getSaleTokenAddress(uint256 saleId_) public view returns (bytes32 tokenAddress){
        tokenAddress = _state.sales[saleId_].tokenAddress;
    }

    function getSaleAllocation(uint256 saleId, uint256 tokenIndex) public view returns (uint256 allocation){
        return _state.sales[saleId].allocations[tokenIndex];
    }

    function getSaleExcessContribution(uint256 saleId, uint256 tokenIndex) public view returns (uint256 allocation){
        return _state.sales[saleId].excessContributions[tokenIndex];
    }

    function getSaleTotalContribution(uint256 saleId, uint256 tokenIndex) public view returns (uint256 contributed){
        return _state.totalContributions[saleId][tokenIndex];
    }

    function getSaleContribution(uint256 saleId, uint256 tokenIndex, address contributor) public view returns (uint256 contributed){
        return _state.contributions[saleId][tokenIndex][contributor];
    }

    function refundIsClaimed(uint256 saleId, uint256 tokenIndex, address contributor) public view returns (bool){
        return _state.refundIsClaimed[saleId][tokenIndex][contributor];
    }

    function allocationIsClaimed(uint256 saleId, uint256 tokenIndex, address contributor) public view returns (bool){
        return _state.allocationIsClaimed[saleId][tokenIndex][contributor];
    }

    function excessContributionIsClaimed(uint256 saleId, uint256 tokenIndex, address contributor) public view returns (bool){
        return _state.excessContributionIsClaimed[saleId][tokenIndex][contributor];
    }

    function isTokenDisabled(uint256 saleId, uint256 tokenIndex) public view returns (bool) {
        return _state.sales[saleId].disabledAcceptedTokens[tokenIndex];
    }

    function getVestingContracts(uint256 saleId, uint16 chainId) public view returns (bytes32) {
        return _state.vestingContracts[saleId][chainId];
    }

    function isSaleVested(uint256 saleId) public view returns (bool) {
        return _state.sales[saleId].isVested;
    }
} 
// File: @openzeppelin/contracts/utils/StorageSlot.sol


// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
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
        IERC20 token,
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
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
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

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: @openzeppelin/contracts/interfaces/draft-IERC1822.sol


// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// File: @openzeppelin/contracts/proxy/beacon/IBeacon.sol


// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// File: @openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol


// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;





/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// File: ethereum/contracts/icco/contributor/ContributorGovernance.sol

// contracts/Contributor.sol


pragma solidity ^0.8.0;









contract ContributorGovernance is ContributorGetters, ContributorSetters, ERC1967Upgrade {
    event ContractUpgraded(address indexed oldContract, address indexed newContract);
    event ConsistencyLevelUpdated(uint8 indexed oldLevel, uint8 indexed newLevel);
    event OwnershipTransfered(address indexed oldOwner, address indexed newOwner);


    /// @dev upgrade serves to upgrade contract implementations 
    function upgrade(uint16 contributorChainId, address newImplementation) public onlyOwner {
        require(contributorChainId == chainId(), "wrong chain id");

        address currentImplementation = _getImplementation();

        _upgradeTo(newImplementation);

        /// call initialize function of the new implementation
        (bool success, bytes memory reason) = newImplementation.delegatecall(abi.encodeWithSignature("initialize()"));

        require(success, string(reason));

        emit ContractUpgraded(currentImplementation, newImplementation);
    } 

    /// @dev updateConsisencyLevel serves to change the wormhole messaging consistencyLevel
    function updateConsistencyLevel(uint16 contributorChainId, uint8 newConsistencyLevel) public onlyOwner {
        require(contributorChainId == chainId(), "wrong chain id");
        require(newConsistencyLevel > 0, "newConsistencyLevel must be > 0");

        uint8 currentConsistencyLevel = consistencyLevel();

        setConsistencyLevel(newConsistencyLevel);    

        emit ConsistencyLevelUpdated(currentConsistencyLevel, newConsistencyLevel);
    } 

    /**
     * @dev submitOwnershipTransferRequest serves to begin the ownership transfer process of the contracts
     * - it saves an address for the new owner in the pending state
     */
    function submitOwnershipTransferRequest(uint16 contributorChainId, address newOwner) public onlyOwner {
        require(contributorChainId == chainId(), "wrong chain id"); 
        require(newOwner != address(0), "new owner cannot be the zero address");

        setPendingOwner(newOwner); 
    }

    /**
     * @dev confirmOwnershipTransferRequest serves to finalize an ownership transfer
     * - it checks that the caller is the pendingOwner to validate the wallet address
     * - it updates the owner state variable with the pendingOwner state variable
     */
    function confirmOwnershipTransferRequest() public {
        /// cache the new owner address
        address newOwner = pendingOwner();

        require(msg.sender == newOwner, "caller must be pendingOwner");

        /// cache currentOwner for Event
        address currentOwner = owner();

        /// @dev update the owner in the contract state and reset the pending owner
        setOwner(newOwner);
        setPendingOwner(address(0));

        emit OwnershipTransfered(currentOwner, newOwner); 
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "caller is not the owner");
        _;
    }
}

// File: ethereum/contracts/icco/contributor/Contributor.sol

// contracts/Contributor.sol


pragma solidity ^0.8.0;











/** 
 * @title A cross-chain token sale contributor
 * @notice This contract is in charge of collecting contributions from 
 * individual contributors who wish to participate in a cross-chain 
 * token sale. It acts as a custodian for the contributed funds and 
 * uses the wormhole token bridge to send contributed funds in exchange
 * for the token being sold. It uses the wormhole core messaging layer
 * to disseminate information about the collected contributions to the
 * Conductor contract.
 */ 
contract Contributor is ContributorGovernance, ContributorEvents, ReentrancyGuard {
    using BytesLib for bytes;

    /**
     * @dev initSale serves to initialize a cross-chain token sale, by consuming 
     * information from the Conductor contract regarding the sale.
     * - it validates messages sent via wormhole containing sale information
     * - it saves a copy of the sale in contract storage
     */
    function initSale(bytes memory saleInitVaa) public {
        /// @dev confirms that the message is from the Conductor and valid
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(saleInitVaa);

        require(valid, reason);
        require(verifyConductorVM(vm), "invalid emitter");

        /// parse the sale information sent by the Conductor contract
        ICCOStructs.SaleInit memory saleInit = ICCOStructs.parseSaleInit(vm.payload);
        require(!saleExists(saleInit.saleID), "sale already initiated");

        /// @dev cache to save on gas
        uint256 acceptedTokensLength = saleInit.acceptedTokens.length;

        /// save the parsed sale information 
        ContributorStructs.Sale memory sale = ContributorStructs.Sale({
            saleID : saleInit.saleID,
            tokenAddress : saleInit.tokenAddress,
            tokenChain : saleInit.tokenChain,
            tokenDecimals: saleInit.tokenDecimals,
            saleStart : saleInit.saleStart,
            saleEnd : saleInit.saleEnd,
            unlockTimestamp : saleInit.unlockTimestamp,
            acceptedTokensChains : new uint16[](acceptedTokensLength),
            acceptedTokensAddresses : new bytes32[](acceptedTokensLength),
            acceptedTokensConversionRates : new uint128[](acceptedTokensLength),
            disabledAcceptedTokens: new bool[](acceptedTokensLength),
            recipient : saleInit.recipient,
            authority : saleInit.authority,
            isSealed : false,
            isAborted : false,
            allocations : new uint256[](acceptedTokensLength),
            excessContributions : new uint256[](acceptedTokensLength),
            isVested: (saleInit.isVested == uint8(0)) ? false : true
        });

        /// make sure the VAA is for an active sale
        require(saleInit.saleEnd >= block.timestamp, "sale has already ended");

        /**
         * @dev This saves accepted token info for only the relevant tokens
         * on this Contributor chain.
         * - it checks that the token is a valid ERC20 token
         */  
        for (uint256 i = 0; i < acceptedTokensLength;) {
            if (saleInit.acceptedTokens[i].tokenChain == chainId()) {
                address tokenAddress = address(uint160(uint256(saleInit.acceptedTokens[i].tokenAddress)));
                (, bytes memory queriedTotalSupply) = tokenAddress.staticcall(
                    abi.encodeWithSelector(IERC20.totalSupply.selector)
                );
                /// @dev mark the accepted token as disabled if it's not a real erc20
                if (queriedTotalSupply.length == 0) {
                    sale.disabledAcceptedTokens[i] = true;
                }
            }
            sale.acceptedTokensChains[i] = saleInit.acceptedTokens[i].tokenChain;
            sale.acceptedTokensAddresses[i] = saleInit.acceptedTokens[i].tokenAddress;
            sale.acceptedTokensConversionRates[i] = saleInit.acceptedTokens[i].conversionRate;
            unchecked { i += 1; }
        }

        
        if(sale.isVested){ // if sale is vested then perform vesting operations
            /// save vestings in storage
            for (uint256 i = 0; i < saleInit.vestings.length; ) {
                setVestingContract(saleInit.saleID, saleInit.vestings[i].vestingContractChain, saleInit.vestings[i].vestingContractAddress);
                unchecked { i += 1; }
            }
            // setting sale id in vesting contract for the specific chain (wormhole chainID)
            IVesting(address(uint160(uint256(getVestingContracts(saleInit.saleID, chainId()))))).setSaleId(saleInit.saleID);
        }

        /// save the sale in contract storage
        setSale(saleInit.saleID, sale);

        /// emit EventContribute event.
        emit EventSaleInit(saleInit.saleID);
    }

    /**
     * @dev verifySignature serves to verify a contribution signature for KYC purposes.
     * - it computes the keccak256 hash of data passed by the client
     * - it recovers the KYC authority key from the hashed data and signature
     * - it saves gas by not caling the verifySignature method in ICCOStructs.sol
     */ 
    function verifySignature(bytes memory encodedHashData, bytes memory sig, address authority) internal pure returns (bool) {
        require(sig.length == 65, "incorrect signature length"); 
        require(encodedHashData.length > 0, "no hash data");

        /// compute hash from encoded data
        bytes32 hash_ = keccak256(encodedHashData); 
        
        /// parse v, r, s
        uint8 index = 0;

        bytes32 r = sig.toBytes32(index);
        index += 32;

        bytes32 s = sig.toBytes32(index);
        index += 32;

        uint8 v = sig.toUint8(index) + 27;

        /// recovered key
        address key = ecrecover(hash_, v, r, s);

        /// confirm that the recovered key is the authority
        if (key == authority) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev contribute serves to allow users to contribute funds and
     * participate in the token sale.
     * - it confirms that the wallet is authorized to contribute
     * - it takes custody of contributed funds
     * - it stores information about the contribution and contributor 
     */  
    function contribute(uint256 saleId, uint256 tokenIndex, uint256 amount, bytes memory sig) public nonReentrant { 
        require(saleExists(saleId), "sale not initiated");

        {/// bypass stack too deep
            /// confirm contributions can be accepted at this time
            (, bool isAborted) = getSaleStatus(saleId);

            require(!isAborted, "sale was aborted");

            (uint256 start, uint256 end, ) = getSaleTimeframe(saleId);

            require(block.timestamp >= start, "sale not yet started");
            require(block.timestamp <= end, "sale has ended"); 
        }

        /// @dev make sure the token is enabled (still accepted by the sale)
        require(!isTokenDisabled(saleId, tokenIndex), "token is disabled");

        /// query information for the passed tokendIndex
        (uint16 tokenChain, bytes32 tokenAddressBytes,) = getSaleAcceptedTokenInfo(saleId, tokenIndex);

        require(tokenChain == chainId(), "this token can not be contributed on this chain");   
 
        {///bypass stack too deep
            /// @dev verify authority has signed contribution 
            bytes memory encodedHashData = abi.encodePacked(
                conductorContract(), 
                saleId, 
                tokenIndex, 
                amount, 
                bytes12(0x0),
                msg.sender, 
                getSaleContribution(saleId, tokenIndex, msg.sender)
            ); 
            require(verifySignature(encodedHashData, sig, authority(saleId)), "unauthorized contributor");
        }

        /// query own token balance before transfer
        address tokenAddress = address(uint160(uint256(tokenAddressBytes)));

        (, bytes memory queriedBalanceBefore) = tokenAddress.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        uint256 balanceBefore = abi.decode(queriedBalanceBefore, (uint256));

        /// deposit tokens
        SafeERC20.safeTransferFrom(
            IERC20(tokenAddress), 
            msg.sender, 
            address(this), 
            amount
        );

        /// query own token balance after transfer
        (, bytes memory queriedBalanceAfter) = tokenAddress.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        uint256 balanceAfter = abi.decode(queriedBalanceAfter, (uint256));

        /// revert if token has fee
        require(amount == balanceAfter - balanceBefore, "fee-on-transfer tokens are not supported");

        /// @dev store contribution information
        setSaleContribution(saleId, msg.sender, tokenIndex, amount);

        /// emit EventContribute event.
        emit EventContribute(saleId, tokenIndex, amount);
    }

    /**
     * @dev attestContributions serves to disseminate contribution information
     * to the Conductor contract once the sale has ended.
     * - it calculates the total contributions for each accepted token
     * - it disseminates a ContributionSealed struct via wormhole
     */ 
    function attestContributions(uint256 saleId) public payable returns (uint256 wormholeSequence) {
        require(saleExists(saleId), "sale not initiated");

        /// confirm that the sale period has ended
        ContributorStructs.Sale memory sale = sales(saleId);

        require(!sale.isSealed && !sale.isAborted, "already sealed / aborted");
        require(block.timestamp > sale.saleEnd, "sale has not yet ended");

        IWormhole wormhole = wormhole();
        uint256 messageFee = wormhole.messageFee();

        require(msg.value == messageFee, "incorrect value");

        /// count accepted tokens for this contract to allocate memory in ContributionsSealed struct 
        uint256 nativeTokens = 0;
        uint16 chainId = chainId(); /// cache from storage
        uint256 acceptedTokensLength = sale.acceptedTokensAddresses.length; /// cache to save on gas
        for (uint256 i = 0; i < acceptedTokensLength;) {
            if (sale.acceptedTokensChains[i] == chainId) {
                nativeTokens++;
            }
            unchecked { i += 1; }
        }

        /// declare ContributionsSealed struct and add contribution info
        ICCOStructs.ContributionsSealed memory consSealed = ICCOStructs.ContributionsSealed({
            payloadID : 2,
            saleID : saleId,
            chainID : uint16(chainId),
            solanaTokenAccount : bytes32(0),
            contributions : new ICCOStructs.Contribution[](nativeTokens)
        });

        uint256 ci = 0;
        for (uint256 i = 0; i < acceptedTokensLength;) {
            if (sale.acceptedTokensChains[i] == chainId) {
                consSealed.contributions[ci].tokenIndex = uint8(i);
                consSealed.contributions[ci].contributed = getSaleTotalContribution(saleId, i);
                ci++;
            }
            unchecked { i += 1; }
        }

        /// @dev send encoded ContributionsSealed message to Conductor contract
        wormholeSequence = wormhole.publishMessage{
            value : messageFee
        }(0, ICCOStructs.encodeContributionsSealed(consSealed), consistencyLevel());

        /// emit EventAttestContribution event.
        emit EventAttestContribution(saleId);
    }

    /**
     * @dev saleSealed serves to send contributed funds to the saleRecipient.
     * - it parses the SaleSealed message sent from the Conductor contract
     * - it determines if all the sale tokens are in custody of this contract
     * - it send the contributed funds to the token sale recipient
     */
    function saleSealed(bytes memory saleSealedVaa) public payable nonReentrant {
        /// @dev confirms that the message is from the Conductor and valid
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(saleSealedVaa);

        require(valid, reason);
        require(verifyConductorVM(vm), "invalid emitter");

        /// parses the SaleSealed message sent by the Conductor
        ICCOStructs.SaleSealed memory sealedSale = ICCOStructs.parseSaleSealed(vm.payload); 
        
        ContributorStructs.Sale memory sale = sales(sealedSale.saleID);

        /// set up struct used for wormhole message accounting
        ICCOStructs.WormholeFees memory feeAccounting;
        feeAccounting.messageFee = wormhole().messageFee();
        feeAccounting.valueSent = msg.value;

        /// check to see if the sale was aborted already
        require(!sale.isSealed && !sale.isAborted, "already sealed / aborted");

        /// confirm that the allocated sale tokens are in custody of this contract
        /// cache variables to save on gas
        uint16 thisChainId = chainId(); 
        ITokenBridge tknBridge = tokenBridge();
        {
            address saleTokenAddress;
            if (sale.tokenChain == thisChainId) {
                /// normal token transfer on same chain
                saleTokenAddress = address(uint160(uint256(sale.tokenAddress)));
            } else {
                /// identify wormhole token bridge wrapper
                saleTokenAddress = tknBridge.wrappedAsset(sale.tokenChain, sale.tokenAddress);
                require(saleTokenAddress != address(0), "sale token is not attested");
            }

            uint256 tokenBalance;
            if(sale.isVested){
                (, bytes memory queriedTokenBalance) = saleTokenAddress.staticcall(
                    abi.encodeWithSelector(IERC20.balanceOf.selector, address(uint160(uint256(getVestingContracts(sale.saleID, chainId())))))
                );
                tokenBalance = abi.decode(queriedTokenBalance, (uint256));                
            }
            else{
                (, bytes memory queriedTokenBalance) = saleTokenAddress.staticcall(
                    abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
                );
                tokenBalance = abi.decode(queriedTokenBalance, (uint256));
            }

            require(tokenBalance > 0, "sale token balance must be non-zero");

            /// store the allocated token amounts defined in the SaleSealed message
            uint256 tokenAllocation;
            uint256 allocationsLength = sealedSale.allocations.length;
            for (uint256 i = 0; i < allocationsLength;) {
                ICCOStructs.Allocation memory allo = sealedSale.allocations[i];
                if (sale.acceptedTokensChains[allo.tokenIndex] == thisChainId) {
                    tokenAllocation += allo.allocation;
                    /// set the allocation for this token
                    setSaleAllocation(sealedSale.saleID, allo.tokenIndex, allo.allocation);
                    /// set the excessContribution for this token
                    setExcessContribution(sealedSale.saleID, allo.tokenIndex, allo.excessContribution);
                }

                /// @dev count how many token bridge transfer will occur in sealSale
                if (sale.acceptedTokensChains[i] != thisChainId) {
                    feeAccounting.bridgeCount += 1;
                }
                unchecked { i += 1; }
            }
 
            require(tokenBalance >= tokenAllocation, "insufficient sale token balance");
            setSaleSealed(sealedSale.saleID);

            /// @dev msg.value must cover all token bridge transfer fees (when bridgeCount is 0, no fees are charged in this method)
            require(feeAccounting.valueSent >= feeAccounting.messageFee * feeAccounting.bridgeCount, "insufficient value");
        }
        
        /**
         * @dev Cache the conductorChainId from storage to save on gas.
         * We will check each acceptedToken to see if it's from this chain.
         */ 
        uint16 conductorChainId = conductorChainId();
        uint256 acceptedTokensLength = sale.acceptedTokensAddresses.length;
        for (uint256 i = 0; i < acceptedTokensLength;) {
            if (sale.acceptedTokensChains[i] == thisChainId) {
                /// compute the total contributions to send to the recipient
                uint256 totalContributionsLessExcess = getSaleTotalContribution(sale.saleID, i) - getSaleExcessContribution(sale.saleID, i); 

                /// make sure we have contributions to send to the recipient for this accepted token
                if (totalContributionsLessExcess > 0) {
                    /// convert bytes32 address to evm address
                    address acceptedTokenAddress = address(uint160(uint256(sale.acceptedTokensAddresses[i]))); 

                    /// check to see if this contributor is on the same chain as conductor
                    if (thisChainId == conductorChainId) {
                        /// send contributions to recipient on this chain
                        SafeERC20.safeTransfer(
                            IERC20(acceptedTokenAddress),
                            address(uint160(uint256(sale.recipient))),
                            totalContributionsLessExcess
                        );
                    } else { 
                        /// get token decimals for normalization of token amount
                        uint8 acceptedTokenDecimals;
                        {/// bypass stack too deep
                            (,bytes memory queriedDecimals) = acceptedTokenAddress.staticcall(
                                abi.encodeWithSignature("decimals()")
                            );
                            acceptedTokenDecimals = abi.decode(queriedDecimals, (uint8));
                        }

                        /// perform dust accounting for tokenBridge
                        totalContributionsLessExcess = ICCOStructs.deNormalizeAmount(
                            ICCOStructs.normalizeAmount(
                                totalContributionsLessExcess,
                                acceptedTokenDecimals
                            ),
                            acceptedTokenDecimals
                        );

                        /// transfer over wormhole token bridge
                        SafeERC20.safeApprove(
                            IERC20(acceptedTokenAddress), 
                            address(tknBridge), 
                            totalContributionsLessExcess
                        );

                        tknBridge.transferTokens{
                            value : feeAccounting.messageFee
                        }(
                            acceptedTokenAddress,
                            totalContributionsLessExcess,
                            conductorChainId,
                            sale.recipient,
                            0,
                            0
                        );

                        /// uptick fee counter
                        feeAccounting.accumulatedFees += feeAccounting.messageFee;
                    }
                }
            }
            unchecked { i += 1; }
        } 

        /// @dev refund the caller any extra wormhole fees
        feeAccounting.refundAmount = feeAccounting.valueSent - feeAccounting.accumulatedFees;  
        if (feeAccounting.refundAmount > 0) payable(msg.sender).transfer(feeAccounting.refundAmount);

        /// emit EventSealSale event.
        emit EventSaleSealed(sale.saleID);
    }

    /// @dev saleAborted serves to mark the sale unnsuccessful or canceled 
    function saleAborted(bytes memory saleAbortedVaa) public {
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(saleAbortedVaa);

        require(valid, reason);
        require(verifyConductorVM(vm), "invalid emitter");

        ICCOStructs.SaleAborted memory abortedSale = ICCOStructs.parseSaleAborted(vm.payload);

        require(saleExists(abortedSale.saleID), "sale not initiated");

        /// set the sale aborted
        setSaleAborted(abortedSale.saleID);
    }

    /**
     * @dev claimAllocation serves to send contributors a preallocated amount of sale tokens.
     * - it confirms that the sale was sealed
     * - it transfers sale tokens to the contributor's wallet
     * - it marks the allocation as claimed to prevent multiple claims for the same allocation
     * - it only distributes tokens once the unlock period has ended
     */
    function claimAllocation(uint256 saleId, uint256 tokenIndex) public nonReentrant {

        if(sales(saleId).isVested){
            revert("Vested Sale can only be claimed using the vesting contracts");
        }

        require(saleExists(saleId), "sale not initiated");

        /// make sure the sale is sealed and not aborted
        (bool isSealed, bool isAborted) = getSaleStatus(saleId);
        (, , uint256 unlockTimestamp) = getSaleTimeframe(saleId);

        require(!isAborted, "token sale is aborted");
        require(isSealed, "token sale is not yet sealed");
        require(!allocationIsClaimed(saleId, tokenIndex, msg.sender), "allocation already claimed"); 

        /// @dev contributors can only claim after the unlock timestamp
        require(block.timestamp >= unlockTimestamp, "tokens have not been unlocked");

        /// cache to save on gas
        uint16 thisChainId = chainId();

        /// make sure the contributor is claiming on the right chain
        (uint16 contributedTokenChainId, , ) = getSaleAcceptedTokenInfo(saleId, tokenIndex);

        require(contributedTokenChainId == thisChainId, "allocation needs to be claimed on a different chain");

        /// set the allocation claimed - also serves as reentrancy protection
        setAllocationClaimed(saleId, tokenIndex, msg.sender);

        ContributorStructs.Sale memory sale = sales(saleId); 

        /**
         * @dev Cache contribution variables since they're used to calculate
         * the allocation and excess contribution.
         */
        uint256 thisContribution = getSaleContribution(saleId, tokenIndex, msg.sender);
        uint256 totalContribution = getSaleTotalContribution(saleId, tokenIndex);

        /// calculate the allocation and send to the contributor
        uint256 thisAllocation = (getSaleAllocation(saleId, tokenIndex) * thisContribution) / totalContribution;

        address tokenAddress;
        if (sale.tokenChain == thisChainId) {
            /// normal token transfer on same chain
            tokenAddress = address(uint160(uint256(sale.tokenAddress)));
        } else {
            /// identify wormhole token bridge wrapper
            tokenAddress = tokenBridge().wrappedAsset(sale.tokenChain, sale.tokenAddress);
        }
        SafeERC20.safeTransfer(IERC20(tokenAddress), msg.sender, thisAllocation); 

        /// emit EventClaimAllocation event.
        emit EventClaimAllocation(saleId, tokenIndex, thisAllocation);
    }

    /**
     * @dev claimExcessContribution serves to send contributors a refund for any excessContributions.
     * - it confirms that the sale was sealed
     * - it calculates the excessContribution owed to the contributor
     * - it marks the excessContribution as claimed to prevent multiple claims for the same refund
     * - it transfers the excessContribution to the contributor's wallet
     */
    function claimExcessContribution(uint256 saleId, uint256 tokenIndex) public nonReentrant {
        require(saleExists(saleId), "sale not initiated");

        /// return any excess contributions 
        uint256 excessContribution = getSaleExcessContribution(saleId, tokenIndex);

        require(excessContribution > 0, "no excess contributions for this token");

        (bool isSealed, ) = getSaleStatus(saleId);

        require(isSealed, "token sale is not sealed");
        require(!excessContributionIsClaimed(saleId, tokenIndex, msg.sender), "excess contribution already claimed");

        (uint16 tokenChainId,, ) = getSaleAcceptedTokenInfo(saleId, tokenIndex);

        require(tokenChainId == chainId(), "refund needs to be claimed on another chain");
 
        setExcessContributionClaimed(saleId, tokenIndex, msg.sender);

        /// calculate how much excess to refund
        uint256 thisExcessContribution = (excessContribution * getSaleContribution(saleId, tokenIndex, msg.sender)) / getSaleTotalContribution(saleId, tokenIndex);

        /// grab the contributed token address  
        (, bytes32 tokenAddressBytes, ) = getSaleAcceptedTokenInfo(saleId, tokenIndex);
        SafeERC20.safeTransfer(
            IERC20(address(uint160(uint256(tokenAddressBytes)))), 
            msg.sender, 
            thisExcessContribution
        );

        /// emit EventClaimExcessContribution event.
        emit EventClaimExcessContribution(saleId, tokenIndex, thisExcessContribution);
    }

    /**
     * @dev claimRefund serves to refund the contributor when a sale is unsuccessful. 
     * - it confirms that the sale was aborted
     * - it transfers the contributed funds back to the contributor's wallet
     */
    function claimRefund(uint256 saleId, uint256 tokenIndex) public nonReentrant {
        require(saleExists(saleId), "sale not initiated");

        (, bool isAborted) = getSaleStatus(saleId);

        require(isAborted, "token sale is not aborted");
        require(!refundIsClaimed(saleId, tokenIndex, msg.sender), "refund already claimed");

        setRefundClaimed(saleId, tokenIndex, msg.sender);

        (uint16 tokenChainId, bytes32 tokenAddressBytes, ) = getSaleAcceptedTokenInfo(saleId, tokenIndex);
        require(tokenChainId == chainId(), "refund needs to be claimed on another chain");

        address tokenAddress = address(uint160(uint256(tokenAddressBytes)));

        /// grab the amount to refund the user
        uint256 thisRefundContribution = getSaleContribution(saleId, tokenIndex, msg.sender);

        /// refund tokens
        SafeERC20.safeTransfer(
            IERC20(tokenAddress), 
            msg.sender, 
            thisRefundContribution
        );

        /// emit EventClaimRefund event.
        emit EventClaimRefund(saleId, tokenIndex, thisRefundContribution);
    }

    /// @dev saleAuthorityUpdated serves to consume an AuthorityUpdated VAA and change a sale's kyc authority
    function saleAuthorityUpdated(bytes memory authorityUpdatedVaa) public {
        /// @dev confirms that the message is from the Conductor and valid
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(authorityUpdatedVaa);

        require(valid, reason);
        require(verifyConductorVM(vm), "invalid emitter");

        /// parse the sale information sent by the Conductor contract
        ICCOStructs.AuthorityUpdated memory update = ICCOStructs.parseAuthorityUpdated(vm.payload);
        require(saleExists(update.saleID), "sale not initiated");

        /// @dev check if the VAA was consumed already
        require(update.newAuthority != authority(update.saleID), "newAuthority already set");

        /// @dev update sale state with the new authority public key
        setNewAuthority(update.saleID, update.newAuthority);
    }

    // @dev verifyConductorVM serves to validate VMs by checking against the known Conductor contract 
    function verifyConductorVM(IWormhole.VM memory vm) internal view returns (bool) {
        if (conductorContract() == vm.emitterAddress && conductorChainId() == vm.emitterChainId) {
            return true;
        }

        return false;
    }

    /// @dev saleExists serves to check if a sale exists
    function saleExists(uint256 saleId) public view returns (bool exists) {
        exists = (getSaleTokenAddress(saleId) != bytes32(0));
    } 

    // necessary for receiving native assets
    receive() external payable {}
}
// File: ethereum/contracts/icco/contributor/ContributorImplementation.sol

// contracts/Implementation.sol


pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;




contract ContributorImplementation is Contributor {
    function initialize() initializer public virtual {
        /// @dev this function needs to be exposed for an upgrade to pass
    }

    modifier initializer() {
        address impl = ERC1967Upgrade._getImplementation();

        require(
            !isInitialized(impl),
            "already initialized"
        );

        setInitialized(impl);

        _;
    }
}