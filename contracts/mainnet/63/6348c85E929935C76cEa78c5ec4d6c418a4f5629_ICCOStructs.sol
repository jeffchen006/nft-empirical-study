/**
 *Submitted for verification at Etherscan.io on 2023-03-20
*/

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