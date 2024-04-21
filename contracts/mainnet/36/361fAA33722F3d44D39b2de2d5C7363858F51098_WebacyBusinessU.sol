// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IWebacyProxyFactory.sol";
import "../interfaces/IWebacyProxy.sol";

contract WebacyBusinessU is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    IWebacyProxyFactory public proxyFactory;
    uint256 public transferFee;

    struct AssetBeneficiary {
        address desAddress;
        uint256 tokenId;
    }

    struct TokenBeneficiary {
        address desAddress;
        uint8 percent;
    }

    struct ERC20TokenStatus {
        address newOwner;
        uint256 amountTransferred;
        bool transferred;
    }

    struct ERC721TokenStatus {
        address newOwner;
        uint256 tokenIdTransferred;
        bool transferred;
    }

    struct ERC20Token {
        address scAddress;
        TokenBeneficiary[] tokenBeneficiaries;
        uint256 amount;
    }

    struct ERC721Token {
        address scAddress;
        AssetBeneficiary[] assetBeneficiaries;
    }

    struct TransferredERC20 {
        address scAddress;
        ERC20TokenStatus erc20TokenStatus;
    }

    struct TransferredERC721 {
        address scAddress;
        ERC721TokenStatus[] erc721TokenStatus;
    }

    struct Assets {
        ERC721Token[] erc721;
        address[] backupAddresses;
        ERC20Token[] erc20;
        TransferredERC20[] transferredErc20;
        TransferredERC721[] transferredErc721;
    }

    // Inverse relation with beneficiary
    mapping(address => address) private beneficiaryToMember;

    // * Asset Beneficiary section
    mapping(address => address[]) private memberToERC721Contracts;
    mapping(address => mapping(address => AssetBeneficiary[])) private memberToContractToAssetBeneficiary;
    mapping(address => mapping(address => address)) private assetBeneficiaryToContractToMember;
    mapping(address => mapping(address => ERC721TokenStatus[])) private memberToContractToAssetStatus;
    // Asset Beneficiary section *

    // * Token Beneficiary section
    mapping(address => address[]) private memberToERC20Contracts;
    mapping(address => mapping(address => uint256)) private memberToContractToAllowableAmount;
    mapping(address => mapping(address => TokenBeneficiary[])) private memberToContractToTokenBeneficiaries;
    mapping(address => mapping(address => address)) private tokenBeneficiaryToContractToMember;
    mapping(address => mapping(address => ERC20TokenStatus)) private memberToContractToTokenStatus;
    // Token Beneficiary section *

    // * Backup data strucutre section
    mapping(address => address[]) private memberToBackupWallets;
    mapping(address => address) private backupWalletToMember;
    // Backup data structure section *

    // * Balances
    address[] private contractBalances;
    mapping(address => bool) private hasBalance;

    // Balances *

    bytes32 public constant MEMBERSHIP_ROLE = keccak256("MEMBERSHIP_ROLE");

    function initialize(address _proxyFactoryAddress) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        proxyFactory = IWebacyProxyFactory(_proxyFactoryAddress);
        transferFee = 1;
    }

    modifier hasPaidMembership(address _address) {
        address memberContract = address(proxyFactory.deployedContractFromMember(_address));
        require(memberContract != address(0x0), "Sender has no paid membership");
        _;
    }

    function getMemberFromBackup(address _address) external view returns (address) {
        return backupWalletToMember[_address];
    }

    function getMemberFromBeneficiary(address _address) external view returns (address) {
        return beneficiaryToMember[_address];
    }

    function storeERC20Data(
        address contractAddress,
        address[] memory destinationAddresses,
        uint8[] memory destinationPercents,
        uint256 amount,
        address[] memory backupAddresses
    ) external whenNotPaused hasPaidMembership(msg.sender) {
        require(destinationAddresses.length == destinationPercents.length, "Equally size arrays required");
        require(amount > 0, "Invalid amount");

        _saveBackupWallet(backupAddresses);

        require(memberToContractToAllowableAmount[msg.sender][contractAddress] == 0, "ERC20 already stored for member");

        memberToERC20Contracts[msg.sender].push(contractAddress);
        memberToContractToAllowableAmount[msg.sender][contractAddress] = amount;

        for (uint256 i = 0; i < destinationAddresses.length; i++) {
            require(destinationPercents[i] >= 0 && destinationPercents[i] <= 100, "Percent must be in range 0-100");
            TokenBeneficiary memory tokenB = TokenBeneficiary(address(0), 0);
            tokenB.desAddress = destinationAddresses[i];
            tokenB.percent = destinationPercents[i];
            _isValidBeneficiary(tokenB.desAddress, contractAddress);
            tokenBeneficiaryToContractToMember[tokenB.desAddress][contractAddress] = msg.sender;
            beneficiaryToMember[tokenB.desAddress] = msg.sender;
            memberToContractToTokenBeneficiaries[msg.sender][contractAddress].push(tokenB);
        }
    }

    function storeERC721Data(
        address contractAddress,
        address[] memory destinationAddresses,
        uint256[] memory destinationTokenIds,
        address[] memory backupAddresses
    ) external whenNotPaused hasPaidMembership(msg.sender) {
        require(destinationAddresses.length == destinationTokenIds.length, "Equally size arrays required");

        _saveBackupWallet(backupAddresses);

        AssetBeneficiary[] memory assetBeneficiaries = memberToContractToAssetBeneficiary[msg.sender][contractAddress];

        require(assetBeneficiaries.length == 0, "ERC721 already stored for member");

        memberToERC721Contracts[msg.sender].push(contractAddress);

        require(destinationTokenIds.length != 0, "No empty token ids allowed");

        for (uint256 i = 0; i < destinationAddresses.length; i++) {
            AssetBeneficiary memory assetB = AssetBeneficiary(address(0), 0);
            assetB.desAddress = destinationAddresses[i];
            assetB.tokenId = destinationTokenIds[i];
            _validateERC721CollectibleNotYetAssigned(contractAddress, assetB.tokenId);
            memberToContractToAssetBeneficiary[msg.sender][contractAddress].push(assetB);
            assetBeneficiaryToContractToMember[destinationAddresses[i]][contractAddress] = msg.sender;
            beneficiaryToMember[destinationAddresses[i]] = msg.sender;
        }
    }

    function getApprovedAssets(address owner) public view returns (Assets memory) {
        // INIT ERC20Contracts
        address[] memory erc20Contracts = memberToERC20Contracts[owner];
        // END ERC20Contracts

        // INIT BackupWallets
        address[] memory backupWallets = memberToBackupWallets[owner];
        // END BackupWallets

        // INIT ERC721Contracts
        address[] memory erc721Contracts = memberToERC721Contracts[owner];
        // END ERC721Contracts

        Assets memory assets = Assets(
            new ERC721Token[](erc721Contracts.length),
            new address[](backupWallets.length),
            new ERC20Token[](erc20Contracts.length),
            new TransferredERC20[](erc20Contracts.length),
            new TransferredERC721[](erc721Contracts.length)
        );

        // INIT FULLFILL ERC721 BENEFICIARIES
        for (uint256 i = 0; i < erc721Contracts.length; i++) {
            AssetBeneficiary[] memory assetBeneficiaries = memberToContractToAssetBeneficiary[owner][
                erc721Contracts[i]
            ];
            assets.erc721[i].assetBeneficiaries = assetBeneficiaries;
            assets.erc721[i].scAddress = erc721Contracts[i];

            ERC721TokenStatus[] memory assetsStatus = memberToContractToAssetStatus[owner][erc721Contracts[i]];
            assets.transferredErc721[i].scAddress = erc721Contracts[i];
            assets.transferredErc721[i].erc721TokenStatus = assetsStatus;
        }
        // END FULLFILL ERC721 BENEFICIARIES

        // INIT FULLFILL BACKUPWALLETS
        for (uint256 i = 0; i < backupWallets.length; i++) {
            assets.backupAddresses[i] = backupWallets[i];
        }
        // END FULLFILL BACKUPWALLETS

        for (uint256 i = 0; i < erc20Contracts.length; i++) {
            //FULLFILL ERC20 BENEFICIARIES
            TokenBeneficiary[] memory tokenBeneficiaries = memberToContractToTokenBeneficiaries[owner][
                erc20Contracts[i]
            ];
            assets.erc20[i].tokenBeneficiaries = tokenBeneficiaries;
            assets.erc20[i].scAddress = erc20Contracts[i];
            assets.erc20[i].amount = memberToContractToAllowableAmount[owner][erc20Contracts[i]];
            //FULLFILL TRANSFERRED ERC20
            ERC20TokenStatus memory tokenStatus = memberToContractToTokenStatus[owner][erc20Contracts[i]];
            if (tokenStatus.newOwner != address(0)) {
                assets.transferredErc20[i].scAddress = erc20Contracts[i];
                assets.transferredErc20[i].erc20TokenStatus = tokenStatus;
            }
        }
        // END FULLFILL ERC20 BENEFICIARIES

        return assets;
    }

    function _saveBackupWallet(address[] memory backupAddresses) private {
        if (memberToBackupWallets[msg.sender].length == 0) {
            for (uint256 i = 0; i < backupAddresses.length; i++) {
                require(backupWalletToMember[backupAddresses[i]] == address(0), "Backup already exists");
                backupWalletToMember[backupAddresses[i]] = msg.sender;
                memberToBackupWallets[msg.sender].push(backupAddresses[i]);
            }
        }
    }

    function _validateERC721CollectibleNotYetAssigned(address _contractAddress, uint256 _tokenId) private view {
        AssetBeneficiary[] memory assetBeneficiaries = memberToContractToAssetBeneficiary[msg.sender][_contractAddress];
        for (uint256 i = 0; i < assetBeneficiaries.length; i++) {
            if (assetBeneficiaries[i].tokenId == _tokenId) {
                require(!(assetBeneficiaries[i].tokenId == _tokenId), "TokenId exists on contract");
            }
        }
    }

    function _isValidBeneficiary(address _destinationAddress, address _contractAddress) private view {
        require(_destinationAddress != address(0), "Not valid address");
        require(
            tokenBeneficiaryToContractToMember[_destinationAddress][_contractAddress] == address(0),
            "Beneficiary already exists"
        );
    }

    function _validateERC721SCExists(address _contractAddress, address _owner) private view {
        AssetBeneficiary[] memory assetBeneficiaries = memberToContractToAssetBeneficiary[_owner][_contractAddress];
        require(assetBeneficiaries.length > 0, "ERC721 address not exists");
    }

    function _validateERC721CollectibleExists(
        address _contractAddress,
        address _owner,
        uint256 _tokenId
    ) private view {
        AssetBeneficiary[] memory assetBeneficiaries = memberToContractToAssetBeneficiary[_owner][_contractAddress];
        bool exists = false;
        for (uint256 i = 0; i < assetBeneficiaries.length; i++) {
            if (assetBeneficiaries[i].tokenId == _tokenId) {
                exists = true;
                break;
            }
        }
        require(exists, "ERC721 tokenId not exists");
    }

    function _validateTokenOwnership(
        address _contractAddress,
        address _owner,
        uint256 _tokenId
    ) private view returns (bool) {
        bool isStillOwner = false;
        address newOwner = IERC721Upgradeable(_contractAddress).ownerOf(_tokenId);
        if (_owner == newOwner) {
            isStillOwner = true;
        }
        return isStillOwner;
    }

    /**
     * @dev Transfers ERC20 and ERC721 tokens approved.
     * If _erc20contracts is empty it will transfer all approved ERC20 assets.
     * If _erc721contracts is empty it will transfer all approved ERC721 assets.
     *
     * Requirements:
     *
     * - `sender` must be a stored backup of some member.
     * - `_erc20contracts` must contain stored ERC20 contract addresses.
     * - `_erc721contracts` must contain stored ERC721 contract addresses.
     * - `_erc721tokensId` must be same length of `_erc721contracts`.
     */
    function transferAssets(
        address[] memory _erc20contracts,
        address[] memory _erc721contracts,
        uint256[][] memory _erc721tokensId
    ) external whenNotPaused nonReentrant {
        require(backupWalletToMember[msg.sender] != address(0), "Associated member not found");
        address member = backupWalletToMember[msg.sender];
        address webacyProxyForMember = address(proxyFactory.deployedContractFromMember(member));
        if (_erc20contracts.length != 0) {
            // Partial transfer
            for (uint256 i = 0; i < _erc20contracts.length; i++) {
                require(
                    memberToContractToAllowableAmount[member][_erc20contracts[i]] != 0,
                    "Contract address not exists"
                );

                uint256 amount = memberToContractToAllowableAmount[member][_erc20contracts[i]];

                uint256 currentAmount = IERC20Upgradeable(_erc20contracts[i]).balanceOf(member);

                if (currentAmount < amount) {
                    amount = currentAmount;
                }

                uint256 feeAmount = calculatePercentage(amount, transferFee);
                uint256 transferAmount = calculatePercentage(amount, 100 - transferFee);

                require(
                    !(memberToContractToTokenStatus[member][_erc20contracts[i]].transferred),
                    "Token already transferred"
                );

                if (!(hasBalance[_erc20contracts[i]])) {
                    hasBalance[_erc20contracts[i]] = true;
                    contractBalances.push(_erc20contracts[i]);
                }
                memberToContractToTokenStatus[member][_erc20contracts[i]] = ERC20TokenStatus(msg.sender, amount, true);

                try
                    IWebacyProxy(webacyProxyForMember).transferErc20TokensAllowed(
                        _erc20contracts[i],
                        member,
                        msg.sender,
                        transferAmount
                    )
                {
                    IWebacyProxy(webacyProxyForMember).transferErc20TokensAllowed(
                        _erc20contracts[i],
                        member,
                        address(this),
                        feeAmount
                    );
                } catch {
                    delete memberToContractToTokenStatus[msg.sender][_erc20contracts[i]];
                }
            }
        }

        if (_erc721contracts.length != 0) {
            require(_erc721contracts.length == _erc721tokensId.length, "ERC721 equally arrays required");
            for (uint256 iContracts = 0; iContracts < _erc721contracts.length; iContracts++) {
                _validateERC721SCExists(_erc721contracts[iContracts], member);
                for (uint256 iTokensId = 0; iTokensId < _erc721tokensId[iContracts].length; iTokensId++) {
                    _validateERC721CollectibleExists(
                        _erc721contracts[iContracts],
                        member,
                        _erc721tokensId[iContracts][iTokensId]
                    );
                    bool isOwner = _validateTokenOwnership(
                        _erc721contracts[iContracts],
                        member,
                        _erc721tokensId[iContracts][iTokensId]
                    );
                    if (isOwner) {
                        memberToContractToAssetStatus[member][_erc721contracts[iContracts]].push(
                            ERC721TokenStatus(msg.sender, _erc721tokensId[iContracts][iTokensId], true)
                        );

                        try
                            IWebacyProxy(webacyProxyForMember).transferErc721TokensAllowed(
                                _erc721contracts[iContracts],
                                member,
                                msg.sender,
                                _erc721tokensId[iContracts][iTokensId]
                            )
                        {
                            continue;
                        } catch {
                            memberToContractToAssetStatus[member][_erc721contracts[iContracts]].pop();
                        }
                    }
                }
            }
        }
    }

    function killswitchTransfer(address _backupWallet)
        external
        whenNotPaused
        hasPaidMembership(msg.sender)
        nonReentrant
    {
        require(backupWalletToMember[_backupWallet] == msg.sender, "Backup and member not match");

        address webacyProxyForMember = address(proxyFactory.deployedContractFromMember(msg.sender));

        // Total ERC20 transfer
        for (uint256 i = 0; i < memberToERC20Contracts[msg.sender].length; i++) {
            address contractAddress = memberToERC20Contracts[msg.sender][i];
            uint256 amount = memberToContractToAllowableAmount[msg.sender][contractAddress];

            require(amount != 0, "Contract address not exists");

            uint256 currentAmount = IERC20Upgradeable(contractAddress).balanceOf(msg.sender);

            if (currentAmount < amount) {
                amount = currentAmount;
            }

            uint256 feeAmount = calculatePercentage(amount, transferFee);
            uint256 transferAmount = calculatePercentage(amount, 100 - transferFee);

            if (!(hasBalance[contractAddress])) {
                hasBalance[contractAddress] = true;
                contractBalances.push(contractAddress);
            }

            if (currentAmount == 0 || memberToContractToTokenStatus[msg.sender][contractAddress].transferred == true)
                continue;

            memberToContractToTokenStatus[msg.sender][contractAddress] = ERC20TokenStatus(_backupWallet, amount, true);

            try
                IWebacyProxy(webacyProxyForMember).transferErc20TokensAllowed(
                    contractAddress,
                    msg.sender,
                    _backupWallet,
                    transferAmount
                )
            {
                IWebacyProxy(webacyProxyForMember).transferErc20TokensAllowed(
                    contractAddress,
                    msg.sender,
                    address(this),
                    feeAmount
                );
            } catch {
                delete memberToContractToTokenStatus[msg.sender][contractAddress];
            }
        }

        // Total ERC721 transfer
        for (uint256 i = 0; i < memberToERC721Contracts[msg.sender].length; i++) {
            address contractAddress = memberToERC721Contracts[msg.sender][i];

            AssetBeneficiary[] memory assetBeneficiaries = memberToContractToAssetBeneficiary[msg.sender][
                contractAddress
            ];

            for (uint256 iAssets = 0; iAssets < assetBeneficiaries.length; iAssets++) {
                bool isOwner = _validateTokenOwnership(
                    contractAddress,
                    msg.sender,
                    assetBeneficiaries[iAssets].tokenId
                );

                if (isOwner) {
                    memberToContractToAssetStatus[msg.sender][contractAddress].push(
                        ERC721TokenStatus(_backupWallet, assetBeneficiaries[iAssets].tokenId, true)
                    );

                    try
                        IWebacyProxy(webacyProxyForMember).transferErc721TokensAllowed(
                            contractAddress,
                            msg.sender,
                            _backupWallet,
                            assetBeneficiaries[iAssets].tokenId
                        )
                    {
                        continue;
                    } catch {
                        memberToContractToAssetStatus[msg.sender][contractAddress].pop();
                    }
                }
            }
        }
    }

    function setProxyFactory(address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        proxyFactory = IWebacyProxyFactory(_address);
    }

    function calculatePercentage(uint256 _amount, uint256 _fee) private pure returns (uint256) {
        _validateBasisPoints(_fee);
        return (_amount * _fee) / 100;
    }

    function _validateBasisPoints(uint256 _transferFee) private pure {
        require((_transferFee >= 0 && _transferFee <= 100), "BasisP must be in range 1-100");
    }

    function setTransferFee(uint256 _transferFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require((_transferFee >= 0 && _transferFee <= 100), "BasisP must be in range 1-100");
        transferFee = _transferFee;
    }

    function withdrawAllBalances(address[] memory _contracts, address _recipient)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address[] memory contractsToIterate;
        if (_contracts.length == 0) {
            contractsToIterate = contractBalances;
        } else {
            contractsToIterate = _contracts;
        }
        for (uint256 i = 0; i < contractsToIterate.length; i++) {
            address iContract = contractsToIterate[i];
            uint256 availableBalance = IERC20Upgradeable(iContract).balanceOf(address(this));
            if (availableBalance > 0) {
                IERC20Upgradeable(iContract).safeTransfer(_recipient, availableBalance);
            }
        }
    }

    function pauseContract() external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpauseContract() external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function deleteStoredData() external hasPaidMembership(msg.sender) {
        removeStoredData(msg.sender);
    }

    function updateStoredData(address _address) external onlyRole(MEMBERSHIP_ROLE) {
        removeStoredData(_address);
    }

    function removeStoredData(address _address) internal {
        //Iterate over backupwallets and update inverse relation
        address[] memory backupWallets = memberToBackupWallets[_address];
        for (uint256 i = 0; i < backupWallets.length; i++) {
            delete backupWalletToMember[backupWallets[i]];
        }
        //Deleting direct relation
        delete memberToBackupWallets[_address];

        //Iterate over nested ERC20 strucuture and deleting
        address[] memory erc20Contracts = memberToERC20Contracts[_address];
        for (uint256 i = 0; i < erc20Contracts.length; i++) {
            TokenBeneficiary[] memory tokenBeneficiaries = memberToContractToTokenBeneficiaries[_address][
                erc20Contracts[i]
            ];
            for (uint256 x = 0; x < tokenBeneficiaries.length; x++) {
                delete tokenBeneficiaryToContractToMember[tokenBeneficiaries[x].desAddress][erc20Contracts[i]];
                if (!(beneficiaryToMember[tokenBeneficiaries[x].desAddress] == address(0))) {
                    delete beneficiaryToMember[tokenBeneficiaries[x].desAddress];
                }
            }
            delete memberToContractToAllowableAmount[_address][erc20Contracts[i]];
            delete memberToContractToTokenBeneficiaries[_address][erc20Contracts[i]];
            delete memberToContractToTokenStatus[_address][erc20Contracts[i]];
        }
        //Deleting direct relation
        delete memberToERC20Contracts[_address];

        //Iterating over  ERC721 strucuture and deleting
        address[] memory erc721Contracts = memberToERC721Contracts[_address];
        for (uint256 y = 0; y < erc721Contracts.length; y++) {
            AssetBeneficiary[] memory assetBeneficiaries = memberToContractToAssetBeneficiary[_address][
                erc721Contracts[y]
            ];

            for (uint256 z = 0; z < assetBeneficiaries.length; z++) {
                delete assetBeneficiaryToContractToMember[assetBeneficiaries[z].desAddress][erc721Contracts[y]];
                if (!(beneficiaryToMember[assetBeneficiaries[z].desAddress] == address(0))) {
                    delete beneficiaryToMember[assetBeneficiaries[z].desAddress];
                }
            }
            delete memberToContractToAssetBeneficiary[_address][erc721Contracts[y]];
            delete memberToContractToAssetStatus[_address][erc721Contracts[y]];
        }
        //Deleting direct relation
        delete memberToERC721Contracts[_address];
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
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
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControl.sol)

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
        _checkRole(role, _msgSender());
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
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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

pragma solidity ^0.8.4;

interface IWebacyProxyFactory {
    function createProxyContract(address _memberAddress) external;

    function deployedContractFromMember(address _memberAddress) external view returns (address);

    function setWebacyAddress(address _webacyAddress) external;

    function pauseContract() external;

    function unpauseContract() external;
    
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IWebacyProxy {
    function transferErc20TokensAllowed(
        address _contractAddress,
        address _ownerAddress,
        address _recipentAddress,
        uint256 _amount
    ) external;

    function transferErc721TokensAllowed(
        address _contractAddress,
        address _ownerAddress,
        address _recipentAddress,
        uint256 _tokenId
    ) external;

    function pauseContract() external;

    function unpauseContract() external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
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