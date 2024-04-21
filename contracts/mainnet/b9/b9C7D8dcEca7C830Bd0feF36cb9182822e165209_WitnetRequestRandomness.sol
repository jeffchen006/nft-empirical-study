// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "WitnetRequestMalleableBase.sol";

contract WitnetRequestRandomness is WitnetRequestMalleableBase {
    bytes internal constant _WITNET_RANDOMNESS_BYTECODE_TEMPLATE = hex"0a0f120508021a01801a0210022202100b";

    constructor() {
        initialize(bytes(""));
    }

    function initialize(bytes memory)
        public
        virtual override
    {
        super.initialize(_WITNET_RANDOMNESS_BYTECODE_TEMPLATE);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "Witnet.sol";
import "Clonable.sol";
import "Ownable.sol";
import "Proxiable.sol";

abstract contract WitnetRequestMalleableBase
    is
        IWitnetRequest,
        Clonable,
        Ownable,
        Proxiable
{
    using Witnet for bytes;

    event WitnessingParamsChanged(
        address indexed by,
        uint8 numWitnesses,
        uint8 minWitnessingConsensus,
        uint64 witnssingCollateral,
        uint64 witnessingReward,
        uint64 witnessingUnitaryFee
    );

    error noWitnessingReward();
    error invalidNumWitnesses(uint8 _numWitnesses);
    error invalidWitnessingConsensus(uint8 _minWitnessingConsensus);
    error invalidWitnessingCollateral(uint64 _witnessingCollateral);

    struct WitnetRequestMalleableBaseContext {
        /// Contract owner address.
        address owner;
        /// Immutable bytecode template.
        bytes template;
        /// Current request bytecode.
        bytes bytecode;
        /// Current request hash.
        bytes32 hash;
        /// Current request witnessing params.
        WitnetRequestWitnessingParams params;
    }

    struct WitnetRequestWitnessingParams {
        /// Number of witnesses required to be involved for solving this Witnet Data Request.
        uint8 numWitnesses;

        /// Threshold percentage for aborting resolution of a request if the witnessing nodes did not arrive to a broad consensus.
        uint8 minWitnessingConsensus;

        /// Amount of nanowits that a witness solving the request will be required to collateralize in the commitment transaction.
        uint64 witnessingCollateral;

        /// Amount of nanowits that every request-solving witness will be rewarded with.
        uint64 witnessingReward;

        /// Amount of nanowits that will be earned by Witnet miners for each each valid commit/reveal transaction they include in a block.
        uint64 witnessingUnitaryFee;
    }

    /// Returns current Witnet Data Request bytecode, encoded using Protocol Buffers.
    function bytecode() external view override returns (bytes memory) {
        return _request().bytecode;
    }

    /// Returns SHA256 hash of current Witnet Data Request bytecode.
    function hash() external view override returns (bytes32) {
        return _request().hash;
    }

    /// Specifies how much you want to pay for rewarding each of the Witnet nodes.
    /// @param _witnessingCollateral Sets amount of nanowits that a witness solving the request will be required to collateralize.
    /// @param _witnessingReward Amount of nanowits that every request-solving witness will be rewarded with.
    /// @param _witnessingUnitaryFee Amount of nanowits that will be earned by Witnet miners for each each valid 
    /// commit/reveal transaction they include in a block.
    function setWitnessingMonetaryPolicy(uint64 _witnessingCollateral, uint64 _witnessingReward, uint64 _witnessingUnitaryFee)
        public
        virtual
        onlyOwner
    {
        WitnetRequestWitnessingParams storage _params = _request().params;
        _params.witnessingCollateral = _witnessingCollateral;
        _params.witnessingReward = _witnessingReward;
        _params.witnessingUnitaryFee = _witnessingUnitaryFee;
        _malleateBytecode(
            _params.numWitnesses,
            _params.minWitnessingConsensus,
            _witnessingCollateral,
            _witnessingReward,
            _witnessingUnitaryFee
        );
    }

    /// Sets how many Witnet nodes will be "hired" for resolving the request.
    /// @param _numWitnesses Number of witnesses required to be involved for solving this Witnet Data Request.
    /// @param _minWitnessingConsensus Threshold percentage for aborting resolution of a request if the witnessing 
    /// nodes did not arrive to a broad consensus.
    function setWitnessingQuorum(uint8 _numWitnesses, uint8 _minWitnessingConsensus)
        public
        virtual
        onlyOwner
    {
        WitnetRequestWitnessingParams storage _params = _request().params;
        _params.numWitnesses = _numWitnesses;
        _params.minWitnessingConsensus = _minWitnessingConsensus;
        _malleateBytecode(
            _numWitnesses,
            _minWitnessingConsensus,
            _params.witnessingCollateral,
            _params.witnessingReward,
            _params.witnessingUnitaryFee
        );
    }

    /// Sets all witness parameters for a request
    /// @param _witnessingCollateral: Amount of nanowits that a witness solving the request will be required to collateralize in the commitment transaction.
    /// @param _witnessingReward Amount of nanowits that every request-solving witness will be rewarded with.
    /// @param _witnessingUnitaryFee Amount of nanowits that will be earned by Witnet miners for each each valid 
    /// commit/reveal transaction they include in a block.
    /// @param _numWitnesses Number of witnesses required to be involved for solving this Witnet Data Request.
    /// @param _minWitnessingConsensus Threshold percentage for aborting resolution of a request if the witnessing 
    /// nodes did not arrive to a broad consensus.
    function setWitnessingParameters(uint64 _witnessingCollateral, uint64 _witnessingReward, uint64 _witnessingUnitaryFee, uint8 _numWitnesses, uint8 _minWitnessingConsensus)
        public
        virtual
        onlyOwner
    {
        WitnetRequestWitnessingParams storage _params = _request().params;
        _params.witnessingCollateral = _witnessingCollateral;
        _params.witnessingReward = _witnessingReward;
        _params.witnessingUnitaryFee = _witnessingUnitaryFee;
        _params.numWitnesses = _numWitnesses;
        _params.minWitnessingConsensus = _minWitnessingConsensus;
        _malleateBytecode(
            _numWitnesses,
            _minWitnessingConsensus,
            _witnessingCollateral,
            _witnessingReward,
            _witnessingUnitaryFee
        );
    }

    /// Returns immutable template bytecode: actual CBOR-encoded data request at the Witnet protocol
    /// level, including no witnessing parameters at all.
    function template()
        external view
        returns (bytes memory)
    {
        return _request().template;
    }

    /// Returns total amount of nanowits that witnessing nodes will need to collateralize all together.
    function totalWitnessingCollateral()
        external view
        returns (uint128)
    {
        WitnetRequestWitnessingParams storage _params = _request().params;
        return _params.numWitnesses * _params.witnessingCollateral;
    }

    /// Returns total amount of nanowits that will have to be paid in total for this request to be solved.
    function totalWitnessingFee()
        external view
        returns (uint128)
    {
        WitnetRequestWitnessingParams storage _params = _request().params;
        return _params.numWitnesses * (2 * _params.witnessingUnitaryFee + _params.witnessingReward);
    }

    /// Returns witnessing parameters of current Witnet Data Request.
    function witnessingParams()
        external view
        returns (WitnetRequestWitnessingParams memory)
    {
        return _request().params;
    }


    // ================================================================================================================
    // --- 'Clonable' overriden functions -----------------------------------------------------------------------------

    /// Deploys and returns the address of a minimal proxy clone that replicates contract
    /// behaviour while using its own EVM storage.
    /// @dev This function should always provide a new address, no matter how many times 
    /// @dev is actually called from the same `msg.sender`.
    function clone()
        public
        virtual override
        returns (Clonable _instance)
    {
        _instance = super.clone();
        _instance.initialize(_request().template);
        Ownable(address(_instance)).transferOwnership(msg.sender);
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract 
    /// behaviour while using its own EVM storage.
    /// @dev This function uses the CREATE2 opcode and a `_salt` to deterministically deploy
    /// @dev the clone. Using the same `_salt` multiple time will revert, since
    /// @dev no contract can be deployed more than once at the same address.
    function cloneDeterministic(bytes32 _salt)
        public
        virtual override
        returns (Clonable _instance)
    {
        _instance = super.cloneDeterministic(_salt);
        _instance.initialize(_request().template);
        Ownable(address(_instance)).transferOwnership(msg.sender);
    }


    // ================================================================================================================
    // --- 'Initializable' overriden functions ------------------------------------------------------------------------

    /// @dev Initializes contract's storage context.
    function initialize(bytes memory _template)
        public
        virtual override
    {
        require(_request().template.length == 0, "WitnetRequestMalleableBase: already initialized");
        _initialize(_template);
        _transferOwnership(_msgSender());
    }

    // ================================================================================================================
    // --- 'Ownable' overriden functions ------------------------------------------------------------------------------

    /// Returns the address of the current owner.
    function owner()
        public view
        virtual override
        returns (address)
    {
        return _request().owner;
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    function _transferOwnership(address newOwner)
        internal
        virtual override
    {
        address oldOwner = _request().owner;
        _request().owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // ================================================================================================================
    // --- 'Proxiable 'overriden functions ----------------------------------------------------------------------------

    /// @dev Complying with EIP-1822: Universal Upgradable Proxy Standard (UUPS)
    /// @dev See https://eips.ethereum.org/EIPS/eip-1822.
    function proxiableUUID()
        external pure
        virtual override
        returns (bytes32)
    {
        return (
            /* keccak256("io.witnet.requests.malleable") */
            0x851d0a92a3ad30295bef33afc69d6874779826b7789386b336e22621365ed2c2
        );
    }


    // ================================================================================================================
    // --- INTERNAL FUNCTIONS -----------------------------------------------------------------------------------------    

    /// @dev Initializes witnessing params and template bytecode.
    function _initialize(bytes memory _template)
        internal
    {
        assert(_template.length > 0);
        _request().template = _template;

        WitnetRequestWitnessingParams storage _params = _request().params;
        _params.numWitnesses = 2;
        _params.minWitnessingConsensus = 51;
        _params.witnessingCollateral = 10 ** 9;      // 1 WIT
        _params.witnessingReward = 5 * 10 ** 5;      // 0.5 milliWITs
        _params.witnessingUnitaryFee = 25 * 10 ** 4; // 0.25 milliWITs

        _malleateBytecode(
            _params.numWitnesses,
            _params.minWitnessingConsensus,
            _params.witnessingCollateral,
            _params.witnessingReward,
            _params.witnessingUnitaryFee
        );
    }

    /// @dev Serializes new `bytecode` by combining immutable template with given parameters.
    function _malleateBytecode(
            uint8 _numWitnesses,
            uint8 _minWitnessingConsensus,
            uint64 _witnessingCollateral,
            uint64 _witnessingReward,
            uint64 _witnessingUnitaryFee
        )
        internal
        virtual
    {
        if (_witnessingReward == 0)
            revert noWitnessingReward();
        if (_numWitnesses > 125 || _numWitnesses == 0)
            revert invalidNumWitnesses(_numWitnesses);
        if (_minWitnessingConsensus < 51 || _minWitnessingConsensus > 99)
            revert invalidWitnessingConsensus(_minWitnessingConsensus);
        if (_witnessingCollateral < 10 ** 9)
            revert invalidWitnessingCollateral(_witnessingCollateral);

        _request().bytecode = abi.encodePacked(
            _request().template,
            _uint64varint(bytes1(0x10), _witnessingReward),
            _uint8varint(bytes1(0x18), _numWitnesses),
            _uint64varint(0x20, _witnessingUnitaryFee),
            _uint8varint(0x28, _minWitnessingConsensus),
            _uint64varint(0x30, _witnessingCollateral)
        );
        _request().hash = _request().bytecode.hash();
        emit WitnessingParamsChanged(
            msg.sender,
            _numWitnesses,
            _minWitnessingConsensus,
            _witnessingCollateral,
            _witnessingReward,
            _witnessingUnitaryFee
        );
    }

    /// @dev Returns pointer to storage slot where State struct is located.
    function _request()
        internal pure
        virtual
        returns (WitnetRequestMalleableBaseContext storage _ptr)
    {
        assembly {
            _ptr.slot :=
                /* keccak256("io.witnet.requests.malleable.context") */
                0x375930152e1d0d102998be6e496b0cee86c9ecd0efef01014ecff169b17dfba7
        }
    }

    /// @dev Encode uint64 into tagged varint.
    /// @dev See https://developers.google.com/protocol-buffers/docs/encoding#varints.
    /// @param t Tag
    /// @param n Number
    /// @return Marshaled bytes
    function _uint64varint(bytes1 t, uint64 n)
        internal pure
        returns (bytes memory)
    {
        // Count the number of groups of 7 bits
        // We need this pre-processing step since Solidity doesn't allow dynamic memory resizing
        uint64 tmp = n;
        uint64 numBytes = 2;
        while (tmp > 0x7F) {
            tmp = tmp >> 7;
            unchecked {
                numBytes += 1;
            }
        }
        bytes memory buf = new bytes(numBytes);
        tmp = n;
        buf[0] = t;
        for (uint64 i = 1; i < numBytes;) {
            // Set the first bit in the byte for each group of 7 bits
            buf[i] = bytes1(0x80 | uint8(tmp & 0x7F));
            tmp = tmp >> 7;
            unchecked {
                i++;
            }
        }
        // Unset the first bit of the last byte
        buf[numBytes - 1] &= 0x7F;
        return buf;
    }

    /// @dev Encode uint8 into tagged varint.
    /// @param t Tag
    /// @param n Number
    /// @return Marshaled bytes
    function _uint8varint(bytes1 t, uint8 n)
        internal pure
        returns (bytes memory)
    {
        return _uint64varint(t, uint64(n));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "IWitnetRequest.sol";

library Witnet {

    /// @notice Witnet function that computes the hash of a CBOR-encoded Data Request.
    /// @param _bytecode CBOR-encoded RADON.
    function hash(bytes memory _bytecode) internal pure returns (bytes32) {
        return sha256(_bytecode);
    }

    /// Struct containing both request and response data related to every query posted to the Witnet Request Board
    struct Query {
        Request request;
        Response response;
        address from;      // Address from which the request was posted.
    }

    /// Possible status of a Witnet query.
    enum QueryStatus {
        Unknown,
        Posted,
        Reported,
        Deleted
    }

    /// Data kept in EVM-storage for every Request posted to the Witnet Request Board.
    struct Request {
        IWitnetRequest addr;    // The contract containing the Data Request which execution has been requested.
        address requester;      // Address from which the request was posted.
        bytes32 hash;           // Hash of the Data Request whose execution has been requested.
        uint256 gasprice;       // Minimum gas price the DR resolver should pay on the solving tx.
        uint256 reward;         // Escrowed reward to be paid to the DR resolver.
    }

    /// Data kept in EVM-storage containing Witnet-provided response metadata and result.
    struct Response {
        address reporter;       // Address from which the result was reported.
        uint256 timestamp;      // Timestamp of the Witnet-provided result.
        bytes32 drTxHash;       // Hash of the Witnet transaction that solved the queried Data Request.
        bytes   cborBytes;      // Witnet-provided result CBOR-bytes to the queried Data Request.
    }

    /// Data struct containing the Witnet-provided result to a Data Request.
    struct Result {
        bool success;           // Flag stating whether the request could get solved successfully, or not.
        CBOR value;             // Resulting value, in CBOR-serialized bytes.
    }

    /// Data struct following the RFC-7049 standard: Concise Binary Object Representation.
    struct CBOR {
        Buffer buffer;
        uint8 initialByte;
        uint8 majorType;
        uint8 additionalInformation;
        uint64 len;
        uint64 tag;
    }

    /// Iterable bytes buffer.
    struct Buffer {
        bytes data;
        uint32 cursor;
    }

    /// Witnet error codes table.
    enum ErrorCodes {
        // 0x00: Unknown error. Something went really bad!
        Unknown,
        // Script format errors
        /// 0x01: At least one of the source scripts is not a valid CBOR-encoded value.
        SourceScriptNotCBOR,
        /// 0x02: The CBOR value decoded from a source script is not an Array.
        SourceScriptNotArray,
        /// 0x03: The Array value decoded form a source script is not a valid Data Request.
        SourceScriptNotRADON,
        /// Unallocated
        ScriptFormat0x04,
        ScriptFormat0x05,
        ScriptFormat0x06,
        ScriptFormat0x07,
        ScriptFormat0x08,
        ScriptFormat0x09,
        ScriptFormat0x0A,
        ScriptFormat0x0B,
        ScriptFormat0x0C,
        ScriptFormat0x0D,
        ScriptFormat0x0E,
        ScriptFormat0x0F,
        // Complexity errors
        /// 0x10: The request contains too many sources.
        RequestTooManySources,
        /// 0x11: The script contains too many calls.
        ScriptTooManyCalls,
        /// Unallocated
        Complexity0x12,
        Complexity0x13,
        Complexity0x14,
        Complexity0x15,
        Complexity0x16,
        Complexity0x17,
        Complexity0x18,
        Complexity0x19,
        Complexity0x1A,
        Complexity0x1B,
        Complexity0x1C,
        Complexity0x1D,
        Complexity0x1E,
        Complexity0x1F,
        // Operator errors
        /// 0x20: The operator does not exist.
        UnsupportedOperator,
        /// Unallocated
        Operator0x21,
        Operator0x22,
        Operator0x23,
        Operator0x24,
        Operator0x25,
        Operator0x26,
        Operator0x27,
        Operator0x28,
        Operator0x29,
        Operator0x2A,
        Operator0x2B,
        Operator0x2C,
        Operator0x2D,
        Operator0x2E,
        Operator0x2F,
        // Retrieval-specific errors
        /// 0x30: At least one of the sources could not be retrieved, but returned HTTP error.
        HTTP,
        /// 0x31: Retrieval of at least one of the sources timed out.
        RetrievalTimeout,
        /// Unallocated
        Retrieval0x32,
        Retrieval0x33,
        Retrieval0x34,
        Retrieval0x35,
        Retrieval0x36,
        Retrieval0x37,
        Retrieval0x38,
        Retrieval0x39,
        Retrieval0x3A,
        Retrieval0x3B,
        Retrieval0x3C,
        Retrieval0x3D,
        Retrieval0x3E,
        Retrieval0x3F,
        // Math errors
        /// 0x40: Math operator caused an underflow.
        Underflow,
        /// 0x41: Math operator caused an overflow.
        Overflow,
        /// 0x42: Tried to divide by zero.
        DivisionByZero,
        /// Unallocated
        Math0x43,
        Math0x44,
        Math0x45,
        Math0x46,
        Math0x47,
        Math0x48,
        Math0x49,
        Math0x4A,
        Math0x4B,
        Math0x4C,
        Math0x4D,
        Math0x4E,
        Math0x4F,
        // Other errors
        /// 0x50: Received zero reveals
        NoReveals,
        /// 0x51: Insufficient consensus in tally precondition clause
        InsufficientConsensus,
        /// 0x52: Received zero commits
        InsufficientCommits,
        /// 0x53: Generic error during tally execution
        TallyExecution,
        /// Unallocated
        OtherError0x54,
        OtherError0x55,
        OtherError0x56,
        OtherError0x57,
        OtherError0x58,
        OtherError0x59,
        OtherError0x5A,
        OtherError0x5B,
        OtherError0x5C,
        OtherError0x5D,
        OtherError0x5E,
        OtherError0x5F,
        /// 0x60: Invalid reveal serialization (malformed reveals are converted to this value)
        MalformedReveal,
        /// Unallocated
        OtherError0x61,
        OtherError0x62,
        OtherError0x63,
        OtherError0x64,
        OtherError0x65,
        OtherError0x66,
        OtherError0x67,
        OtherError0x68,
        OtherError0x69,
        OtherError0x6A,
        OtherError0x6B,
        OtherError0x6C,
        OtherError0x6D,
        OtherError0x6E,
        OtherError0x6F,
        // Access errors
        /// 0x70: Tried to access a value from an index using an index that is out of bounds
        ArrayIndexOutOfBounds,
        /// 0x71: Tried to access a value from a map using a key that does not exist
        MapKeyNotFound,
        /// Unallocated
        OtherError0x72,
        OtherError0x73,
        OtherError0x74,
        OtherError0x75,
        OtherError0x76,
        OtherError0x77,
        OtherError0x78,
        OtherError0x79,
        OtherError0x7A,
        OtherError0x7B,
        OtherError0x7C,
        OtherError0x7D,
        OtherError0x7E,
        OtherError0x7F,
        OtherError0x80,
        OtherError0x81,
        OtherError0x82,
        OtherError0x83,
        OtherError0x84,
        OtherError0x85,
        OtherError0x86,
        OtherError0x87,
        OtherError0x88,
        OtherError0x89,
        OtherError0x8A,
        OtherError0x8B,
        OtherError0x8C,
        OtherError0x8D,
        OtherError0x8E,
        OtherError0x8F,
        OtherError0x90,
        OtherError0x91,
        OtherError0x92,
        OtherError0x93,
        OtherError0x94,
        OtherError0x95,
        OtherError0x96,
        OtherError0x97,
        OtherError0x98,
        OtherError0x99,
        OtherError0x9A,
        OtherError0x9B,
        OtherError0x9C,
        OtherError0x9D,
        OtherError0x9E,
        OtherError0x9F,
        OtherError0xA0,
        OtherError0xA1,
        OtherError0xA2,
        OtherError0xA3,
        OtherError0xA4,
        OtherError0xA5,
        OtherError0xA6,
        OtherError0xA7,
        OtherError0xA8,
        OtherError0xA9,
        OtherError0xAA,
        OtherError0xAB,
        OtherError0xAC,
        OtherError0xAD,
        OtherError0xAE,
        OtherError0xAF,
        OtherError0xB0,
        OtherError0xB1,
        OtherError0xB2,
        OtherError0xB3,
        OtherError0xB4,
        OtherError0xB5,
        OtherError0xB6,
        OtherError0xB7,
        OtherError0xB8,
        OtherError0xB9,
        OtherError0xBA,
        OtherError0xBB,
        OtherError0xBC,
        OtherError0xBD,
        OtherError0xBE,
        OtherError0xBF,
        OtherError0xC0,
        OtherError0xC1,
        OtherError0xC2,
        OtherError0xC3,
        OtherError0xC4,
        OtherError0xC5,
        OtherError0xC6,
        OtherError0xC7,
        OtherError0xC8,
        OtherError0xC9,
        OtherError0xCA,
        OtherError0xCB,
        OtherError0xCC,
        OtherError0xCD,
        OtherError0xCE,
        OtherError0xCF,
        OtherError0xD0,
        OtherError0xD1,
        OtherError0xD2,
        OtherError0xD3,
        OtherError0xD4,
        OtherError0xD5,
        OtherError0xD6,
        OtherError0xD7,
        OtherError0xD8,
        OtherError0xD9,
        OtherError0xDA,
        OtherError0xDB,
        OtherError0xDC,
        OtherError0xDD,
        OtherError0xDE,
        OtherError0xDF,
        // Bridge errors: errors that only belong in inter-client communication
        /// 0xE0: Requests that cannot be parsed must always get this error as their result.
        /// However, this is not a valid result in a Tally transaction, because invalid requests
        /// are never included into blocks and therefore never get a Tally in response.
        BridgeMalformedRequest,
        /// 0xE1: Witnesses exceeds 100
        BridgePoorIncentives,
        /// 0xE2: The request is rejected on the grounds that it may cause the submitter to spend or stake an
        /// amount of value that is unjustifiably high when compared with the reward they will be getting
        BridgeOversizedResult,
        /// Unallocated
        OtherError0xE3,
        OtherError0xE4,
        OtherError0xE5,
        OtherError0xE6,
        OtherError0xE7,
        OtherError0xE8,
        OtherError0xE9,
        OtherError0xEA,
        OtherError0xEB,
        OtherError0xEC,
        OtherError0xED,
        OtherError0xEE,
        OtherError0xEF,
        OtherError0xF0,
        OtherError0xF1,
        OtherError0xF2,
        OtherError0xF3,
        OtherError0xF4,
        OtherError0xF5,
        OtherError0xF6,
        OtherError0xF7,
        OtherError0xF8,
        OtherError0xF9,
        OtherError0xFA,
        OtherError0xFB,
        OtherError0xFC,
        OtherError0xFD,
        OtherError0xFE,
        // This should not exist:
        /// 0xFF: Some tally error is not intercepted but should
        UnhandledIntercept
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title The Witnet Data Request basic interface.
/// @author The Witnet Foundation.
interface IWitnetRequest {
    /// A `IWitnetRequest` is constructed around a `bytes` value containing 
    /// a well-formed Witnet Data Request using Protocol Buffers.
    function bytecode() external view returns (bytes memory);

    /// Returns SHA256 hash of Witnet Data Request as CBOR-encoded bytes.
    function hash() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "Initializable.sol";

abstract contract Clonable is Initializable {
    /// Immutable contract address that actually attends all calls to this contract.
    /// @dev Differs from `address(this)` when reached within a DELEGATECALL.
    address immutable public self = address(this);

    event Cloned(address indexed by, Clonable indexed self, Clonable indexed clone);

    /// Tells whether this contract is a clone of another (i.e. `self()`)
    function cloned()
        public view
        returns (bool)
    {
        return (
            address(this) != self
        );
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract
    /// behaviour while using its own EVM storage.
    /// @dev This function should always provide a new address, no matter how many times 
    /// @dev is actually called from the same `msg.sender`.
    /// @dev See https://eips.ethereum.org/EIPS/eip-1167.
    /// @dev See https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/.
    function clone()
        public virtual
        returns (Clonable _instance)
    {
        address _self = self;
        assembly {
            // ptr to free mem:
            let ptr := mload(0x40)
            // begin minimal proxy construction bytecode:
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            // make minimal proxy delegate all calls to `self()`:
            mstore(add(ptr, 0x14), shl(0x60, _self))
            // end minimal proxy construction bytecode:
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            // CREATE new instance:
            _instance := create(0, ptr, 0x37)
        }        
        require(address(_instance) != address(0), "Clonable: CREATE failed");
        emit Cloned(msg.sender, Clonable(self), _instance);
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract 
    /// behaviour while using its own EVM storage.
    /// @dev This function uses the CREATE2 opcode and a `_salt` to deterministically deploy
    /// @dev the clone. Using the same `_salt` multiple times will revert, since
    /// @dev no contract can be deployed more than once at the same address.
    /// @dev See https://eips.ethereum.org/EIPS/eip-1167.
    /// @dev See https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/.
    function cloneDeterministic(bytes32 _salt)
        public virtual
        returns (Clonable _instance)
    {
        address _self = self;
        assembly {
            // ptr to free mem:
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            // make minimal proxy delegate all calls to `self()`:
            mstore(add(ptr, 0x14), shl(0x60, _self))
            // end minimal proxy construction bytecode:
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            // CREATE2 new instance:
            _instance := create2(0, ptr, 0x37, _salt)
        }
        require(address(_instance) != address(0), "Clonable: CREATE2 failed");
        emit Cloned(msg.sender, Clonable(self), _instance);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface Initializable {
    /// @dev Initialize contract's storage context.
    function initialize(bytes calldata) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "Context.sol";

/// @dev Contract module which provides a basic access control mechanism, where
/// there is an account (an owner) that can be granted exclusive access to
/// specific functions.
///
/// By default, the owner account will be the one that deploys the contract. This
/// can later be changed with {transferOwnership}.
///
/// This module is used through inheritance. It will make available the modifier
/// `onlyOwner`, which can be applied to your functions to restrict their use to
/// the owner.

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Initializes the contract setting the deployer as the initial owner.
    constructor() {
        _transferOwnership(_msgSender());
    }

    /// @dev Returns the address of the current owner.
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /// @dev Leaves the contract without owner. It will not be possible to call
    /// `onlyOwner` functions anymore. Can only be called by the current owner.
    /// NOTE: Renouncing ownership will leave the contract without an owner,
    /// thereby removing any functionality that is only available to the owner.
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// Can only be called by the current owner.
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// Internal function without access restriction.
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @dev Provides information about the current execution context, including the
/// sender of the transaction and its data. While these are generally available
/// via msg.sender and msg.data, they should not be accessed in such a direct
/// manner, since when dealing with meta-transactions the account sending and
/// paying for execution may not be the actual sender (as far as an application
/// is concerned).
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _msgValue() internal view virtual returns (uint256) {
        return msg.value;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface Proxiable {
    /// @dev Complying with EIP-1822: Universal Upgradable Proxy Standard (UUPS)
    /// @dev See https://eips.ethereum.org/EIPS/eip-1822.
    function proxiableUUID() external pure returns (bytes32);
}