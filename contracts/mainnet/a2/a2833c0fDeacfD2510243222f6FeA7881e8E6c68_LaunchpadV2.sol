//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ILaunchpadNFT.sol";

contract LaunchpadV2 is Ownable, ReentrancyGuard {
    event AddCampaign(address contractAddress, CampaignMode mode, address payeeAddress, address platformFeeAddress, uint256 platformFeeRate, uint256 price, uint256 maxSupply, uint256 listingTime, uint256 expirationTime, uint256 maxBatch, uint256 maxPerAddress, address validator);
    event UpdateCampaign(address contractAddress, CampaignMode mode, address payeeAddress, address platformFeeAddress, uint256 platformFeeRate, uint256 price, uint256 maxSupply, uint256 listingTime, uint256 expirationTime, uint256 maxBatch, uint256 maxPerAddress, address validator);
    event Mint(address indexed contractAddress, CampaignMode mode, address userAddress, address payeeAddress, address platformFeeAddress, uint256 size, uint256 fee, uint256 platformFee);

    enum CampaignMode {
        normal,
        whitelisted
    }
    struct Campaign {
        address contractAddress;
        address payeeAddress;
        address platformFeeAddress;
        uint256 platformFeeRate; // 0 %0 - 10000 100%
        uint256 price; // wei
        uint256 maxSupply;
        uint256 listingTime;
        uint256 expirationTime;
        uint256 maxBatch;
        uint256 maxPerAddress;
        address validator; // only for whitelisted
        uint256 minted;
    }

    mapping(address => Campaign) private _campaignsNormal;
    mapping(address => Campaign) private _campaignsWhitelisted;

    mapping(address => mapping(address => uint256)) private _mintPerAddressNormal;
    mapping(address => mapping(address => uint256)) private _mintPerAddressWhitelisted;

    /* Inverse basis point. */
    uint256 public constant INVERSE_BASIS_POINT = 10000;

    function mintWhitelisted(
        address contractAddress,
        uint256 batchSize,
        bytes memory signature
    ) external payable nonReentrant {

        //  Check whitelist validator signature
        Campaign memory campaign = getCampaign(contractAddress, CampaignMode.whitelisted);
        require(campaign.contractAddress != address(0), "contract not register");

        bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, address(this), contractAddress, msg.sender));
        bytes32 proof = ECDSA.toEthSignedMessageHash(messageHash);
        require(ECDSA.recover(proof, signature) == campaign.validator, "whitelist verification failed");

        // activity check
        mint_(contractAddress, batchSize, CampaignMode.whitelisted);

    }

    function mint(address contractAddress, uint256 batchSize) external payable nonReentrant {
        mint_(contractAddress, batchSize, CampaignMode.normal);
    }

    function mint_(address contractAddress, uint256 batchSize, CampaignMode mode) internal {
        require(contractAddress != address(0), "contract address can't be empty");
        require(batchSize > 0, "batchSize must greater than 0");

        Campaign memory campaign = getCampaign(contractAddress, mode);

        require(campaign.contractAddress != address(0), "contract not register");

        require(batchSize <= campaign.maxBatch, "reach max batch size");
        require(block.timestamp >= campaign.listingTime, "activity not start");
        require(block.timestamp < campaign.expirationTime, "activity ended");
        // normal and white-list mint have individual maxSupply and share MaxLaunchpadSupply
        require(campaign.minted + batchSize <= campaign.maxSupply, "reach campaign max supply");
        require(ILaunchpadNFT(campaign.contractAddress).getLaunchpadSupply() + batchSize <= ILaunchpadNFT(campaign.contractAddress).getMaxLaunchpadSupply(), "reach campaign total max supply");

        if (mode == CampaignMode.normal) {
            require(_mintPerAddressNormal[campaign.contractAddress][msg.sender] + batchSize <= campaign.maxPerAddress, "reach max per address limit");
            _mintPerAddressNormal[contractAddress][msg.sender] = _mintPerAddressNormal[contractAddress][msg.sender] + batchSize;
            _campaignsNormal[contractAddress].minted += batchSize;

        } else {
            require(_mintPerAddressWhitelisted[campaign.contractAddress][msg.sender] + batchSize <= campaign.maxPerAddress, "reach max per address limit");
            _mintPerAddressWhitelisted[contractAddress][msg.sender] = _mintPerAddressWhitelisted[contractAddress][msg.sender] + batchSize;
            _campaignsWhitelisted[contractAddress].minted += batchSize;
        }

        uint256 totalPrice = campaign.price * batchSize;
        require(msg.value >= totalPrice, "value not enough");

        // transfer token and mint
        uint256 platformFee = totalPrice * campaign.platformFeeRate / INVERSE_BASIS_POINT;
        uint256 fee = totalPrice - platformFee;
        payable(campaign.payeeAddress).transfer(fee);
        if (platformFee > 0) {
            payable(campaign.platformFeeAddress).transfer(platformFee);
        }

        ILaunchpadNFT(contractAddress).mintTo(msg.sender, batchSize);

        emit Mint(campaign.contractAddress, mode, msg.sender, campaign.payeeAddress, campaign.platformFeeAddress, batchSize, fee, platformFee);
        // return
        uint256 valueLeft = msg.value - totalPrice;
        if (valueLeft > 0) {
            payable(_msgSender()).transfer(valueLeft);
        }

    }

    function getMintPerAddress(
        address contractAddress,
        CampaignMode mode,
        address userAddress
    ) external view returns (uint256 mintPerAddress) {
        require(userAddress != address(0), "user address invalid");
        if (mode == CampaignMode.normal) {
            mintPerAddress = _mintPerAddressNormal[contractAddress][userAddress];
        } else {
            mintPerAddress = _mintPerAddressWhitelisted[contractAddress][userAddress];
        }
    }

    function getLaunchpadMaxSupply(address contractAddress, CampaignMode mode) external view returns (uint256) {
        if (mode == CampaignMode.normal) {
            return _campaignsNormal[contractAddress].maxSupply;
        } else {
            return _campaignsWhitelisted[contractAddress].maxSupply;
        }
    }

    function getLaunchpadSupply(address contractAddress, CampaignMode mode) external view returns (uint256) {
        if (mode == CampaignMode.normal) {
            return _campaignsNormal[contractAddress].minted;
        } else {
            return _campaignsWhitelisted[contractAddress].minted;
        }
    }

    function getLaunchpadSupplyTotal(address contractAddress) external view returns (uint256) {
        return ILaunchpadNFT(contractAddress).getLaunchpadSupply();
    }

    function addCampaign(
        address[] memory addresses,
        CampaignMode mode,
        uint256[] memory values
    ) external onlyOwner {
        require(addresses.length == 4, "addresses size wrong");
        require(values.length == 7, "values size wrong");
        Campaign memory campaign = Campaign(
            addresses[0], // contractAddress_,
            addresses[1], // payeeAddress_,
            addresses[2], // platformFeeAddress_,
            values[0], // platformFeeRate_,
            values[1], // price_,
            values[2], // maxSupply_,
            values[3], // listingTime_,
            values[4], // expirationTime_,
            values[5], // maxBatch_,
            values[6], // maxPerAddress_,
            addresses[3], // validator_,
            0
        );
        addCampaign_(campaign, mode);
    }

    function addCampaign_(
        Campaign memory campaign,
        CampaignMode mode
    ) internal {

        campaignCheck(campaign, mode);

        if (mode == CampaignMode.normal) {
            require(_campaignsNormal[campaign.contractAddress].contractAddress == address(0), "contract address already exist");
        } else {
            require(_campaignsWhitelisted[campaign.contractAddress].contractAddress == address(0), "contract address already exist");
        }

        emit AddCampaign(
            campaign.contractAddress,
            mode,
            campaign.payeeAddress,
            campaign.platformFeeAddress,
            campaign.platformFeeRate,
            campaign.price,
            campaign.maxSupply,
            campaign.listingTime,
            campaign.expirationTime,
            campaign.maxBatch,
            campaign.maxPerAddress,
            campaign.validator
        );

        if (mode == CampaignMode.normal) {
            _campaignsNormal[campaign.contractAddress] = campaign;
        } else {
            _campaignsWhitelisted[campaign.contractAddress] = campaign;
        }
    }

    function updateCampaign(
        address[] memory addresses,
        CampaignMode mode,
        uint256[] memory values
    ) external onlyOwner {
        require(addresses.length == 4, "addresses size wrong");
        require(values.length == 7, "values size wrong");

        address contractAddress = addresses[0];
        uint256 minted;
        if (mode == CampaignMode.normal) {
            require(_campaignsNormal[contractAddress].contractAddress != address(0), "normal contract address not exist");
            minted = _campaignsNormal[contractAddress].minted;
        } else {
            require(_campaignsWhitelisted[contractAddress].contractAddress != address(0), "white-list contract address not exist");
            minted = _campaignsWhitelisted[contractAddress].minted;
        }

        Campaign memory campaign = Campaign(
            addresses[0], // contractAddress_,
            addresses[1], //payeeAddress_,
            addresses[2], //platformFeeAddress_,
            values[0], //platformFeeRate_,
            values[1], //price_,
            values[2], //maxSupply_,
            values[3], //listingTime_,
            values[4], //expirationTime_,
            values[5], // maxBatch_,
            values[6], //maxPerAddress_,
            addresses[3], //validator_,
            minted
        );
        updateCampaign_(campaign, mode);
    }

    function updateCampaign_(Campaign memory campaign, CampaignMode mode) internal {

        campaignCheck(campaign, mode);

        emit UpdateCampaign(campaign.contractAddress, mode, campaign.payeeAddress, campaign.platformFeeAddress, campaign.platformFeeRate, campaign.price, campaign.maxSupply, campaign.listingTime, campaign.expirationTime, campaign.maxBatch, campaign.maxPerAddress, campaign.validator);

        if (mode == CampaignMode.normal) {
            _campaignsNormal[campaign.contractAddress] = campaign;
        } else {
            _campaignsWhitelisted[campaign.contractAddress] = campaign;
        }
    }

    function campaignCheck(Campaign memory campaign, CampaignMode mode) private view {
        require(campaign.contractAddress != address(0), "contract address can't be empty");
        require(campaign.expirationTime > campaign.listingTime, "expiration time must above listing time");
        require(campaign.maxSupply > 0 && campaign.maxSupply <= ILaunchpadNFT(campaign.contractAddress).getMaxLaunchpadSupply(), "campaign max supply invalid");

        if (mode == CampaignMode.whitelisted) {
            require(campaign.validator != address(0), "validator can't be empty");
        }

        require(campaign.payeeAddress != address(0), "payee address can't be empty");
        require(campaign.platformFeeAddress != address(0), "platform fee address can't be empty");
        require(campaign.platformFeeRate >= 0 && campaign.platformFeeRate <= INVERSE_BASIS_POINT, "platform fee rate invalid");
        require(campaign.maxBatch > 0 && campaign.maxBatch <= 10, "max batch invalid");
        require(campaign.maxPerAddress > 0 && campaign.maxPerAddress <= campaign.maxSupply, "max per address invalid");
    }

    function getCampaign(address contractAddress, CampaignMode mode) public view returns (Campaign memory) {
        if (mode == CampaignMode.normal) {
            return _campaignsNormal[contractAddress];
        } else {
            return _campaignsWhitelisted[contractAddress];
        }
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ILaunchpadNFT {
    // return max supply config for launchpad, if no reserved will be collection's max supply
    function getMaxLaunchpadSupply() external view returns (uint256);
    // return current launchpad supply
    function getLaunchpadSupply() external view returns (uint256);
    // this function need to restrict mint permission to launchpad contract
    function mintTo(address to, uint256 size) external;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
}