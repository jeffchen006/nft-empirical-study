// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.0;

import "ERC721URIStorage.sol";
import "Ownable.sol";

/*

The ERC721D standard is an advanced and dynamic implementation of the ERC721 token standard.
This innovative contract takes the non-fungible token (NFT) concept a step further by introducing dynamic ownership.
In conventional NFTs, a token can only be owned by an address.
However, in the ERC721D standard, ownership can be dynamic, meaning an NFT can be owned by either an address or another NFT.
This introduces a new layer of complexity and opportunity in the NFT space.

*/
contract Nested is ERC721, Ownable {
    
    // The Ownership structure represents the owner of the token
    struct Ownership {
        address ownerAddress;  // The address of the owner
        uint256 tokenId;       // The token Id of the owner if the owner is an NFT
    }

    // Mapping from token ID to Ownership
    mapping(uint256 => Ownership) private _owners;

    // Mapping from owner address to token balance
    mapping(address => uint256) private _balances;
    
    constructor() ERC721("Nested", "Nested") {}

    // Mint new token
    // `to` is the address that will own the minted token
    // `tokenId` is the identifier for the new token
    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
        _owners[tokenId] = Ownership(to, 0);
        _balances[to] += 1;
    }

    // Burn token
    // `tokenId` is the identifier for the token
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721D: caller is not owner nor approved");

        Ownership memory oldOwnership = _owners[tokenId];
        if (oldOwnership.ownerAddress != address(0)) {
            // Decrease the balance of the old owner
            _balances[oldOwnership.ownerAddress] -= 1;
        }
        
        // Set token ownership to the zero address (burning the token)
        _owners[tokenId] = Ownership(address(0), 0);
        _burn(tokenId);
    }

    // Transfer Nested Ownership of a token
    // `tokenId` is the identifier for the token
    // `newOwnerAddress` is the address of the new owner
    // `newTokenId` is the token Id of the new owner if the owner is an NFT
    function transferNestedOwnership(uint256 tokenId, address newOwnerAddress, uint256 newTokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721D: caller is not owner nor approved");
        Ownership memory oldOwnership = _owners[tokenId];
        
        // First time ownership, balance increases
        // Ownership is changing, adjust the balances
        if (oldOwnership.ownerAddress == address(0) || oldOwnership.ownerAddress != newOwnerAddress) {
            address oldOwner = oldOwnership.ownerAddress;
            _balances[oldOwner] -= 1;
            _balances[newOwnerAddress] += 1;
        }
        // Else: The token is being re-assigned to a different token but the same owner, do not change the balance.

        _owners[tokenId] = Ownership(newOwnerAddress, newTokenId);
    }

    // Overrides the 'ownerOf' function from the ERC721 standard.
    // Returns the current owner of the token identified by `tokenId`.
    // It navigates through potential layers of ownership, making it suitable for dynamic token structures.
    function ownerOf(uint256 tokenId) public view override(ERC721) returns (address) {
        address currentOwnerAddress = _owners[tokenId].ownerAddress;
        uint256 currentTokenId = _owners[tokenId].tokenId;

        // This loop will go through the ownership layers of the token.
        // It stops if the owner address is zero (no owner), or if there's an error calling the ownerOf function on the owner contract,
        // or if the returned owner is the same as the current owner (end of ownership chain).
        while (currentOwnerAddress != address(0)) {
            bytes memory payload = abi.encodeWithSignature("ownerOf(uint256)", currentTokenId);
            (bool success, bytes memory result) = currentOwnerAddress.staticcall(payload);
            if (!success || result.length == 0) {
                break;
            }

            address newOwnerAddress = abi.decode(result, (address));
            if (newOwnerAddress != currentOwnerAddress) {
                currentOwnerAddress = newOwnerAddress;
                currentTokenId = _owners[currentTokenId].tokenId;
            } else {
                break;
            }
        }

        // Return the final owner in the chain
        return currentOwnerAddress;
    }

    // This internal function is used to implement the transfer of tokens, following the ERC721 standard but allowing dynamic token ownership.
    // It transfers the `tokenId` token from the `from` address to the `to` address.
    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        require(ownerOf(tokenId) == from, "ERC721D: transfer of token that is not owned");
        Ownership memory oldOwnership = _owners[tokenId];
        
        _approve(address(0), tokenId);
        _owners[tokenId] = Ownership(to, 0);

        if (oldOwnership.ownerAddress == address(0)) {
            // The token is being owned for the first time, increase the balance of the new owner
            _balances[to] += 1;
        } else if (oldOwnership.ownerAddress != to) {
            // The token is changing owner, adjust the balances
            address oldOwner = oldOwnership.ownerAddress;
            _balances[oldOwner] -= 1;
            _balances[to] += 1;
        }
        
        emit Transfer(from, to, tokenId);
    }

    // An internal function that checks if a `spender` is an approved operator or the owner of a token.
    // Returns true if the `spender` is an approved operator or the owner of the `tokenId` token.
    // The function follows the ERC721 standard requirements.
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        require(_exists(tokenId), "ERC721D: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    // Overrides the `balanceOf` function from the ERC721 standard.
    // Returns the balance (number of owned tokens) of the `owner` address.
    // It checks for the zero address and returns the balance from the internal _balances mapping.
    function balanceOf(address owner) public view override(ERC721) returns (uint256) {
        require(owner != address(0), "ERC721D: balance query for the zero address");
        return _balances[owner];
    }

    // This function returns the ownership details of the `tokenId` token.
    // Returns a struct with the owner's address and the token id of the token owned by the returned token (if any).
    function owners(uint256 tokenId) public view returns (Ownership memory) {
        return _owners[tokenId];
    }

    // Base URI
    string private _baseURIextended;

    // Override function to set the base URI for all tokens
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    // Function to set the base URI
    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseURIextended = baseURI_;
    }

}