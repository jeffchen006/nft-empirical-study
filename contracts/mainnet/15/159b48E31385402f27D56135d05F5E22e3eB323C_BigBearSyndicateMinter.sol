//                             .*+=.
//                        .#+.  -###: *#*-
//                         ###+   --   -=:
//                         .#+:.+###*.+*=.
//       .::-----.       *:   :#######:*##=                                                             +++++=-:.
//  -+#%@@@@@@@@@@@%+.  :#%*  *########-*##.                                                           [email protected]@@@@@@@@@%*=:
// %@@@@@@@@@@@@@@@@@@#. :*#+ +############:           :-=++++=:                                       [email protected]@@@@@@@@@@@@@@=
// [email protected]@@@@@@@@@@@@@@@@@@@:     .########=:.            #@@@@@@@@@@#.                                    *@@@@@@@@@@@@@@@@@-
//  %@@@@@@%=--=+%@@@@@@@:      =+***=:  :=+*+=:      %@@@@:.-*@@@@.   .::::::::::-.      =****+:      %@@@@@@++*@@@@@@@@@-
//  [email protected]@@@@@@      [email protected]@@@@@#   *%+.      [email protected]@@@@@@@@-    #@@@#    *@@@=   %@@@@@@@@@@@=     #@@@@@@%      @@@@@@#    -%@@@@@@%
//   #@@@@@@=      :@@@@@@   @@@@@=   [email protected]@@@%#%@@@@.   *@@@#   .%@@@.   @@@@@@@@@@@%     [email protected]@@@@@@@     [email protected]@@@@@=      #@@@@@@
//   :@@@@@@%       *@@@@@   #@@@@@   [email protected]@@@   #@@@-   [email protected]@@@  -%@@%:    @@@@#-:::::      %@@@:%@@@:    [email protected]@@@@@.      [email protected]@@@@%
//    *@@@@@@=      *@@@@%   [email protected]@@@@.  [email protected]@@#   :**+.   [email protected]@@@%@@@@#      @@@@+           [email protected]@@+ [email protected]@@-    [email protected]@@@@@       *@@@@@+
//     @@@@@@%     [email protected]@@@@=   [email protected]@@@@=  [email protected]@@#           [email protected]@@@@@@@@@*.    @@@@+           @@@@  :@@@+    *@@@@@*      [email protected]@@@@%
//     [email protected]@@@@@+:-*@@@@@@+    [email protected]@@@@*  [email protected]@@%  ==---:   [email protected]@@@==*@@@@@+   @@@@%**#*      [email protected]@@=   @@@#    #@@@@@-   .=%@@@@@*
//      #@@@@@@@@@@@@@@*      @@@@@%  :@@@@ :@@@@@@*   @@@@   .%@@@@:  @@@@@@@@@      %@@@    @@@@    @@@@@@@%%@@@@@@@%:
//      [email protected]@@@@@@@@@@@@@@%=    #@@@@@   @@@@ [email protected]@@@@@%   @@@%    :@@@@+  @@@@%===-     [email protected]@@%**[email protected]@@@   [email protected]@@@@@@@@@@@@@*-
//       [email protected]@@@@@%**#@@@@@@*   [email protected]@@@@:  %@@@:   #@@@@   #@@%     @@@@+  @@@@+         %@@@@@@@@@@@@:  :@@@@@@@@@@@@*
//        %@@@@%     %@@@@@:  :@@@@@=  *@@@+   %@@@%   *@@@    [email protected]@@@-  @@@@+        [email protected]@@@%***@@@@@=  [email protected]@@@@@:#@@@@@:
//        :@@@@@:    *@@@@@-   @@@@@#  :@@@@#+%@@@@*   [email protected]@@--=#@@@@#   @@@@@@@@@#   %@@@@-   [email protected]@@@*  [email protected]@@@@%  %@@@@@.
//         [email protected]@@@*  [email protected]@@@@#    #@@@@@   [email protected]@@@@@@@@#    [email protected]@@@@@@@@@=    @@@@@@@@@@  [email protected]@@@@    [email protected]@@@%  #@@@@@*  [email protected]@@@@%.
//          @@@@@@@@@@@@%=     -###*+    .+#@@%#+:      %@@@@%#+-      #%##%%%%#*  +%%%%+    -%%%%%  %@@@@@-   :@@@@@%
//          :%@@@@%#*+-.                                                                              ::---     :@@@@@%.
//                        .---:                                                                                  .-==++:
//                      =*+:.++-      :=.   ..  .:.  .---:    ::.    .::.       .         ....   ...:::::
//                     +##=  ##+ =*+- -==- ###: ##=  *#####-  ###  :######=   =###. ##########= *########-
//                     ####+-:   -###+##+ -+=+=.++. :##==###  ###  ###:.###.  +#*#* .-::###:... -###=---:
//                     -######.   .*###+  #######*  ==-  .=+  ###  ###  .--   ##=-#+    *##-     ###=-=-
//                   --   .###:    :##+  =##-####- .##= .*#* .===  -=+   === .##*=##-   :##*     =######.
//                  :##+  -##+    :##=  .##* *###. =#######- =###  +*+-.:--- :+*#+###:   *##:     ###=..
//                  -###+*##=    .##=   +##: -##+  +######:  =###: -#######: =+=: .::-   :##*     +##*::::....
//                   =*##*+.      .     .::   ::.  .::-::    .::.   :=+++=.  :==.  .**+   :-=:    .###########:

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/IBigBearSyndicate.sol";
import "../utils/Whitelists.sol";

