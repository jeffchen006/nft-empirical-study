//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

// import 'hardhat/console.sol';

import '@openzeppelin/contracts/GSN/Context.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './interfaces/IERC20Burnable.sol';
import './interfaces/IOven.sol';
import { HarvestVaultAdapter } from './adapters/HarvestVaultAdapter.sol';
import { HarvestVault } from './libraries/HarvestVault.sol';
import './libraries/Convert.sol';

contract OvenB is Context, Convert {
	using SafeMath for uint256;
	using SafeERC20 for IERC20Burnable;
	using Address for address;
	using HarvestVault for HarvestVault.Data;
	using HarvestVault for HarvestVault.List;

	address public constant ZERO_ADDRESS = address(0);
	uint256 public EXCHANGE_PERIOD;

	address public friesToken;
	address public token;

	mapping(address => uint256) public depositedFriesTokens;
	mapping(address => uint256) public tokensInBucket;
	mapping(address => uint256) public realisedTokens;
	mapping(address => uint256) public lastDividendPoints;

	mapping(address => bool) public userIsKnown;
	mapping(uint256 => address) public userList;
	uint256 public nextUser;

	uint256 public totalSupplyFriesTokens;
	uint256 public buffer;
	uint256 public lastDepositBlock;

	///@dev values needed to calculate the distribution of base asset in proportion for fUSDs staked
	uint256 public pointMultiplier = 10e18;

	uint256 public totalDividendPoints;
	uint256 public unclaimedDividends;

	/// @dev alchemist addresses whitelisted
	mapping(address => bool) public whiteList;

	/// @dev addresses whitelisted to run keepr jobs (harvest)
	mapping(address => bool) public keepers;

	/// @dev The threshold above which excess funds will be deployed to yield farming activities
	uint256 public plantableThreshold = 5000000000000000000000000; // 5mm

	/// @dev The % margin to trigger planting or recalling of funds
	uint256 public plantableMargin = 5;

	/// @dev The address of the account which currently has administrative capabilities over this contract.
	address public governance;

	/// @dev The address of the pending governance.
	address public pendingGovernance;

	/// @dev The address of the account which can perform emergency activities
	address public sentinel;

	/// @dev A flag indicating if deposits and flushes should be halted and if all parties should be able to recall
	/// from the active vault.
	bool public pause;

	/// @dev The address of the contract which will receive fees.
	address public rewards;

	/// @dev A mapping of adapter addresses to keep track of vault adapters that have already been added
	mapping(HarvestVaultAdapter => bool) public adapters;

	/// @dev A list of all of the vaults. The last element of the list is the vault that is currently being used for
	/// deposits and withdraws. VaultWithIndirections before the last element are considered inactive and are expected to be cleared.
	HarvestVault.List private _vaults;

	/// @dev make sure the contract is only initialized once.
	bool public initialized;

	/// @dev mapping of user account to the last block they acted
	mapping(address => uint256) public lastUserAction;

	/// @dev number of blocks to delay between allowed user actions
	uint256 public minUserActionDelay;

	event GovernanceUpdated(address governance);

	event PendingGovernanceUpdated(address pendingGovernance);

	event SentinelUpdated(address sentinel);

	event ovenPeriodUpdated(uint256 newTransmutationPeriod);

	event TokenClaimed(address claimant, address token, uint256 amountClaimed);

	event AlUsdStaked(address staker, uint256 amountStaked);

	event AlUsdUnstaked(address staker, uint256 amountUnstaked);

	event Transmutation(address transmutedTo, uint256 amountTransmuted);

	event ForcedTransmutation(address transmutedBy, address transmutedTo, uint256 amountTransmuted);

	event Distribution(address origin, uint256 amount);

	event WhitelistSet(address whitelisted, bool state);

	event KeepersSet(address[] keepers, bool[] states);

	event PlantableThresholdUpdated(uint256 plantableThreshold);

	event PlantableMarginUpdated(uint256 plantableMargin);

	event MinUserActionDelayUpdated(uint256 minUserActionDelay);

	event ActiveVaultUpdated(HarvestVaultAdapter indexed adapter);

	event PauseUpdated(bool status);

	event FundsRecalled(uint256 indexed vaultId, uint256 withdrawnAmount, uint256 decreasedValue);

	event FundsHarvested(uint256 withdrawnAmount, uint256 decreasedValue);

	event RewardsUpdated(address treasury);

	event MigrationComplete(address migrateTo, uint256 fundsMigrated);

	constructor(
		address _fUSD,
		address _token,
		address _governance
	) public {
		require(_governance != ZERO_ADDRESS, 'oven: 0 gov');
		governance = _governance;
		friesToken = _fUSD;
		token = _token;
		EXCHANGE_PERIOD = 500000;
		minUserActionDelay = 1;
		pause = true;
	}

	///@return displays the user's share of the pooled fUSDs.
	function dividendsOwing(address account) public view returns (uint256) {
		uint256 newDividendPoints = totalDividendPoints.sub(lastDividendPoints[account]);
		return depositedFriesTokens[account].mul(newDividendPoints).div(pointMultiplier);
	}

	/// @dev Checks that caller is not a eoa.
	///
	/// This is used to prevent contracts from interacting.
	modifier noContractAllowed() {
		require(!address(msg.sender).isContract() && msg.sender == tx.origin, 'no contract calls');
		_;
	}

	///@dev modifier to fill the bucket and keep bookkeeping correct incase of increase/decrease in shares
	modifier updateAccount(address account) {
		uint256 owing = dividendsOwing(account);
		if (owing > 0) {
			unclaimedDividends = unclaimedDividends.sub(owing);
			tokensInBucket[account] = tokensInBucket[account].add(owing);
		}
		lastDividendPoints[account] = totalDividendPoints;
		_;
	}
	///@dev modifier add users to userlist. Users are indexed in order to keep track of when a bond has been filled
	modifier checkIfNewUser() {
		if (!userIsKnown[msg.sender]) {
			userList[nextUser] = msg.sender;
			userIsKnown[msg.sender] = true;
			nextUser++;
		}
		_;
	}

	///@dev run the phased distribution of the buffered funds
	modifier runPhasedDistribution() {
		uint256 _lastDepositBlock = lastDepositBlock;
		uint256 _currentBlock = block.number;
		uint256 _toDistribute = 0;
		uint256 _buffer = buffer;

		// check if there is something in bufffer
		if (_buffer > 0) {
			// NOTE: if last deposit was updated in the same block as the current call
			// then the below logic gates will fail

			//calculate diffrence in time
			uint256 deltaTime = _currentBlock.sub(_lastDepositBlock);

			// distribute all if bigger than timeframe
			if (deltaTime >= EXCHANGE_PERIOD) {
				_toDistribute = _buffer;
			} else {
				//needs to be bigger than 0 cuzz solidity no decimals
				if (_buffer.mul(deltaTime) > EXCHANGE_PERIOD) {
					_toDistribute = _buffer.mul(deltaTime).div(EXCHANGE_PERIOD);
				}
			}

			// factually allocate if any needs distribution
			if (_toDistribute > 0) {
				// remove from buffer
				buffer = _buffer.sub(_toDistribute);

				// increase the allocation
				increaseAllocations(_toDistribute);
			}
		}

		// current timeframe is now the last
		lastDepositBlock = _currentBlock;
		_;
	}

	/// @dev A modifier which checks if whitelisted for minting.
	modifier onlyWhitelisted() {
		require(whiteList[msg.sender], 'oven: !whitelisted');
		_;
	}

	/// @dev A modifier which checks if caller is a keepr.
	modifier onlyKeeper() {
		require(keepers[msg.sender], 'oven: !keeper');
		_;
	}

	/// @dev Checks that the current message sender or caller is the governance address.
	///
	///
	modifier onlyGov() {
		require(msg.sender == governance, 'oven: !governance');
		_;
	}

	/// @dev checks that the block delay since a user's last action is longer than the minium delay
	///
	modifier ensureUserActionDelay() {
		require(block.number.sub(lastUserAction[msg.sender]) >= minUserActionDelay, 'action delay not met');
		lastUserAction[msg.sender] = block.number;
		_;
	}

	///@dev set the transmutationPeriod variable
	///
	/// sets the length (in blocks) of one full distribution phase
	function setExchangePeriod(uint256 newTransmutationPeriod) public onlyGov {
		EXCHANGE_PERIOD = newTransmutationPeriod;
		emit ovenPeriodUpdated(EXCHANGE_PERIOD);
	}

	///@dev claims the base token after it has been transmuted
	///
	///This function reverts if there is no realisedToken balance
	function claim() public noContractAllowed {
		address sender = msg.sender;
		require(realisedTokens[sender] > 0);
		uint256 value = realisedTokens[sender];
		realisedTokens[sender] = 0;
		ensureSufficientFundsExistLocally(value);
		IERC20Burnable(token).safeTransfer(sender, value);
		emit TokenClaimed(sender, token, value);
	}

	///@dev Withdraws staked fUSDs from the oven
	///
	/// This function reverts if you try to draw more tokens than you deposited
	///
	///@param amount the amount of fUSDs to unstake
	function unstake(uint256 amount) public noContractAllowed runPhasedDistribution updateAccount(msg.sender) {
		// by calling this function before transmuting you forfeit your gained allocation
		address sender = msg.sender;

		uint256 tokenAmount = convertTokenAmount(friesToken, token, amount);
		amount = convertTokenAmount(token, friesToken, tokenAmount);
		require(tokenAmount > 0, 'The amount is too small');

		require(depositedFriesTokens[sender] >= amount, 'oven: unstake amount exceeds deposited amount');
		depositedFriesTokens[sender] = depositedFriesTokens[sender].sub(amount);
		totalSupplyFriesTokens = totalSupplyFriesTokens.sub(amount);
		IERC20Burnable(friesToken).safeTransfer(sender, amount);
		emit AlUsdUnstaked(sender, amount);
	}

	///@dev Deposits fUSDs into the oven
	///
	///@param amount the amount of fUSDs to stake
	function stake(uint256 amount)
		public
		noContractAllowed
		ensureUserActionDelay
		runPhasedDistribution
		updateAccount(msg.sender)
		checkIfNewUser
	{
		require(!pause, 'emergency pause enabled');

		uint256 tokenAmount = convertTokenAmount(friesToken, token, amount);
		amount = convertTokenAmount(token, friesToken, tokenAmount);
		require(tokenAmount > 0, 'The amount is too small');

		// requires approval of fUSD first
		address sender = msg.sender;
		//require tokens transferred in;
		IERC20Burnable(friesToken).safeTransferFrom(sender, address(this), amount);
		totalSupplyFriesTokens = totalSupplyFriesTokens.add(amount);
		depositedFriesTokens[sender] = depositedFriesTokens[sender].add(amount);
		emit AlUsdStaked(sender, amount);
	}

	/// @dev Converts the staked fUSDs to the base tokens in amount of the sum of pendingdivs and tokensInBucket
	///
	/// once the fUSD has been converted, it is burned, and the base token becomes realisedTokens which can be recieved using claim()
	///
	/// reverts if there are no pendingdivs or tokensInBucket
	function exchange() public noContractAllowed ensureUserActionDelay runPhasedDistribution updateAccount(msg.sender) {
		address sender = msg.sender;
		uint256 pendingz = tokensInBucket[sender];
		uint256 pendingzToFries = convertTokenAmount(token, friesToken, pendingz); // fries
		uint256 diff;

		require(pendingz > 0 && pendingzToFries > 0, 'need to have pending in bucket');

		tokensInBucket[sender] = 0;

		if (pendingzToFries > depositedFriesTokens[sender]) {
			diff = convertTokenAmount(friesToken, token, pendingzToFries.sub(depositedFriesTokens[sender]));
			// remove overflow
			pendingzToFries = depositedFriesTokens[sender];
			pendingz = convertTokenAmount(friesToken, token, pendingzToFries);
			require(pendingz > 0 && pendingzToFries > 0, 'need to have pending in bucket');
		}

		// decrease fUSD
		depositedFriesTokens[sender] = depositedFriesTokens[sender].sub(pendingzToFries);

		// BURN fUSD
		IERC20Burnable(friesToken).burn(pendingzToFries);

		// adjust total
		totalSupplyFriesTokens = totalSupplyFriesTokens.sub(pendingzToFries);

		// reallocate overflow
		increaseAllocations(diff);

		// add payout
		realisedTokens[sender] = realisedTokens[sender].add(pendingz);

		emit Transmutation(sender, pendingz);
	}

	/// @dev Executes transmute() on another account that has had more base tokens allocated to it than fUSDs staked.
	///
	/// The caller of this function will have the surlus base tokens credited to their tokensInBucket balance, rewarding them for performing this action
	///
	/// This function reverts if the address to transmute is not over-filled.
	///
	/// @param toTransmute address of the account you will force transmute.
	function forceExchange(address toTransmute)
		public
		noContractAllowed
		ensureUserActionDelay
		runPhasedDistribution
		updateAccount(msg.sender)
		updateAccount(toTransmute)
		checkIfNewUser
	{
		//load into memory
		address sender = msg.sender;
		uint256 pendingz = tokensInBucket[toTransmute];
		uint256 pendingzToFries = convertTokenAmount(token, friesToken, pendingz);
		// check restrictions
		require(pendingzToFries > depositedFriesTokens[toTransmute], 'oven: !overflow');

		// empty bucket
		tokensInBucket[toTransmute] = 0;

		address _toTransmute = toTransmute;

		// calculaate diffrence
		uint256 diff = convertTokenAmount(friesToken, token, pendingzToFries.sub(depositedFriesTokens[_toTransmute]));

		// remove overflow
		pendingzToFries = depositedFriesTokens[_toTransmute];

		// decrease fUSD
		depositedFriesTokens[_toTransmute] = 0;

		// BURN fUSD
		IERC20Burnable(friesToken).burn(pendingzToFries);

		// adjust total
		totalSupplyFriesTokens = totalSupplyFriesTokens.sub(pendingzToFries);

		// reallocate overflow
		tokensInBucket[sender] = tokensInBucket[sender].add(diff);

		uint256 payout = convertTokenAmount(friesToken, token, pendingzToFries);

		// add payout
		realisedTokens[_toTransmute] = realisedTokens[_toTransmute].add(payout);

		uint256 value = realisedTokens[_toTransmute];

		ensureSufficientFundsExistLocally(value);

		// force payout of realised tokens of the toTransmute address
		realisedTokens[_toTransmute] = 0;
		IERC20Burnable(token).safeTransfer(_toTransmute, value);
		emit ForcedTransmutation(sender, _toTransmute, value);
	}

	/// @dev Transmutes and unstakes all fUSDs
	///
	/// This function combines the transmute and unstake functions for ease of use
	function exit() public noContractAllowed {
		exchange();
		uint256 toWithdraw = depositedFriesTokens[msg.sender];
		unstake(toWithdraw);
	}

	/// @dev Transmutes and claims all converted base tokens.
	///
	/// This function combines the transmute and claim functions while leaving your remaining fUSDs staked.
	function transmuteAndClaim() public noContractAllowed {
		exchange();
		claim();
	}

	/// @dev Transmutes, claims base tokens, and withdraws fUSDs.
	///
	/// This function helps users to exit the oven contract completely after converting their fUSDs to the base pair.
	function transmuteClaimAndWithdraw() public noContractAllowed {
		exchange();
		claim();
		uint256 toWithdraw = depositedFriesTokens[msg.sender];
		unstake(toWithdraw);
	}

	/// @dev Distributes the base token proportionally to all fUSD stakers.
	///
	/// This function is meant to be called by the Alchemist contract for when it is sending yield to the oven.
	/// Anyone can call this and add funds, idk why they would do that though...
	///
	/// @param origin the account that is sending the tokens to be distributed.
	/// @param amount the amount of base tokens to be distributed to the oven.
	function distribute(address origin, uint256 amount) public onlyWhitelisted runPhasedDistribution {
		require(!pause, 'emergency pause enabled');
		IERC20Burnable(token).safeTransferFrom(origin, address(this), amount);
		buffer = buffer.add(amount);
		_plantOrRecallExcessFunds();
		emit Distribution(origin, amount);
	}

	/// @dev Allocates the incoming yield proportionally to all fUSD stakers.
	///
	/// @param amount the amount of base tokens to be distributed in the oven.
	function increaseAllocations(uint256 amount) internal {
		if (totalSupplyFriesTokens > 0 && amount > 0) {
			totalDividendPoints = totalDividendPoints.add(amount.mul(pointMultiplier).div(totalSupplyFriesTokens));
			unclaimedDividends = unclaimedDividends.add(amount);
		} else {
			buffer = buffer.add(amount);
		}
	}

	/// @dev Gets the status of a user's staking position.
	///
	/// The total amount allocated to a user is the sum of pendingdivs and inbucket.
	///
	/// @param user the address of the user you wish to query.
	///
	/// returns user status

	function userInfo(address user)
		public
		view
		returns (
			uint256 depositedToken,
			uint256 pendingdivs,
			uint256 inbucket,
			uint256 realised
		)
	{
		uint256 _depositedToken = depositedFriesTokens[user];
		uint256 _toDistribute = buffer.mul(block.number.sub(lastDepositBlock)).div(EXCHANGE_PERIOD);
		if (block.number.sub(lastDepositBlock) > EXCHANGE_PERIOD) {
			_toDistribute = buffer;
		}
		uint256 _pendingdivs = 0;

		if (totalSupplyFriesTokens > 0) {
			_pendingdivs = _toDistribute.mul(depositedFriesTokens[user]).div(totalSupplyFriesTokens);
		}
		uint256 _inbucket = tokensInBucket[user].add(dividendsOwing(user));
		uint256 _realised = realisedTokens[user];
		return (_depositedToken, _pendingdivs, _inbucket, _realised);
	}

	/// @dev Gets the status of multiple users in one call
	///
	/// This function is used to query the contract to check for
	/// accounts that have overfilled positions in order to check
	/// who can be force transmuted.
	///
	/// @param from the first index of the userList
	/// @param to the last index of the userList
	///
	/// returns the userList with their staking status in paginated form.
	function getMultipleUserInfo(uint256 from, uint256 to)
		public
		view
		returns (address[] memory theUserList, uint256[] memory theUserData)
	{
		uint256 i = from;
		uint256 delta = to - from;
		address[] memory _theUserList = new address[](delta); //user
		uint256[] memory _theUserData = new uint256[](delta * 2); //deposited-bucket
		uint256 y = 0;
		uint256 _toDistribute = buffer.mul(block.number.sub(lastDepositBlock)).div(EXCHANGE_PERIOD);
		if (block.number.sub(lastDepositBlock) > EXCHANGE_PERIOD) {
			_toDistribute = buffer;
		}
		for (uint256 x = 0; x < delta; x += 1) {
			_theUserList[x] = userList[i];
			_theUserData[y] = depositedFriesTokens[userList[i]];
			_theUserData[y + 1] = dividendsOwing(userList[i]).add(tokensInBucket[userList[i]]).add(
				_toDistribute.mul(depositedFriesTokens[userList[i]]).div(totalSupplyFriesTokens)
			);
			y += 2;
			i += 1;
		}
		return (_theUserList, _theUserData);
	}

	/// @dev Gets info on the buffer
	///
	/// This function is used to query the contract to get the
	/// latest state of the buffer
	///
	/// @return _toDistribute the amount ready to be distributed
	/// @return _deltaBlocks the amount of time since the last phased distribution
	/// @return _buffer the amount in the buffer
	function bufferInfo()
		public
		view
		returns (
			uint256 _toDistribute,
			uint256 _deltaBlocks,
			uint256 _buffer
		)
	{
		_deltaBlocks = block.number.sub(lastDepositBlock);
		_buffer = buffer;
		_toDistribute = _buffer.mul(_deltaBlocks).div(EXCHANGE_PERIOD);
	}

	/// @dev Sets the pending governance.
	///
	/// This function reverts if the new pending governance is the zero address or the caller is not the current
	/// governance. This is to prevent the contract governance being set to the zero address which would deadlock
	/// privileged contract functionality.
	///
	/// @param _pendingGovernance the new pending governance.
	function setPendingGovernance(address _pendingGovernance) external onlyGov {
		require(_pendingGovernance != ZERO_ADDRESS, 'oven: 0 gov');

		pendingGovernance = _pendingGovernance;

		emit PendingGovernanceUpdated(_pendingGovernance);
	}

	/// @dev Accepts the role as governance.
	///
	/// This function reverts if the caller is not the new pending governance.
	function acceptGovernance() external {
		require(msg.sender == pendingGovernance, '!pendingGovernance');
		address _pendingGovernance = pendingGovernance;
		governance = _pendingGovernance;

		emit GovernanceUpdated(_pendingGovernance);
	}

	/// @dev Sets the whitelist
	///
	/// This function reverts if the caller is not governance
	///
	/// @param _toWhitelist the address to alter whitelist permissions.
	/// @param _state the whitelist state.
	function setWhitelist(address _toWhitelist, bool _state) external onlyGov {
		whiteList[_toWhitelist] = _state;
		emit WhitelistSet(_toWhitelist, _state);
	}

	/// @dev Sets the keeper list
	///
	/// This function reverts if the caller is not governance
	///
	/// @param _keepers the accounts to set states for.
	/// @param _states the accounts states.
	function setKeepers(address[] calldata _keepers, bool[] calldata _states) external onlyGov {
		uint256 n = _keepers.length;
		for (uint256 i = 0; i < n; i++) {
			keepers[_keepers[i]] = _states[i];
		}
		emit KeepersSet(_keepers, _states);
	}

	/// @dev Initializes the contract.
	///
	/// This function checks that the oven and rewards have been set and sets up the active vault.
	///
	/// @param _adapter the vault adapter of the active vault.
	function initialize(HarvestVaultAdapter _adapter) external onlyGov {
		require(!initialized, 'oven: already initialized');
		require(rewards != ZERO_ADDRESS, 'oven: cannot initialize rewards address to 0x0');

		_updateActiveVault(_adapter);

		initialized = true;
	}

	function migrate(HarvestVaultAdapter _adapter) external onlyGov {
		_updateActiveVault(_adapter);
	}

	/// @dev Updates the active vault.
	///
	/// This function reverts if the vault adapter is the zero address, if the token that the vault adapter accepts
	/// is not the token that this contract defines as the parent asset, or if the contract has not yet been initialized.
	///
	/// @param _adapter the adapter for the new active vault.
	function _updateActiveVault(HarvestVaultAdapter _adapter) internal {
		require(_adapter != HarvestVaultAdapter(ZERO_ADDRESS), 'oven: active vault address cannot be 0x0.');
		require(address(_adapter.token()) == token, 'oven.vault: token mismatch.');
		require(!adapters[_adapter], 'Adapter already in use');
		adapters[_adapter] = true;
		_vaults.push(HarvestVault.Data({ adapter: _adapter, totalDeposited: 0 }));

		emit ActiveVaultUpdated(_adapter);
	}

	/// @dev Gets the number of vaults in the vault list.
	///
	/// @return the vault count.
	function vaultCount() external view returns (uint256) {
		return _vaults.length();
	}

	/// @dev Get the adapter of a vault.
	///
	/// @param _vaultId the identifier of the vault.
	///
	/// @return the vault adapter.
	function getVaultAdapter(uint256 _vaultId) external view returns (address) {
		HarvestVault.Data storage _vault = _vaults.get(_vaultId);
		return address(_vault.adapter);
	}

	/// @dev Get the total amount of the parent asset that has been deposited into a vault.
	///
	/// @param _vaultId the identifier of the vault.
	///
	/// @return the total amount of deposited tokens.
	function getVaultTotalDeposited(uint256 _vaultId) external view returns (uint256) {
		HarvestVault.Data storage _vault = _vaults.get(_vaultId);
		return _vault.totalDeposited;
	}

	/// @dev Recalls funds from active vault if less than amt exist locally
	///
	/// @param amt amount of funds that need to exist locally to fulfill pending request
	function ensureSufficientFundsExistLocally(uint256 amt) internal {
		uint256 currentBal = IERC20Burnable(token).balanceOf(address(this));
		if (currentBal < amt) {
			uint256 diff = amt - currentBal;
			// get enough funds from active vault to replenish local holdings & fulfill claim request
			_recallExcessFundsFromActiveVault(plantableThreshold.add(diff));
		}
	}

	/// @dev Recalls all planted funds from a target vault
	///
	/// @param _vaultId the id of the vault from which to recall funds
	function recallAllFundsFromVault(uint256 _vaultId) external {
		require(
			pause && (msg.sender == governance || msg.sender == sentinel),
			'oven: not paused, or not governance or sentinel'
		);
		_recallAllFundsFromVault(_vaultId);
	}

	/// @dev Recalls all planted funds from a target vault
	///
	/// @param _vaultId the id of the vault from which to recall funds
	function _recallAllFundsFromVault(uint256 _vaultId) internal {
		HarvestVault.Data storage _vault = _vaults.get(_vaultId);
		(uint256 _withdrawnAmount, uint256 _decreasedValue) = _vault.withdrawAll(address(this));
		emit FundsRecalled(_vaultId, _withdrawnAmount, _decreasedValue);
	}

	/// @dev Recalls planted funds from a target vault
	///
	/// @param _vaultId the id of the vault from which to recall funds
	/// @param _amount the amount of funds to recall
	function recallFundsFromVault(uint256 _vaultId, uint256 _amount) external {
		require(
			pause && (msg.sender == governance || msg.sender == sentinel),
			'oven: not paused, or not governance or sentinel'
		);
		_recallFundsFromVault(_vaultId, _amount);
	}

	/// @dev Recalls planted funds from a target vault
	///
	/// @param _vaultId the id of the vault from which to recall funds
	/// @param _amount the amount of funds to recall
	function _recallFundsFromVault(uint256 _vaultId, uint256 _amount) internal {
		HarvestVault.Data storage _vault = _vaults.get(_vaultId);
		(uint256 _withdrawnAmount, uint256 _decreasedValue) = _vault.withdraw(address(this), _amount);
		emit FundsRecalled(_vaultId, _withdrawnAmount, _decreasedValue);
	}

	/// @dev Recalls planted funds from the active vault
	///
	/// @param _amount the amount of funds to recall
	function _recallFundsFromActiveVault(uint256 _amount) internal {
		_recallFundsFromVault(_vaults.lastIndex(), _amount);
	}

	/// @dev Plants or recalls funds from the active vault
	///
	/// This function plants excess funds in an external vault, or recalls them from the external vault
	/// Should only be called as part of distribute()
	function _plantOrRecallExcessFunds() internal {
		// check if the oven holds more funds than plantableThreshold
		uint256 bal = IERC20Burnable(token).balanceOf(address(this));
		uint256 marginVal = plantableThreshold.mul(plantableMargin).div(100);
		if (bal > plantableThreshold.add(marginVal)) {
			uint256 plantAmt = bal - plantableThreshold;
			// if total funds above threshold, send funds to vault
			HarvestVault.Data storage _activeVault = _vaults.last();
			_activeVault.deposit(plantAmt);
		} else if (bal < plantableThreshold.sub(marginVal)) {
			// if total funds below threshold, recall funds from vault
			// first check that there are enough funds in vault
			uint256 harvestAmt = plantableThreshold - bal;
			_recallExcessFundsFromActiveVault(harvestAmt);
		}
	}

	/// @dev Recalls up to the harvestAmt from the active vault
	///
	/// This function will recall less than harvestAmt if only less is available
	///
	/// @param _recallAmt the amount to harvest from the active vault
	function _recallExcessFundsFromActiveVault(uint256 _recallAmt) internal {
		HarvestVault.Data storage _activeVault = _vaults.last();
		uint256 activeVaultVal = _activeVault.totalValue();
		if (activeVaultVal < _recallAmt) {
			_recallAmt = activeVaultVal;
		}
		if (_recallAmt > 0) {
			_recallFundsFromActiveVault(_recallAmt);
		}
	}

	/// @dev Sets the address of the sentinel
	///
	/// @param _sentinel address of the new sentinel
	function setSentinel(address _sentinel) external onlyGov {
		require(_sentinel != ZERO_ADDRESS, 'oven: sentinel address cannot be 0x0.');
		sentinel = _sentinel;
		emit SentinelUpdated(_sentinel);
	}

	/// @dev Sets the threshold of total held funds above which excess funds will be planted in yield farms.
	///
	/// This function reverts if the caller is not the current governance.
	///
	/// @param _plantableThreshold the new plantable threshold.
	function setPlantableThreshold(uint256 _plantableThreshold) external onlyGov {
		plantableThreshold = _plantableThreshold;
		emit PlantableThresholdUpdated(_plantableThreshold);
	}

	/// @dev Sets the plantableThreshold margin for triggering the planting or recalling of funds on harvest
	///
	/// This function reverts if the caller is not the current governance.
	///
	/// @param _plantableMargin the new plantable margin.
	function setPlantableMargin(uint256 _plantableMargin) external onlyGov {
		plantableMargin = _plantableMargin;
		emit PlantableMarginUpdated(_plantableMargin);
	}

	/// @dev Sets the minUserActionDelay
	///
	/// This function reverts if the caller is not the current governance.
	///
	/// @param _minUserActionDelay the new min user action delay.
	function setMinUserActionDelay(uint256 _minUserActionDelay) external onlyGov {
		minUserActionDelay = _minUserActionDelay;
		emit MinUserActionDelayUpdated(_minUserActionDelay);
	}

	/// @dev Sets if the contract should enter emergency exit mode.
	///
	/// There are 2 main reasons to pause:
	///     1. Need to shut down deposits in case of an emergency in one of the vaults
	///     2. Need to migrate to a new oven
	///
	/// While the oven is paused, deposit() and distribute() are disabled
	///
	/// @param _pause if the contract should enter emergency exit mode.
	function setPause(bool _pause) external {
		require(msg.sender == governance || msg.sender == sentinel, '!(gov || sentinel)');
		pause = _pause;
		emit PauseUpdated(_pause);
	}

	/// @dev Harvests yield from a vault.
	///
	/// @param _vaultId the identifier of the vault to harvest from.
	///
	/// @return the amount of funds that were harvested from the vault.
	function harvest(uint256 _vaultId) external onlyKeeper returns (uint256, uint256) {
		HarvestVault.Data storage _vault = _vaults.get(_vaultId);

		(uint256 _harvestedAmount, uint256 _decreasedValue) = _vault.harvest(rewards);

		emit FundsHarvested(_harvestedAmount, _decreasedValue);

		return (_harvestedAmount, _decreasedValue);
	}

	/// @dev Rebalance the funds
	function plantOrRecallExcessFunds() external onlyKeeper {
		_plantOrRecallExcessFunds();
	}

	/// @dev Sets the rewards contract.
	///
	/// This function reverts if the new rewards contract is the zero address or the caller is not the current governance.
	///
	/// @param _rewards the new rewards contract.
	function setRewards(address _rewards) external onlyGov {
		// Check that the rewards address is not the zero address. Setting the rewards to the zero address would break
		// transfers to the address because of `safeTransfer` checks.
		require(_rewards != ZERO_ADDRESS, 'oven: rewards address cannot be 0x0.');

		rewards = _rewards;

		emit RewardsUpdated(_rewards);
	}

	/// @dev Migrates oven funds to a new oven
	///
	/// @param migrateTo address of the new oven
	function migrateFunds(address migrateTo) external onlyGov {
		require(migrateTo != address(0), 'cannot migrate to 0x0');
		require(pause, 'migrate: set emergency exit first');

		// leave enough funds to service any pending transmutations
		uint256 totalFunds = IERC20Burnable(token).balanceOf(address(this));
		uint256 totalFriesUsd = IERC20Burnable(friesToken).balanceOf(address(this));

		uint256 totalSupplyfUSDToFunds = convertTokenAmount(friesToken, token, totalFriesUsd);
		uint256 migratableFunds = totalFunds.sub(totalSupplyfUSDToFunds, 'not enough funds to service stakes');
		IERC20Burnable(token).safeApprove(migrateTo, migratableFunds);
		IOven(migrateTo).distribute(address(this), migratableFunds);
		emit MigrationComplete(migrateTo, migratableFunds);
	}
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../utils/Context.sol";

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

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
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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
pragma solidity >=0.6.5 <0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IERC20Burnable is IERC20 {
	function burn(uint256 amount) external;

	function burnFrom(address account, uint256 amount) external;
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;




interface IOven {
    function distribute (address origin, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '../libraries/FixedPointMath.sol';
import '../libraries/TransferHelper.sol';
import '../interfaces/IDetailedERC20.sol';
import '../interfaces/IHarvestVaultAdapter.sol';
import '../interfaces/IHarvestVault.sol';
import '../interfaces/IHarvestFarm.sol';

/// @title YearnVaultAdapter
///
/// @dev A vault adapter implementation which wraps a yEarn vault.
contract HarvestVaultAdapter is IHarvestVaultAdapter {
	using FixedPointMath for FixedPointMath.uq192x64;
	using TransferHelper for address;
	using SafeMath for uint256;

	/// @dev The vault that the adapter is wrapping.
	IHarvestVault public vault;

	IHarvestFarm public farm;

	/// @dev The address which has admin control over this contract.
	address public admin;

	/// @dev The decimals of the token.
	uint256 public decimals;

	address public treasury;

	constructor(
		IHarvestVault _vault,
		IHarvestFarm _farm,
		address _admin,
		address _treasury
	) public {
		vault = _vault;
		farm = _farm;
		admin = _admin;
		treasury = _treasury;
		updateVaultApproval();
		updateFarmApproval();
		decimals = _vault.decimals();
	}

	/// @dev A modifier which reverts if the caller is not the admin.
	modifier onlyAdmin() {
		require(admin == msg.sender, 'HarvestVaultAdapter: only admin');
		_;
	}

	/// @dev Gets the token that the vault accepts.
	///
	/// @return the accepted token.
	function token() external view override returns (address) {
		return vault.underlying();
	}

	function lpToken() external view override returns (address) {
		return address(vault);
	}

	function lpTokenInFarm() public view override returns (uint256) {
		return farm.balanceOf(address(this));
	}

	/// @dev Gets the total value of the assets that the adapter holds in the vault.
	///
	/// @return the total assets.
	function totalValue() external view override returns (uint256) {
		return _sharesToTokens(lpTokenInFarm());
	}

	/// @dev Deposits tokens into the vault.
	///
	/// @param _amount the amount of tokens to deposit into the vault.
	function deposit(uint256 _amount) external override {
		vault.deposit(_amount);
	}

	/// @dev Withdraws tokens from the vault to the recipient.
	///
	/// This function reverts if the caller is not the admin.
	///
	/// @param _recipient the account to withdraw the tokes to.
	/// @param _amount    the amount of tokens to withdraw.
	function withdraw(address _recipient, uint256 _amount) external override onlyAdmin {
		vault.withdraw(_tokensToShares(_amount));
		address _token = vault.underlying();
		uint256 _balance = IERC20(_token).balanceOf(address(this));
		_token.safeTransfer(_recipient, _balance);
	}

	/// @dev stake into farming pool.
	function stake(uint256 _amount) external override {
		farm.stake(_amount);
	}

	/// @dev unstake from farming pool.
	function unstake(uint256 _amount) external override onlyAdmin {
		farm.withdraw(_tokensToShares(_amount));
	}

	function claim() external override {
		farm.getReward();
		address _rewardToken = farm.rewardToken();
		uint256 _balance = IERC20(_rewardToken).balanceOf(address(this));
		if (_balance > 0) {
			_rewardToken.safeTransfer(treasury, _balance);
		}
	}

	/// @dev Updates the vaults approval of the token to be the maximum value.
	function updateVaultApproval() public {
		address _token = vault.underlying();
		_token.safeApprove(address(vault), uint256(-1));
	}

	/// @dev Update the farm approval.
	function updateFarmApproval() public {
		address(vault).safeApprove(address(farm), uint256(-1));
	}

	/// @dev Computes the number of tokens an amount of shares is worth.
	///
	/// @param _sharesAmount the amount of shares.
	///
	/// @return the number of tokens the shares are worth.

	function _sharesToTokens(uint256 _sharesAmount) internal view returns (uint256) {
		return _sharesAmount.mul(vault.getPricePerFullShare()).div(10**decimals);
	}

	/// @dev Computes the number of shares an amount of tokens is worth.
	///
	/// @param _tokensAmount the amount of shares.
	///
	/// @return the number of shares the tokens are worth.
	function _tokensToShares(uint256 _tokensAmount) internal view returns (uint256) {
		return _tokensAmount.mul(10**decimals).div(vault.getPricePerFullShare());
	}
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

// import 'hardhat/console.sol';

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '../interfaces/IHarvestVaultAdapter.sol';
import '../interfaces/IVaultAdapter.sol';
import './TransferHelper.sol';

/// @title Pool
///
/// @dev A library which provides the Vault data struct and associated functions.
library HarvestVault {
	using HarvestVault for Data;
	using HarvestVault for List;
	using TransferHelper for address;
	using SafeMath for uint256;

	struct Data {
		IHarvestVaultAdapter adapter;
		uint256 totalDeposited;
	}

	struct List {
		Data[] elements;
	}

	/// @dev Gets the total amount of assets deposited in the vault.
	///
	/// @return the total assets.
	function totalValue(Data storage _self) internal view returns (uint256) {
		return _self.adapter.totalValue();
	}

	/// @dev Gets the token that the vault accepts.
	///
	/// @return the accepted token.
	function token(Data storage _self) internal view returns (address) {
		return _self.adapter.token();
	}

	/// @dev Deposits funds from the caller into the vault.
	///
	/// @param _amount the amount of funds to deposit.
	function deposit(Data storage _self, uint256 _amount) internal returns (uint256) {
		// Push the token that the vault accepts onto the stack to save gas.
		address _token = _self.token();
		_token.safeTransfer(address(_self.adapter), _amount);
		_self.adapter.deposit(_amount);
		_self.totalDeposited = _self.totalDeposited.add(_amount);

		// Stake all lp to farm.
		IERC20 _lpToken = IERC20(_self.adapter.lpToken());
		uint256 _lpTokenAmount = _lpToken.balanceOf(address(_self.adapter));
		_self.adapter.stake(_lpTokenAmount);

		return _amount;
	}

	/// @dev Withdraw deposited funds from the vault.
	///
	/// @param _recipient the account to withdraw the tokens to.
	/// @param _amount    the amount of tokens to withdraw.
	function withdraw(
		Data storage _self,
		address _recipient,
		uint256 _amount
	) internal returns (uint256, uint256) {
		(uint256 _withdrawnAmount, uint256 _decreasedValue) = _self.directWithdraw(_recipient, _amount);
		_self.totalDeposited = _self.totalDeposited.sub(_decreasedValue);
		return (_withdrawnAmount, _decreasedValue);
	}

	/// @dev Directly withdraw deposited funds from the vault.
	///
	/// @param _recipient the account to withdraw the tokens to.
	/// @param _amount    the amount of tokens to withdraw.
	function directWithdraw(
		Data storage _self,
		address _recipient,
		uint256 _amount
	) internal returns (uint256, uint256) {
		address _token = _self.token();

		uint256 _startingBalance = IERC20(_token).balanceOf(_recipient);
		uint256 _startingTotalValue = _self.totalValue();

		_self.adapter.unstake(_amount);
		_self.adapter.withdraw(_recipient, _amount);

		uint256 _endingBalance = IERC20(_token).balanceOf(_recipient);

		uint256 _withdrawnAmount = _endingBalance.sub(_startingBalance);

		uint256 _endingTotalValue = _self.totalValue();
		uint256 _decreasedValue = _startingTotalValue.sub(_endingTotalValue);

		return (_withdrawnAmount, _decreasedValue);
	}

	/// @dev Withdraw all the deposited funds from the vault.
	///
	/// @param _recipient the account to withdraw the tokens to.
	function withdrawAll(Data storage _self, address _recipient) internal returns (uint256, uint256) {
		uint256 _withdrawAmount = _self.totalDeposited;
		if (_withdrawAmount > _self.totalValue()) {
			_withdrawAmount = _self.totalValue(); // This fix with rounding problem.
		}
		return _self.withdraw(_recipient, _withdrawAmount);
	}

	/// @dev Harvests yield from the vault.
	///
	/// @param _recipient the account to withdraw the harvested yield to.
	function harvest(Data storage _self, address _recipient) internal returns (uint256, uint256) {
		_self.adapter.claim();
		if (_self.totalValue() <= _self.totalDeposited) {
			return (0, 0);
		}
		uint256 _withdrawAmount = _self.totalValue().sub(_self.totalDeposited);

		(uint256 _withdrawnAmount, uint256 _decreasedValue) = _self.directWithdraw(_recipient, _withdrawAmount);
		IVaultAdapter(_recipient).deposit(_withdrawnAmount);
		return (_withdrawnAmount, _decreasedValue);
	}

	/// @dev Adds a element to the list.
	///
	/// @param _element the element to add.
	function push(List storage _self, Data memory _element) internal {
		for (uint256 i = 0; i < _self.elements.length; i++) {
			// Avoid duplicated adapter
			require(address(_element.adapter) != address(_self.elements[i].adapter), '!Repeat adapter');
		}
		_self.elements.push(_element);
	}

	/// @dev Gets a element from the list.
	///
	/// @param _index the index in the list.
	///
	/// @return the element at the specified index.
	function get(List storage _self, uint256 _index) internal view returns (Data storage) {
		return _self.elements[_index];
	}

	/// @dev Gets the last element in the list.
	///
	/// This function will revert if there are no elements in the list.
	///
	/// @return the last element in the list.
	function last(List storage _self) internal view returns (Data storage) {
		return _self.elements[_self.lastIndex()];
	}

	/// @dev Gets the index of the last element in the list.
	///
	/// This function will revert if there are no elements in the list.
	///
	/// @return the index of the last element.
	function lastIndex(List storage _self) internal view returns (uint256) {
		uint256 _length = _self.length();
		return _length.sub(1, 'Vault.List: empty');
	}

	/// @dev Gets the number of elements in the list.
	///
	/// @return the number of elements.
	function length(List storage _self) internal view returns (uint256) {
		return _self.elements.length;
	}
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

contract Convert {
	using SafeMath for uint256;

	function convertTokenAmount(
		address _fromToken,
		address _toToken,
		uint256 _fromAmount
	) public view returns (uint256 toAmount) {
		uint256 fromDecimals = uint256(ERC20(_fromToken).decimals());
		uint256 toDecimals = uint256(ERC20(_toToken).decimals());
		if (fromDecimals > toDecimals) {
			toAmount = _fromAmount.div(10**(fromDecimals.sub(toDecimals)));
		} else if (toDecimals > fromDecimals) {
			toAmount = _fromAmount.mul(10**(toDecimals.sub(fromDecimals)));
		} else {
			toAmount = _fromAmount;
		}
		return toAmount;
	}
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;


library FixedPointMath {
  uint256 public constant DECIMALS = 18;
  uint256 public constant SCALAR = 10**DECIMALS;

  struct uq192x64 {
    uint256 x;
  }

  function fromU256(uint256 value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require(value == 0 || (x = value * SCALAR) / SCALAR == value);
    return uq192x64(x);
  }

  function maximumValue() internal pure returns (uq192x64 memory) {
    return uq192x64(uint256(-1));
  }

  function add(uq192x64 memory self, uq192x64 memory value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require((x = self.x + value.x) >= self.x);
    return uq192x64(x);
  }

  function add(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    return add(self, fromU256(value));
  }

  function sub(uq192x64 memory self, uq192x64 memory value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require((x = self.x - value.x) <= self.x);
    return uq192x64(x);
  }

  function sub(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    return sub(self, fromU256(value));
  }

  function mul(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require(value == 0 || (x = self.x * value) / value == self.x);
    return uq192x64(x);
  }

  function div(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    require(value != 0);
    return uq192x64(self.x / value);
  }

  function cmp(uq192x64 memory self, uq192x64 memory value) internal pure returns (int256) {
    if (self.x < value.x) {
      return -1;
    }

    if (self.x > value.x) {
      return 1;
    }

    return 0;
  }

  function decode(uq192x64 memory self) internal pure returns (uint256) {
    return self.x / SCALAR;
  }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

interface IDetailedERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

interface IHarvestVaultAdapter {
	function totalValue() external view returns (uint256);

	function deposit(uint256) external;

	function withdraw(address, uint256) external;

	function token() external view returns (address);

	function lpToken() external view returns (address);

	function lpTokenInFarm() external view returns (uint256);

	function stake(uint256) external;

	function unstake(uint256) external;

	function claim() external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IHarvestVault is IERC20 {
	function underlying() external view returns (address);

	function totalValue() external view returns (uint256);

	function deposit(uint256) external;

	function withdraw(uint256) external;

	function getPricePerFullShare() external view returns (uint256);

	function decimals() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IHarvestFarm {
	function rewardToken() external view returns (address);

	function lpToken() external view returns (address);

	function getReward() external;

	function stake(uint256 amount) external;

	function withdraw(uint256) external;

	function rewards(address) external returns (uint256);

	function balanceOf(address) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

/// Interface for all Vault Adapter implementations.
interface IVaultAdapter {

  /// @dev Gets the token that the adapter accepts.
  function token() external view returns (address);

  /// @dev The total value of the assets deposited into the vault.
  function totalValue() external view returns (uint256);

  /// @dev Deposits funds into the vault.
  ///
  /// @param _amount  the amount of funds to deposit.
  function deposit(uint256 _amount) external;

  /// @dev Attempts to withdraw funds from the wrapped vault.
  ///
  /// The amount withdrawn to the recipient may be less than the amount requested.
  ///
  /// @param _recipient the recipient of the funds.
  /// @param _amount    the amount of funds to withdraw.
  function withdraw(address _recipient, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../utils/Context.sol";
import "./IERC20.sol";
import "../../math/SafeMath.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}