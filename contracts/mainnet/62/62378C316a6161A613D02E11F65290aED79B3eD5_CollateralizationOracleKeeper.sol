pragma solidity ^0.8.0;

import "../token/FeiTimedMinter.sol";
import "../oracle/collateralization/ICollateralizationOracleWrapper.sol";

/// @title CollateralizationOracleKeeper
/// @notice a FEI timed minter which only rewards when updating the collateralization oracle 
contract CollateralizationOracleKeeper is FeiTimedMinter {

    ICollateralizationOracleWrapper public collateralizationOracleWrapper;

    /**
        @notice constructor for CollateralizationOracleKeeper
        @param _core the Core address to reference
        @param _incentive the incentive amount for calling mint paid in FEI
        @param _collateralizationOracleWrapper the collateralizationOracleWrapper to incentivize updates only
        sets the target to this address and mint amount to 0, relying exclusively on the incentive payment to caller
    */
    constructor(
        address _core,
        uint256 _incentive,
        ICollateralizationOracleWrapper _collateralizationOracleWrapper
    ) 
        FeiTimedMinter(_core, address(this), _incentive, MIN_MINT_FREQUENCY, 0) 
    {
        collateralizationOracleWrapper = _collateralizationOracleWrapper;
    }

    function _afterMint() internal override {
        collateralizationOracleWrapper.updateIfOutdated();
    }
}

pragma solidity ^0.8.0;

import "../refs/CoreRef.sol";
import "../utils/Timed.sol";
import "../utils/Incentivized.sol";
import "../utils/RateLimitedMinter.sol";
import "./IFeiTimedMinter.sol";