error NotEnoughSupply();
error IncorrectEtherValue(uint256 expectedValue);
error PhaseNotStarted(uint256 startTime);
error PhaseOver(uint256 endTime);
error NotWhitelisted(address address_);
error InvalidAddress(address address_);
error InvalidTier(uint256 tier);
error MintAllowanceExceeded(address address_, uint256 allowance);
error MintLimitExceeded(uint256 limit);
error InsufficientBalance(uint256 balance, uint256 required);

/**
 * @notice This is a 2-phase minter contract that includes a allow list and public sale.
 * @dev This is a heavily modified version of the Forgotten Runes Warriors Minters contract.
 * @dev The contract can be found at https://etherscan.io/address/0xB4d9AcB0a6735058908E943e966867A266619fBD#code.
 */
contract BigBearSyndicateMinter is
	AccessControlUpgradeable,
	PausableUpgradeable,
	ReentrancyGuardUpgradeable
{
	// ------------------------------
	// 			V1 Variables
	// ------------------------------

	/// @notice The address of the BigBearSyndicate contract
	IBigBearSyndicate public bbs;

	/// @notice Tracks the total count of bears for sale
	uint256 public supplyLimit;

	/// @dev Used for incrementing the token IDs
	uint256 public currentTokenId;

	using Whitelists for Whitelists.MerkleProofWhitelist;

	/// @notice The start timestamp for the free mint
	uint256 public freeMintStartTime;

	/// @notice The start timestamp for the allow list sale
	uint256 public allowListStartTime;

	/// @notice The start timestamp for the public sale
	uint256 public publicStartTime;

	/// @notice The whitelist for the allow list sale
	Whitelists.MerkleProofWhitelist private allowListWhitelist;

	/// @notice The number of tokens that can be minted by an address through the allow list mint
	uint256 public allowListMints;

	/// @notice Tracks the number of tokens an address has minted through the allow list mint
	mapping(address => uint256) public addressToAllowListMints;

	/// @notice Tracks addresses that can still claim a free mint
	mapping(address => uint256) public addressToFreeMintClaim;

	/// @notice Tracks the number of tokens an address can mint during allow list mint if not the same as allowListMints
	mapping(address => uint256) public addressToPaidMints;

	/// @notice The maximum number of tokens that can be minted per transaction
	uint256 public mintLimit;

	/// @notice The address of the vault
	address payable public vault;

	/// @notice The price of a mint
	uint256 public price;

	/*
	 * DO NOT ADD OR REMOVE VARIABLES ABOVE THIS LINE. INSTEAD, CREATE A NEW VERSION SECTION BELOW.
	 * MOVE THIS COMMENT BLOCK TO THE END OF THE LATEST VERSION SECTION PRE-DEPLOYMENT.
	 */

	function initialize(IBigBearSyndicate bbs_) public initializer {
		// Call parent initializers
		__AccessControl_init();
		__Pausable_init();
		__ReentrancyGuard_init();

		// Set defaults
		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

		setSupplyLimit(5000);
		currentTokenId = 0;

		vault = payable(msg.sender);

		uint256 defaultStartTime = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

		setFreeMintStartTime(defaultStartTime);
		setAllowListStartTime(defaultStartTime);
		setPublicStartTime(defaultStartTime);

		allowListMints = 1;
		mintLimit = 20;
		price = 0.01337 ether;

		// Set constructor arguments
		setBigBearSyndicateAddress(bbs_);
	}

	/*
	 Timeline:
	 
	 freeMintSale    :|------------|
	 allowListSale   :			   |------------|
	 publicSale      :             				|------------|
	 */

	// ------------------------------
	// 		   Free Mint Sale
	// ------------------------------
	/**
	@notice Returns true if the free mint sale has started
	 */
	function isInFreeMintPhase() external view returns (bool) {
		return
			_hasStarted(freeMintStartTime) && !_hasStarted(allowListStartTime);
	}

	/**
	@notice Mint a free BigBearSyndicate
	*/
	function freeMint(uint256 numBears)
		external
		nonReentrant
		whenNotPaused
		inFreeMintPhase
		whenSupplyRemains(numBears)
		withinMintLimit(numBears)
	{
		uint256 mints = addressToFreeMintClaim[msg.sender];

		if (numBears > mints) {
			revert MintAllowanceExceeded(msg.sender, mints);
		}

		addressToFreeMintClaim[msg.sender] -= numBears;

		_mint(msg.sender, numBears);
	}

	function setFreeMintClaims(address user, uint256 mints)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		addressToFreeMintClaim[user] = mints;
	}

	/**
	 * @notice Sets the number of tokens an address can mint in a paid tier
	 * @param user address of the user
	 * @param mints uint256 of the number of BigBearSyndicate the user can mint
	 */
	function setPaidMints(address user, uint256 mints)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		addressToPaidMints[user] = mints;
	}

	// ------------------------------
	// 		   Allow List Sale
	// ------------------------------

	/**
	@notice Mint a BigBearSyndicate in the allow list phase (paid)
	@param numBears uint256 of the number of BigBearSyndicates to mint
	@param merkleProof bytes32[] of the merkle proof of the minting address
	*/
	function allowListMint(uint256 numBears, bytes32[] calldata merkleProof)
		external
		payable
		nonReentrant
		whenNotPaused
		inAllowListPhase
		onlyWhitelisted(msg.sender, merkleProof, allowListWhitelist)
		whenSupplyRemains(numBears)
		withinMintLimit(numBears)
	{
		uint256 paidMints = addressToPaidMints[msg.sender];
		if (paidMints > 0) {
			if (addressToAllowListMints[msg.sender] + numBears > paidMints) {
				revert MintAllowanceExceeded(msg.sender, paidMints);
			}
		} else {
			if (
				addressToAllowListMints[msg.sender] + numBears > allowListMints
			) {
				revert MintAllowanceExceeded(msg.sender, allowListMints);
			}
		}

		uint256 expectedValue = price * numBears;

		if (msg.value != expectedValue) {
			revert IncorrectEtherValue(expectedValue);
		}

		addressToAllowListMints[msg.sender] += numBears;

		_mint(msg.sender, numBears);
	}

	/**
    @notice Returns true it the user is included in the allow list whitelist
    @param user address of the user
    @param merkleProof uint256[] of the merkle proof of the user address
    */
	function isAllowListWhitelisted(
		address user,
		bytes32[] calldata merkleProof
	) external view returns (bool) {
		return allowListWhitelist.isWhitelisted(user, merkleProof);
	}

	/**
	@notice Returns true if the allow list sale has started
	 */
	function isInAllowListPhase() external view returns (bool) {
		return _hasStarted(allowListStartTime) && !_hasStarted(publicStartTime);
	}

	/**
	@notice Returns the root hash of the allow list Merkle tree
	 */
	function allowListMerkleRoot() external view returns (bytes32) {
		return allowListWhitelist.getRootHash();
	}

	/**
	 @notice Returns the number of allowlist mints remaining for the user
	 */
	function allowListMintsRemaining(address user)
		external
		view
		returns (uint256)
	{
		uint256 paidMints = addressToPaidMints[user];
		if (paidMints > 0) {
			return paidMints - addressToAllowListMints[user];
		}

		return allowListMints - addressToAllowListMints[user];
	}

	// ------------------------------
	// 			Public Sale
	// ------------------------------

	/**
	@notice Mint a BigBearSyndicate in the Public phase (paid)
	@param numBears uint256 of the number of BigBearSyndicates to mint
	*/
	function publicMint(uint256 numBears)
		external
		payable
		nonReentrant
		whenNotPaused
		inPublicPhase
		whenSupplyRemains(numBears)
		withinMintLimit(numBears)
	{
		uint256 expectedValue = price * numBears;

		if (msg.value != expectedValue) {
			revert IncorrectEtherValue(expectedValue);
		}

		_mint(msg.sender, numBears);
	}

	/**
	@notice Returns true if the public sale has started
	*/
	function isInPublicPhase() external view returns (bool) {
		return _hasStarted(publicStartTime);
	}

	// ------------------------------
	// 			  Minting
	// ------------------------------

	function _mint(address to, uint256 numBears) internal {
		for (uint256 i = 0; i < numBears; i++) {
			// Generate token id
			currentTokenId += 1;

			bbs.mint(to, currentTokenId);
		}
	}

	function availableSupply() external view returns (uint256) {
		return supplyLimit - currentTokenId;
	}

	// ------------------------------
	// 			  Pausing
	// ------------------------------

	function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
		_pause();
	}

	function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
		_unpause();
	}

	// ------------------------------
	// 			 Withdrawal
	// ------------------------------

	/**
	 @notice Withdraw funds to the vault
	 @param _amount uint256 the amount to withdraw
	 */
	function withdraw(uint256 _amount)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
		hasVault
	{
		if (address(this).balance < _amount) {
			revert InsufficientBalance(address(this).balance, _amount);
		}

		payable(vault).transfer(_amount);
	}

	/**
	 @notice Withdraw all funds to the vault
	 */
	function withdrawAll() external onlyRole(DEFAULT_ADMIN_ROLE) hasVault {
		if (address(this).balance < 1) {
			revert InsufficientBalance(address(this).balance, 1);
		}

		payable(vault).transfer(address(this).balance);
	}

	// ------------------------------
	// 			  Setters
	// ------------------------------

	/// @notice Sets the address of the BigBearSyndicate contract
	function setBigBearSyndicateAddress(IBigBearSyndicate bbs_)
		public
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		bbs = bbs_;
	}

	/// @notice Sets the number of available tokens
	function setSupplyLimit(uint256 supplyLimit_)
		public
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		supplyLimit = supplyLimit_;
	}

	/**
	@notice A convenient way to set phase times at once
	@param freeMintStartTime_ uint256 the free mint start time
	@param allowListStartTime_ uint256 the allow list start time
	@param publicStartTime_ uint256 the public sale start time
	*/
	function setPhaseTimes(
		uint256 freeMintStartTime_,
		uint256 allowListStartTime_,
		uint256 publicStartTime_
	) external onlyRole(DEFAULT_ADMIN_ROLE) {
		setFreeMintStartTime(freeMintStartTime_);
		setAllowListStartTime(allowListStartTime_);
		setPublicStartTime(publicStartTime_);
	}

	/**
	@notice Sets the allow list start time
	@param freeMintStartTime_ uint256 the allow list start time
	*/
	function setFreeMintStartTime(uint256 freeMintStartTime_)
		public
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		freeMintStartTime = freeMintStartTime_;
	}

	/**
	@notice Sets the allow list start time
	@param allowListStartTime_ uint256 the allow list start time
	*/
	function setAllowListStartTime(uint256 allowListStartTime_)
		public
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		allowListStartTime = allowListStartTime_;
	}

	/**
	@notice Sets the public start time
	@param publicStartTime_ uint256 the public sale start time
	*/
	function setPublicStartTime(uint256 publicStartTime_)
		public
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		publicStartTime = publicStartTime_;
	}

	/**
	@notice Sets the vault address
	@param vault_ address of the vault
	*/
	function setVaultAddress(address payable vault_)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		vault = vault_;
	}

	/**
	@notice Sets the price of a mint
	@param price_ uint256 the price of a mint
	*/
	function setPrice(uint256 price_) external onlyRole(DEFAULT_ADMIN_ROLE) {
		price = price_;
	}

	/**
	 * @notice Sets the number of BigBearSyndicates that can be minted in the allow list phase
	 * @param mints uint256 the number of BigBearSyndicates that can be minted in the allow list phase
	 */
	function setAllowListMints(uint256 mints)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		allowListMints = mints;
	}

	/**
	 * @notice Sets the number of BigBearSyndicates that can be minted in one transaction
	 * @param limit uint256 the number of BigBearSyndicates that can be minted in one transaction
	 */
	function setMintLimit(uint256 limit) external onlyRole(DEFAULT_ADMIN_ROLE) {
		mintLimit = limit;
	}

	/**
	@notice Sets the root hash of the allow list Merkle tree
	@param rootHash bytes32 the root hash of the allow list Merkle tree
	*/
	function setAllowListMerkleRoot(bytes32 rootHash)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		allowListWhitelist.setRootHash(rootHash);
	}

	// ------------------------------
	// 			  Modifiers
	// ------------------------------

	/**
	@dev Modifier to make a function callable only when there is enough bears left for sale
	
	Requirements:

	- Number of bears sold must be less than the maximum for sale
	*/
	modifier whenSupplyRemains(uint256 mintAmount) {
		if (currentTokenId + mintAmount > supplyLimit) {
			revert NotEnoughSupply();
		}
		_;
	}

	/**
    @dev Modifier to make a function callable only when in the allow list phase

    Requirements:

    - Current block timestamp must be greater than the allow list start time
    */
	modifier inFreeMintPhase() {
		if (!_hasStarted(freeMintStartTime)) {
			revert PhaseNotStarted(freeMintStartTime);
		}
		if (_hasStarted(allowListStartTime)) {
			revert PhaseOver(allowListStartTime);
		}
		_;
	}

	/**
    @dev Modifier to make a function callable only when in the allow list phase

    Requirements:

    - Current block timestamp must be greater than the allow list start time
    */
	modifier inAllowListPhase() {
		if (!_hasStarted(allowListStartTime)) {
			revert PhaseNotStarted(allowListStartTime);
		}
		if (_hasStarted(publicStartTime)) {
			revert PhaseOver(publicStartTime);
		}
		_;
	}

	/**
    @dev Modifier to make a function callable only when in the public sale phase

    Requirements:

    - Current block timestamp must be greater than the public sale start time
    */
	modifier inPublicPhase() {
		if (!_hasStarted(publicStartTime)) {
			revert PhaseNotStarted(publicStartTime);
		}
		_;
	}

	/**
    @dev Modifier to make a function callable only when the user is included in the allow list whitelist

    Requirements:

    - Merkle proof of user address must be valid
    */
	modifier onlyWhitelisted(
		address user,
		bytes32[] calldata merkleProof,
		Whitelists.MerkleProofWhitelist storage whitelist
	) {
		if (!whitelist.isWhitelisted(user, merkleProof)) {
			revert NotWhitelisted(user);
		}
		_;
	}

	/**
    @dev Modifier to make a function callable only when the vault address is valid

    Requirements:

    - The vault must be a non-zero address
    */
	modifier hasVault() {
		if (vault == address(0)) {
			revert InvalidAddress(vault);
		}
		_;
	}

	/**
    @dev Modifier to make a function callable only when the requested number of BigBearSyndicates is valid
    Requirements:

    - The requested number of BigBearSyndicates must be less than or equal to mint limit
    */
	modifier withinMintLimit(uint256 numBears) {
		if (numBears > mintLimit) {
			revert MintLimitExceeded(mintLimit);
		}
		_;
	}

	/**
	 @notice Returns true if the start time has passed
	 @param startTime uint256 of the start time
	 */
	function _hasStarted(uint256 startTime) internal view returns (bool) {
		return block.timestamp > startTime;
	}
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

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
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

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
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 * Copyright (c) 2022 Mighty Bear Games
 */

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IBigBearSyndicate is IERC721Upgradeable {
	function mint(address to, uint256 tokenId) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library Whitelists {
	// Inspired by https://medium.com/@ItsCuzzo/using-merkle-trees-for-nft-whitelists-523b58ada3f9
	struct MerkleProofWhitelist {
		bytes32 _rootHash;
	}

	function getRootHash(MerkleProofWhitelist storage whitelist)
		internal
		view
		returns (bytes32)
	{
		return whitelist._rootHash;
	}

	function setRootHash(
		MerkleProofWhitelist storage whitelist,
		bytes32 _rootHash
	) internal {
		whitelist._rootHash = _rootHash;
	}

	function isWhitelisted(
		MerkleProofWhitelist storage whitelist,
		address user,
		bytes32[] calldata proof
	) internal view returns (bool) {
		bytes32 leaf = keccak256(abi.encodePacked(user));

		return MerkleProof.verify(proof, whitelist._rootHash, leaf);
	}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
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
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
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
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
interface IERC165Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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