/// @title FeiTimedMinter
/// @notice a contract which mints FEI to a target address on a timed cadence
contract FeiTimedMinter is IFeiTimedMinter, CoreRef, Timed, Incentivized, RateLimitedMinter {
    
    /// @notice most frequent that mints can happen
    uint256 public constant override MIN_MINT_FREQUENCY = 1 hours; // Min 1 hour per mint

    /// @notice least frequent that mints can happen
    uint256 public constant override MAX_MINT_FREQUENCY = 30 days; // Max 1 month per mint
    
    uint256 private _mintAmount;

    /// @notice the target receiving minted FEI
    address public override target;

    /**
        @notice constructor for FeiTimedMinter
        @param _core the Core address to reference
        @param _target the target for minted FEI
        @param _incentive the incentive amount for calling mint paid in FEI
        @param _frequency the frequency minting happens
        @param _initialMintAmount the initial FEI amount to mint
    */
    constructor(
        address _core,
        address _target,
        uint256 _incentive,
        uint256 _frequency,
        uint256 _initialMintAmount
    ) 
        CoreRef(_core)
        Timed(_frequency)
        Incentivized(_incentive)
        RateLimitedMinter((_initialMintAmount + _incentive) / _frequency, (_initialMintAmount + _incentive), true) 
    {
        _initTimed();

        _setTarget(_target);
        _setMintAmount(_initialMintAmount);
    }

    /// @notice triggers a minting of FEI
    /// @dev timed and incentivized
    function mint() public virtual override whenNotPaused afterTime {

        /// Reset the timer
        _initTimed();

        uint256 amount = mintAmount();

        // incentivizing before minting so if there is a partial mint it goes to target not caller
        _incentivize();

        if (amount != 0) {
            // Calls the overriden RateLimitedMinter _mintFei which includes the rate limiting logic
            _mintFei(target, amount);
        
            emit FeiMinting(msg.sender, amount);
        }
        // After mint called whether a "mint" happens or not to allow incentivized target hooks
        _afterMint();
    }
    
    function mintAmount() public view virtual override returns (uint256) {
        return _mintAmount;
    }

    /// @notice set the new FEI target
    function setTarget(address newTarget) external override onlyGovernor {
        _setTarget(newTarget);
    }

    /// @notice set the mint frequency
    function setFrequency(uint256 newFrequency) external override onlyGovernorOrAdmin {
        require(newFrequency >= MIN_MINT_FREQUENCY, "FeiTimedMinter: frequency low");
        require(newFrequency <= MAX_MINT_FREQUENCY, "FeiTimedMinter: frequency high");

        _setDuration(newFrequency);
    }

    function setMintAmount(uint256 newMintAmount) external override onlyGovernorOrAdmin {
        _setMintAmount(newMintAmount);
    }

    function _setTarget(address newTarget) internal {
        require(newTarget != address(0), "FeiTimedMinter: zero address");
        address oldTarget = target;
        target = newTarget;
        emit TargetUpdate(oldTarget, newTarget);
    }

    function _setMintAmount(uint256 newMintAmount) internal {
        uint256 oldMintAmount = _mintAmount;
        _mintAmount = newMintAmount;
        emit MintAmountUpdate(oldMintAmount, newMintAmount);
    }

    function _mintFei(address to, uint256 amountIn) internal override(CoreRef, RateLimitedMinter) {
      RateLimitedMinter._mintFei(to, amountIn);
    }

    function _afterMint() internal virtual {}
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "./ICoreRef.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title A Reference to Core
/// @author Fei Protocol
/// @notice defines some modifiers and utilities around interacting with Core
abstract contract CoreRef is ICoreRef, Pausable {
    ICore private _core;

    /// @notice a role used with a subset of governor permissions for this contract only
    bytes32 public override CONTRACT_ADMIN_ROLE;

    /// @notice boolean to check whether or not the contract has been initialized.
    /// cannot be initialized twice.
    bool private _initialized;

    constructor(address coreAddress) {
        _initialize(coreAddress);
    }

    /// @notice CoreRef constructor
    /// @param coreAddress Fei Core to reference
    function _initialize(address coreAddress) internal {
        require(!_initialized, "CoreRef: already initialized");
        _initialized = true;

        _core = ICore(coreAddress);
        _setContractAdminRole(_core.GOVERN_ROLE());
    }

    modifier ifMinterSelf() {
        if (_core.isMinter(address(this))) {
            _;
        }
    }

    modifier onlyMinter() {
        require(_core.isMinter(msg.sender), "CoreRef: Caller is not a minter");
        _;
    }

    modifier onlyBurner() {
        require(_core.isBurner(msg.sender), "CoreRef: Caller is not a burner");
        _;
    }

    modifier onlyPCVController() {
        require(
            _core.isPCVController(msg.sender),
            "CoreRef: Caller is not a PCV controller"
        );
        _;
    }

    modifier onlyGovernorOrAdmin() {
        require(
            _core.isGovernor(msg.sender) ||
            isContractAdmin(msg.sender),
            "CoreRef: Caller is not a governor or contract admin"
        );
        _;
    }

    modifier onlyGovernor() {
        require(
            _core.isGovernor(msg.sender),
            "CoreRef: Caller is not a governor"
        );
        _;
    }

    modifier onlyGuardianOrGovernor() {
        require(
            _core.isGovernor(msg.sender) || 
            _core.isGuardian(msg.sender),
            "CoreRef: Caller is not a guardian or governor"
        );
        _;
    }

    modifier onlyFei() {
        require(msg.sender == address(fei()), "CoreRef: Caller is not FEI");
        _;
    }

    /// @notice set new Core reference address
    /// @param newCore the new core address
    function setCore(address newCore) external override onlyGovernor {
        require(newCore != address(0), "CoreRef: zero address");
        address oldCore = address(_core);
        _core = ICore(newCore);
        emit CoreUpdate(oldCore, newCore);
    }

    /// @notice sets a new admin role for this contract
    function setContractAdminRole(bytes32 newContractAdminRole) external override onlyGovernor {
        _setContractAdminRole(newContractAdminRole);
    }

    /// @notice returns whether a given address has the admin role for this contract
    function isContractAdmin(address _admin) public view override returns (bool) {
        return _core.hasRole(CONTRACT_ADMIN_ROLE, _admin);
    }

    /// @notice set pausable methods to paused
    function pause() public override onlyGuardianOrGovernor {
        _pause();
    }

    /// @notice set pausable methods to unpaused
    function unpause() public override onlyGuardianOrGovernor {
        _unpause();
    }

    /// @notice address of the Core contract referenced
    /// @return ICore implementation address
    function core() public view override returns (ICore) {
        return _core;
    }

    /// @notice address of the Fei contract referenced by Core
    /// @return IFei implementation address
    function fei() public view override returns (IFei) {
        return _core.fei();
    }

    /// @notice address of the Tribe contract referenced by Core
    /// @return IERC20 implementation address
    function tribe() public view override returns (IERC20) {
        return _core.tribe();
    }

    /// @notice fei balance of contract
    /// @return fei amount held
    function feiBalance() public view override returns (uint256) {
        return fei().balanceOf(address(this));
    }

    /// @notice tribe balance of contract
    /// @return tribe amount held
    function tribeBalance() public view override returns (uint256) {
        return tribe().balanceOf(address(this));
    }

    function _burnFeiHeld() internal {
        fei().burn(feiBalance());
    }

    function _mintFei(address to, uint256 amount) internal virtual {
        if (amount != 0) {
            fei().mint(to, amount);
        }
    }

    function _setContractAdminRole(bytes32 newContractAdminRole) internal {
        bytes32 oldContractAdminRole = CONTRACT_ADMIN_ROLE;
        CONTRACT_ADMIN_ROLE = newContractAdminRole;
        emit ContractAdminRoleUpdate(oldContractAdminRole, newContractAdminRole);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "../core/ICore.sol";

/// @title CoreRef interface
/// @author Fei Protocol
interface ICoreRef {
    // ----------- Events -----------

    event CoreUpdate(address indexed oldCore, address indexed newCore);

    event ContractAdminRoleUpdate(bytes32 indexed oldContractAdminRole, bytes32 indexed newContractAdminRole);

    // ----------- Governor only state changing api -----------

    function setCore(address newCore) external;

    function setContractAdminRole(bytes32 newContractAdminRole) external;

    // ----------- Governor or Guardian only state changing api -----------

    function pause() external;

    function unpause() external;

    // ----------- Getters -----------

    function core() external view returns (ICore);

    function fei() external view returns (IFei);

    function tribe() external view returns (IERC20);

    function feiBalance() external view returns (uint256);

    function tribeBalance() external view returns (uint256);

    function CONTRACT_ADMIN_ROLE() external view returns (bytes32);

    function isContractAdmin(address admin) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "./IPermissions.sol";
import "../token/IFei.sol";

/// @title Core Interface
/// @author Fei Protocol
interface ICore is IPermissions {
    // ----------- Events -----------

    event FeiUpdate(address indexed _fei);
    event TribeUpdate(address indexed _tribe);
    event GenesisGroupUpdate(address indexed _genesisGroup);
    event TribeAllocation(address indexed _to, uint256 _amount);
    event GenesisPeriodComplete(uint256 _timestamp);

    // ----------- Governor only state changing api -----------

    function init() external;

    // ----------- Governor only state changing api -----------

    function setFei(address token) external;

    function setTribe(address token) external;

    function allocateTribe(address to, uint256 amount) external;

    // ----------- Getters -----------

    function fei() external view returns (IFei);

    function tribe() external view returns (IERC20);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Permissions interface
/// @author Fei Protocol
interface IPermissions is IAccessControl {
    // ----------- Governor only state changing api -----------

    function createRole(bytes32 role, bytes32 adminRole) external;

    function grantMinter(address minter) external;

    function grantBurner(address burner) external;

    function grantPCVController(address pcvController) external;

    function grantGovernor(address governor) external;

    function grantGuardian(address guardian) external;

    function revokeMinter(address minter) external;

    function revokeBurner(address burner) external;

    function revokePCVController(address pcvController) external;

    function revokeGovernor(address governor) external;

    function revokeGuardian(address guardian) external;

    // ----------- Revoker only state changing api -----------

    function revokeOverride(bytes32 role, address account) external;

    // ----------- Getters -----------

    function isBurner(address _address) external view returns (bool);

    function isMinter(address _address) external view returns (bool);

    function isGovernor(address _address) external view returns (bool);

    function isGuardian(address _address) external view returns (bool);

    function isPCVController(address _address) external view returns (bool);

    function GUARDIAN_ROLE() external view returns (bytes32);

    function GOVERN_ROLE() external view returns (bytes32);

    function BURNER_ROLE() external view returns (bytes32);

    function MINTER_ROLE() external view returns (bytes32);

    function PCV_CONTROLLER_ROLE() external view returns (bytes32);

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title FEI stablecoin interface
/// @author Fei Protocol
interface IFei is IERC20 {
    // ----------- Events -----------

    event Minting(
        address indexed _to,
        address indexed _minter,
        uint256 _amount
    );

    event Burning(
        address indexed _to,
        address indexed _burner,
        uint256 _amount
    );

    event IncentiveContractUpdate(
        address indexed _incentivized,
        address indexed _incentiveContract
    );

    // ----------- State changing api -----------

    function burn(uint256 amount) external;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    // ----------- Burner only state changing api -----------

    function burnFrom(address account, uint256 amount) external;

    // ----------- Minter only state changing api -----------

    function mint(address account, uint256 amount) external;

    // ----------- Governor only state changing api -----------

    function setIncentiveContract(address account, address incentive) external;

    // ----------- Getters -----------

    function incentiveContract(address account) external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

/// @title an abstract contract for timed events
/// @author Fei Protocol
abstract contract Timed {

    /// @notice the start timestamp of the timed period
    uint256 public startTime;

    /// @notice the duration of the timed period
    uint256 public duration;

    event DurationUpdate(uint256 oldDuration, uint256 newDuration);

    event TimerReset(uint256 startTime);

    constructor(uint256 _duration) {
        _setDuration(_duration);
    }

    modifier duringTime() {
        require(isTimeStarted(), "Timed: time not started");
        require(!isTimeEnded(), "Timed: time ended");
        _;
    }

    modifier afterTime() {
        require(isTimeEnded(), "Timed: time not ended");
        _;
    }

    /// @notice return true if time period has ended
    function isTimeEnded() public view returns (bool) {
        return remainingTime() == 0;
    }

    /// @notice number of seconds remaining until time is up
    /// @return remaining
    function remainingTime() public view returns (uint256) {
        return duration - timeSinceStart(); // duration always >= timeSinceStart which is on [0,d]
    }

    /// @notice number of seconds since contract was initialized
    /// @return timestamp
    /// @dev will be less than or equal to duration
    function timeSinceStart() public view returns (uint256) {
        if (!isTimeStarted()) {
            return 0; // uninitialized
        }
        uint256 _duration = duration;
        uint256 timePassed = block.timestamp - startTime; // block timestamp always >= startTime
        return timePassed > _duration ? _duration : timePassed;
    }

    function isTimeStarted() public view returns (bool) {
        return startTime != 0;
    }

    function _initTimed() internal {
        startTime = block.timestamp;
        
        emit TimerReset(block.timestamp);
    }

    function _setDuration(uint256 newDuration) internal {
        require(newDuration != 0, "Timed: zero duration");

        uint256 oldDuration = duration;
        duration = newDuration;
        emit DurationUpdate(oldDuration, newDuration);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "../refs/CoreRef.sol";

/// @title abstract contract for incentivizing keepers
/// @author Fei Protocol
abstract contract Incentivized is CoreRef {

    /// @notice FEI incentive for calling keeper functions
    uint256 public incentiveAmount;

    event IncentiveUpdate(uint256 oldIncentiveAmount, uint256 newIncentiveAmount);

    constructor(uint256 _incentiveAmount) {
        incentiveAmount = _incentiveAmount;
        emit IncentiveUpdate(0, _incentiveAmount);
    }

    /// @notice set the incentiveAmount
    function setIncentiveAmount(uint256 newIncentiveAmount) public onlyGovernor {
        uint256 oldIncentiveAmount = incentiveAmount;
        incentiveAmount = newIncentiveAmount;
        emit IncentiveUpdate(oldIncentiveAmount, newIncentiveAmount);
    }

    /// @notice incentivize a call with incentiveAmount FEI rewards
    /// @dev no-op if the contract does not have Minter role
    function _incentivize() internal ifMinterSelf {
        _mintFei(msg.sender, incentiveAmount);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "./RateLimited.sol";

/// @title abstract contract for putting a rate limit on how fast a contract can mint FEI
/// @author Fei Protocol
abstract contract RateLimitedMinter is RateLimited {

    uint256 private constant MAX_FEI_LIMIT_PER_SECOND = 10_000e18; // 10000 FEI/s or ~860m FEI/day
    
    constructor(
        uint256 _feiLimitPerSecond, 
        uint256 _mintingBufferCap, 
        bool _doPartialMint
    ) 
        RateLimited(MAX_FEI_LIMIT_PER_SECOND, _feiLimitPerSecond, _mintingBufferCap, _doPartialMint)
    {}

    /// @notice override the FEI minting behavior to enforce a rate limit
    function _mintFei(address to, uint256 amount) internal virtual override {
        uint256 mintAmount = _depleteBuffer(amount);
        super._mintFei(to, mintAmount);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "../refs/CoreRef.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title abstract contract for putting a rate limit on how fast a contract can perform an action e.g. Minting
/// @author Fei Protocol
abstract contract RateLimited is CoreRef {

    /// @notice maximum rate limit per second governance can set for this contract
    uint256 public immutable MAX_RATE_LIMIT_PER_SECOND;

    /// @notice the rate per second for this contract
    uint256 public rateLimitPerSecond;

    /// @notice the last time the buffer was used by the contract
    uint256 public lastBufferUsedTime;

    /// @notice the cap of the buffer that can be used at once
    uint256 public bufferCap;

    /// @notice a flag for whether to allow partial actions to complete if the buffer is less than amount
    bool public doPartialAction;

    /// @notice the buffer at the timestamp of lastBufferUsedTime
    uint256 private _bufferStored;

    event BufferCapUpdate(uint256 oldBufferCap, uint256 newBufferCap);
    event RateLimitPerSecondUpdate(uint256 oldRateLimitPerSecond, uint256 newRateLimitPerSecond);

    constructor(uint256 _maxRateLimitPerSecond, uint256 _rateLimitPerSecond, uint256 _bufferCap, bool _doPartialAction) {
        lastBufferUsedTime = block.timestamp;

        _bufferStored = _bufferCap;
        _setBufferCap(_bufferCap);

        require(_rateLimitPerSecond <= _maxRateLimitPerSecond, "RateLimited: rateLimitPerSecond too high");
        _setRateLimitPerSecond(_rateLimitPerSecond);
        
        MAX_RATE_LIMIT_PER_SECOND = _maxRateLimitPerSecond;
        doPartialAction = _doPartialAction;
    }

    /// @notice set the rate limit per second
    function setRateLimitPerSecond(uint256 newRateLimitPerSecond) external onlyGovernorOrAdmin {
        require(newRateLimitPerSecond <= MAX_RATE_LIMIT_PER_SECOND, "RateLimited: rateLimitPerSecond too high");
        _setRateLimitPerSecond(newRateLimitPerSecond);
    }

    /// @notice set the buffer cap
    function setbufferCap(uint256 newBufferCap) external onlyGovernorOrAdmin {
        _setBufferCap(newBufferCap);
    }

    /// @notice the amount of action used before hitting limit
    /// @dev replenishes at rateLimitPerSecond per second up to bufferCap
    function buffer() public view returns(uint256) { 
        uint256 elapsed = block.timestamp - lastBufferUsedTime;
        return Math.min(_bufferStored + (rateLimitPerSecond * elapsed), bufferCap);
    }

    /** 
        @notice the method that enforces the rate limit. Decreases buffer by "amount". 
        If buffer is <= amount either
        1. Does a partial mint by the amount remaining in the buffer or
        2. Reverts
        Depending on whether doPartialAction is true or false
    */
    function _depleteBuffer(uint256 amount) internal returns(uint256) {
        uint256 newBuffer = buffer();
        
        uint256 usedAmount = amount;
        if (doPartialAction && usedAmount > newBuffer) {
            usedAmount = newBuffer;
        }

        require(newBuffer != 0, "RateLimited: no rate limit buffer");
        require(usedAmount <= newBuffer, "RateLimited: rate limit hit");

        _bufferStored = newBuffer - usedAmount;

        lastBufferUsedTime = block.timestamp;

        return usedAmount;
    }

    function _setRateLimitPerSecond(uint256 newRateLimitPerSecond) internal {

        // Reset the stored buffer and last buffer used time using the prior RateLimitPerSecond
        _bufferStored = buffer();
        lastBufferUsedTime = block.timestamp;

        uint256 oldRateLimitPerSecond = rateLimitPerSecond;
        rateLimitPerSecond = newRateLimitPerSecond;

        emit RateLimitPerSecondUpdate(oldRateLimitPerSecond, newRateLimitPerSecond);
    }

    function _setBufferCap(uint256 newBufferCap) internal {
        uint256 oldBufferCap = bufferCap;
        bufferCap = newBufferCap;

        // Cap the existing stored buffer
        if (_bufferStored > newBufferCap) {
            _bufferStored = newBufferCap;
        }

        emit BufferCapUpdate(oldBufferCap, newBufferCap);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title a Fei Timed Minter
/// @author Fei Protocol
interface IFeiTimedMinter {

    // ----------- Events -----------

    event FeiMinting(address indexed caller, uint256 feiAmount);

    event TargetUpdate(address oldTarget, address newTarget);

    event MintAmountUpdate(uint256 oldMintAmount, uint256 newMintAmount);

    // ----------- State changing api -----------

    function mint() external;

    // ----------- Governor only state changing api -----------

    function setTarget(address newTarget) external;

    // ----------- Governor or Admin only state changing api -----------

    function setFrequency(uint256 newFrequency) external;

    function setMintAmount(uint256 newMintAmount) external;

    // ----------- Getters -----------
    
    function mintAmount() external view returns(uint256);
    
    function MIN_MINT_FREQUENCY() external view returns(uint256);

    function MAX_MINT_FREQUENCY() external view returns(uint256);

    function target() external view returns(address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "./ICollateralizationOracle.sol";

/// @title Collateralization ratio oracle interface for Fei Protocol
/// @author Fei Protocol
interface ICollateralizationOracleWrapper is ICollateralizationOracle {

    // ----------- Events ------------------------------------------------------

    event CachedValueUpdate(
        address from,
        uint256 indexed protocolControlledValue,
        uint256 indexed userCirculatingFei,
        int256 indexed protocolEquity
    );

    event CollateralizationOracleUpdate(
        address from,
        address indexed oldOracleAddress,
        address indexed newOracleAddress
    );

    event DeviationThresholdUpdate(
        address from,
        uint256 indexed oldThreshold,
        uint256 indexed newThreshold
    );

    event ReadPauseOverrideUpdate(
        bool readPauseOverride
    );
    // ----------- Public state changing api -----------

    function updateIfOutdated() external;

    // ----------- Governor only state changing api -----------
    function setValidityDuration(uint256 _validityDuration) external;

    function setReadPauseOverride(bool newReadPauseOverride) external;

    function setDeviationThresholdBasisPoints(uint256 _newDeviationThresholdBasisPoints) external;

    function setCollateralizationOracle(address _newCollateralizationOracle) external;

    function setCache(
        uint256 protocolControlledValue,
        uint256 userCirculatingFei,
        int256 protocolEquity
    ) external;

    // ----------- Getters -----------
    
    function cachedProtocolControlledValue() external view returns (uint256);
    
    function cachedUserCirculatingFei() external view returns (uint256);

    function cachedProtocolEquity() external view returns (int256);

    function deviationThresholdBasisPoints() external view returns (uint256);

    function collateralizationOracle() external view returns(address);

    function isOutdatedOrExceededDeviationThreshold() external view returns (bool);

    function pcvStatsCurrent() external view returns (
        uint256 protocolControlledValue,
        uint256 userCirculatingFei,
        int256 protocolEquity,
        bool validityStatus
    );

    function isExceededDeviationThreshold() external view returns (bool);

    function readPauseOverride() external view returns(bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "../IOracle.sol";

/// @title Collateralization ratio oracle interface for Fei Protocol
/// @author Fei Protocol
interface ICollateralizationOracle is IOracle {

    // ----------- Getters -----------

    // returns the PCV value, User-circulating FEI, and Protocol Equity, as well
    // as a validity status.
    function pcvStats() external view returns (
        uint256 protocolControlledValue,
        uint256 userCirculatingFei,
        int256 protocolEquity,
        bool validityStatus
    );

    // true if Protocol Equity > 0
    function isOvercollateralized() external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.4;

import "../external/Decimal.sol";

/// @title generic oracle interface for Fei Protocol
/// @author Fei Protocol
interface IOracle {
    // ----------- Events -----------

    event Update(uint256 _peg);

    // ----------- State changing API -----------

    function update() external;

    // ----------- Getters -----------

    function read() external view returns (Decimal.D256 memory, bool);

    function isOutdated() external view returns (bool);
    
}

/*
    Copyright 2019 dYdX Trading Inc.
    Copyright 2020 Empty Set Squad <[email protected]>
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title Decimal
 * @author dYdX
 *
 * Library that defines a fixed-point number with 18 decimal places.
 */
library Decimal {
    using SafeMath for uint256;

    // ============ Constants ============

    uint256 private constant BASE = 10**18;

    // ============ Structs ============


    struct D256 {
        uint256 value;
    }

    // ============ Static Functions ============

    function zero()
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: 0 });
    }

    function one()
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: BASE });
    }

    function from(
        uint256 a
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: a.mul(BASE) });
    }

    function ratio(
        uint256 a,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: getPartial(a, BASE, b) });
    }

    // ============ Self Functions ============

    function add(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.add(b.mul(BASE)) });
    }

    function sub(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.mul(BASE)) });
    }

    function sub(
        D256 memory self,
        uint256 b,
        string memory reason
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.mul(BASE), reason) });
    }

    function mul(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.mul(b) });
    }

    function div(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.div(b) });
    }

    function pow(
        D256 memory self,
        uint256 b
    )
    internal
    pure
    returns (D256 memory)
    {
        if (b == 0) {
            return from(1);
        }

        D256 memory temp = D256({ value: self.value });
        for (uint256 i = 1; i < b; i++) {
            temp = mul(temp, self);
        }

        return temp;
    }

    function add(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.add(b.value) });
    }

    function sub(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.value) });
    }

    function sub(
        D256 memory self,
        D256 memory b,
        string memory reason
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: self.value.sub(b.value, reason) });
    }

    function mul(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: getPartial(self.value, b.value, BASE) });
    }

    function div(
        D256 memory self,
        D256 memory b
    )
    internal
    pure
    returns (D256 memory)
    {
        return D256({ value: getPartial(self.value, BASE, b.value) });
    }

    function equals(D256 memory self, D256 memory b) internal pure returns (bool) {
        return self.value == b.value;
    }

    function greaterThan(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) == 2;
    }

    function lessThan(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) == 0;
    }

    function greaterThanOrEqualTo(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) > 0;
    }

    function lessThanOrEqualTo(D256 memory self, D256 memory b) internal pure returns (bool) {
        return compareTo(self, b) < 2;
    }

    function isZero(D256 memory self) internal pure returns (bool) {
        return self.value == 0;
    }

    function asUint256(D256 memory self) internal pure returns (uint256) {
        return self.value.div(BASE);
    }

    // ============ Core Methods ============

    function getPartial(
        uint256 target,
        uint256 numerator,
        uint256 denominator
    )
    private
    pure
    returns (uint256)
    {
        return target.mul(numerator).div(denominator);
    }

    function compareTo(
        D256 memory a,
        D256 memory b
    )
    private
    pure
    returns (uint256)
    {
        if (a.value == b.value) {
            return 1;
        }
        return a.value > b.value ? 2 : 0;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
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
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
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
        require(paused(), "Pausable: not paused");
        _;
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
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

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
abstract contract AccessControl is Context, IAccessControl, ERC165 {
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
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
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
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
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
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
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
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
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

    function _grantRole(bytes32 role, address account) private {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    function _revokeRole(bytes32 role, address account) private {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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

pragma solidity ^0.8.0;

import "./IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        return a + b;
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
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}