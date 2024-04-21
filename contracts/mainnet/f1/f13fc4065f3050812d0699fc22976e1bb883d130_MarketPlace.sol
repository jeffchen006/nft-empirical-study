// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.16;

import 'src/lib/Compounding.sol';

import 'src/interfaces/IMarketPlace.sol';
import 'src/interfaces/ICreator.sol';
import 'src/interfaces/ISwivel.sol';
import 'src/interfaces/IVaultTracker.sol';
import 'src/interfaces/IZcToken.sol';

contract MarketPlace is IMarketPlace {
    /// @dev A single custom error capable of indicating a wide range of detected errors by providing
    /// an error code value whose string representation is documented <here>, and any possible other values
    /// that are pertinent to the error.
    error Exception(uint8, uint256, uint256, address, address);

    struct Market {
        address cTokenAddr;
        address zcToken;
        address vaultTracker;
        uint256 maturityRate;
    }

    mapping(uint8 => mapping(address => mapping(uint256 => Market)))
        public markets;
    mapping(uint8 => bool) public paused;

    address public admin;
    address public swivel;
    address public immutable creator;

    event Create(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address cToken,
        address zcToken,
        address vaultTracker
    );
    event Mature(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        uint256 maturityRate,
        uint256 matured
    );
    event RedeemZcToken(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address sender,
        uint256 amount
    );
    event RedeemVaultInterest(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address sender
    );
    event CustodialInitiate(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address zcTarget,
        address nTarget,
        uint256 amount
    );
    event CustodialExit(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address zcTarget,
        address nTarget,
        uint256 amount
    );
    event P2pZcTokenExchange(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address from,
        address to,
        uint256 amount
    );
    event P2pVaultExchange(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address from,
        address to,
        uint256 amount
    );
    event TransferVaultNotional(
        uint8 indexed protocol,
        address indexed underlying,
        uint256 indexed maturity,
        address from,
        address to,
        uint256 amount
    );
    event SetAdmin(address indexed admin);

    /// @param c Address of the deployed creator contract
    constructor(address c) {
        admin = msg.sender;
        creator = c;
    }

    /// @param s Address of the deployed swivel contract
    /// @notice We only allow this to be set once
    /// @dev there is no emit here as it's only done once post deploy by the deploying admin
    function setSwivel(address s) external authorized(admin) returns (bool) {
        if (swivel != address(0)) {
            revert Exception(20, 0, 0, swivel, address(0));
        }

        swivel = s;
        return true;
    }

    /// @param a Address of a new admin
    function setAdmin(address a) external authorized(admin) returns (bool) {
        admin = a;

        emit SetAdmin(a);

        return true;
    }

    /// @notice Allows the owner to create new markets
    /// @param p Protocol associated with the new market
    /// @param m Maturity timestamp of the new market
    /// @param c Compounding Token address associated with the new market
    /// @param n Name of the new market zcToken
    /// @dev the memory allocation of `s` is for alleviating STD err, there's no clearly superior scoping or abstracting alternative.
    /// @param s Symbol of the new market zcToken
    function createMarket(
        uint8 p,
        uint256 m,
        address c,
        string calldata n,
        string memory s
    ) external authorized(admin) unpaused(p) returns (bool) {
        if (swivel == address(0)) {
            revert Exception(21, 0, 0, address(0), address(0));
        }

        address underAddr = Compounding.underlying(p, c);

        if (markets[p][underAddr][m].vaultTracker != address(0)) {
            // NOTE: not saving and publishing that found tracker addr as stack limitations...
            revert Exception(22, 0, 0, address(0), address(0));
        }

        (address zct, address tracker) = ICreator(creator).create(
            p,
            underAddr,
            m,
            c,
            swivel,
            n,
            s,
            IERC20(underAddr).decimals()
        );

        markets[p][underAddr][m] = Market(c, zct, tracker, 0);

        emit Create(p, underAddr, m, c, zct, tracker);

        return true;
    }

    /// @notice Can be called after maturity, allowing all of the zcTokens to earn floating interest on Compound until they release their funds
    /// @param p Protocol Enum value associated with the market being matured
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    function matureMarket(
        uint8 p,
        address u,
        uint256 m
    ) public unpaused(p) returns (bool) {
        Market memory market = markets[p][u][m];

        if (market.maturityRate != 0) {
            revert Exception(
                23,
                market.maturityRate,
                0,
                address(0),
                address(0)
            );
        }

        if (block.timestamp < m) {
            revert Exception(24, block.timestamp, m, address(0), address(0));
        }

        // set the base maturity cToken exchange rate at maturity to the current cToken exchange rate
        uint256 xRate = Compounding.exchangeRate(p, market.cTokenAddr);
        markets[p][u][m].maturityRate = xRate;

        // NOTE we don't check the return of this simple operation
        IVaultTracker(market.vaultTracker).matureVault(xRate);

        emit Mature(p, u, m, xRate, block.timestamp);

        return true;
    }

    /// @notice Allows Swivel caller to deposit their underlying, in the process splitting it - minting both zcTokens and vault notional.
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param t Address of the depositing user
    /// @param a Amount of notional being added
    function mintZcTokenAddingNotional(
        uint8 p,
        address u,
        uint256 m,
        address t,
        uint256 a
    ) external authorized(swivel) unpaused(p) returns (bool) {
        Market memory market = markets[p][u][m];

        if (!IZcToken(market.zcToken).mint(t, a)) {
            revert Exception(28, 0, 0, address(0), address(0));
        }

        if (!IVaultTracker(market.vaultTracker).addNotional(t, a)) {
            revert Exception(25, 0, 0, address(0), address(0));
        }

        return true;
    }

    /// @notice Allows Swivel caller to deposit/burn both zcTokens + vault notional. This process is "combining" the two and redeeming underlying.
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param t Address of the combining/redeeming user
    /// @param a Amount of zcTokens being burned
    function burnZcTokenRemovingNotional(
        uint8 p,
        address u,
        uint256 m,
        address t,
        uint256 a
    ) external authorized(swivel) unpaused(p) returns (bool) {
        Market memory market = markets[p][u][m];

        if (!IZcToken(market.zcToken).burn(t, a)) {
            revert Exception(29, 0, 0, address(0), address(0));
        }

        if (!IVaultTracker(market.vaultTracker).removeNotional(t, a)) {
            revert Exception(26, 0, 0, address(0), address(0));
        }

        return true;
    }

    /// @notice Implementation of authRedeem to fulfill the IRedeemer interface for ERC5095
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param f Address of the user having their zcTokens burned
    /// @param t Address of the user receiving underlying
    /// @param a Amount of zcTokens being redeemed
    /// @return Amount of underlying being withdrawn (needed for 5095 return)
    function authRedeem(
        uint8 p,
        address u,
        uint256 m,
        address f,
        address t,
        uint256 a
    )
        external
        authorized(markets[p][u][m].zcToken)
        unpaused(p)
        returns (uint256)
    {
        /// @dev swiv needs to be set or the call to authRedeem there will be faulty
        if (swivel == address(0)) {
            revert Exception(21, 0, 0, address(0), address(0));
        }

        Market memory market = markets[p][u][m];
        // if the market has not matured, mature it...
        if (market.maturityRate == 0) {
            if (!matureMarket(p, u, m)) {
                revert Exception(30, 0, 0, address(0), address(0));
            }
        }

        if (!IZcToken(market.zcToken).burn(f, a)) {
            revert Exception(29, 0, 0, address(0), address(0));
        }

        // depending on initial market maturity status adjust (or don't) the amount to be redemmed/returned
        uint256 amount = market.maturityRate == 0
            ? a
            : calculateReturn(p, u, m, a);

        if (!ISwivel(swivel).authRedeem(p, u, market.cTokenAddr, t, amount)) {
            revert Exception(37, amount, 0, market.cTokenAddr, t);
        }

        emit RedeemZcToken(p, u, m, t, amount);

        return amount;
    }

    /// @notice Allows (via swivel) zcToken holders to redeem their tokens for underlying tokens after maturity has been reached.
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param t Address of the redeeming user
    /// @param a Amount of zcTokens being redeemed
    function redeemZcToken(
        uint8 p,
        address u,
        uint256 m,
        address t,
        uint256 a
    ) external authorized(swivel) unpaused(p) returns (uint256) {
        Market memory market = markets[p][u][m];

        // if the market has not matured, mature it and redeem exactly the amount
        if (market.maturityRate == 0) {
            if (!matureMarket(p, u, m)) {
                revert Exception(30, 0, 0, address(0), address(0));
            }
        }

        if (!IZcToken(market.zcToken).burn(t, a)) {
            revert Exception(29, 0, 0, address(0), address(0));
        }

        emit RedeemZcToken(p, u, m, t, a);

        if (market.maturityRate == 0) {
            return a;
        } else {
            // if the market was already mature the return should include the amount + marginal floating interest generated on Compound since maturity
            return calculateReturn(p, u, m, a);
        }
    }

    /// @notice Allows Vault owners (via Swivel) to redeem any currently accrued interest
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param t Address of the redeeming user
    function redeemVaultInterest(
        uint8 p,
        address u,
        uint256 m,
        address t
    ) external authorized(swivel) unpaused(p) returns (uint256) {
        // call to the floating market contract to release the position and calculate the interest generated
        uint256 interest = IVaultTracker(markets[p][u][m].vaultTracker)
            .redeemInterest(t);

        emit RedeemVaultInterest(p, u, m, t);

        return interest;
    }

    /// @notice Calculates the total amount of underlying returned including interest generated since the `matureMarket` function has been called
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param a Amount of zcTokens being redeemed
    function calculateReturn(
        uint8 p,
        address u,
        uint256 m,
        uint256 a
    ) internal returns (uint256) {
        Market memory market = markets[p][u][m];

        uint256 xRate = Compounding.exchangeRate(p, market.cTokenAddr);

        return (a * xRate) / market.maturityRate;
    }

    /// @notice Return the compounding token address for a given market
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    function cTokenAddress(
        uint8 p,
        address u,
        uint256 m
    ) external view returns (address) {
        return markets[p][u][m].cTokenAddr;
    }

    /// @notice Return the exchange rate for a given protocol's compounding token
    /// @param p Protocol Enum value
    /// @param c Compounding token address
    function exchangeRate(uint8 p, address c) external returns (uint256) {
        return Compounding.exchangeRate(p, c);
    }

    /// @notice Return current rates (maturity, exchange) for a given vault. See VaultTracker.rates for details
    /// @dev While it's true that Compounding exchange rate is not strictly affiliated with a vault, the 2 data points are usually needed together.
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @return maturityRate, exchangeRate*
    function rates(
        uint8 p,
        address u,
        uint256 m
    ) external returns (uint256, uint256) {
        return IVaultTracker(markets[p][u][m].vaultTracker).rates();
    }

    /// @notice Called by swivel IVFZI && IZFVI
    /// @dev Call with protocol, underlying, maturity, mint-target, add-notional-target and an amount
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param z Recipient of the minted zcToken
    /// @param n Recipient of the added notional
    /// @param a Amount of zcToken minted and notional added
    function custodialInitiate(
        uint8 p,
        address u,
        uint256 m,
        address z,
        address n,
        uint256 a
    ) external authorized(swivel) unpaused(p) returns (bool) {
        Market memory market = markets[p][u][m];
        if (!IZcToken(market.zcToken).mint(z, a)) {
            revert Exception(28, 0, 0, address(0), address(0));
        }

        if (!IVaultTracker(market.vaultTracker).addNotional(n, a)) {
            revert Exception(25, 0, 0, address(0), address(0));
        }

        emit CustodialInitiate(p, u, m, z, n, a);
        return true;
    }

    /// @notice Called by swivel EVFZE FF EZFVE
    /// @dev Call with protocol, underlying, maturity, burn-target, remove-notional-target and an amount
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param z Owner of the zcToken to be burned
    /// @param n Target to remove notional from
    /// @param a Amount of zcToken burned and notional removed
    function custodialExit(
        uint8 p,
        address u,
        uint256 m,
        address z,
        address n,
        uint256 a
    ) external authorized(swivel) unpaused(p) returns (bool) {
        Market memory market = markets[p][u][m];
        if (!IZcToken(market.zcToken).burn(z, a)) {
            revert Exception(29, 0, 0, address(0), address(0));
        }

        if (!IVaultTracker(market.vaultTracker).removeNotional(n, a)) {
            revert Exception(26, 0, 0, address(0), address(0));
        }

        emit CustodialExit(p, u, m, z, n, a);
        return true;
    }

    /// @notice Called by swivel IZFZE, EZFZI
    /// @dev Call with underlying, maturity, transfer-from, transfer-to, amount
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param f Owner of the zcToken to be burned
    /// @param t Target to be minted to
    /// @param a Amount of zcToken transfer
    function p2pZcTokenExchange(
        uint8 p,
        address u,
        uint256 m,
        address f,
        address t,
        uint256 a
    ) external authorized(swivel) unpaused(p) returns (bool) {
        address zct = markets[p][u][m].zcToken;

        if (!IZcToken(zct).burn(f, a)) {
            revert Exception(29, 0, 0, address(0), address(0));
        }

        if (!IZcToken(zct).mint(t, a)) {
            revert Exception(28, 0, 0, address(0), address(0));
        }

        emit P2pZcTokenExchange(p, u, m, f, t, a);
        return true;
    }

    /// @notice Called by swivel IVFVE, EVFVI
    /// @dev Call with protocol, underlying, maturity, remove-from, add-to, amount
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param f Owner of the notional to be transferred
    /// @param t Target to be transferred to
    /// @param a Amount of notional transfer
    function p2pVaultExchange(
        uint8 p,
        address u,
        uint256 m,
        address f,
        address t,
        uint256 a
    ) external authorized(swivel) unpaused(p) returns (bool) {
        if (
            !IVaultTracker(markets[p][u][m].vaultTracker).transferNotionalFrom(
                f,
                t,
                a
            )
        ) {
            revert Exception(27, 0, 0, address(0), address(0));
        }

        emit P2pVaultExchange(p, u, m, f, t, a);
        return true;
    }

    /// @notice External method giving access to this functionality within a given vault
    /// @dev Note that this method calculates yield and interest as well
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param t Target to be transferred to
    /// @param a Amount of notional to be transferred
    function transferVaultNotional(
        uint8 p,
        address u,
        uint256 m,
        address t,
        uint256 a
    ) external unpaused(p) returns (bool) {
        if (
            !IVaultTracker(markets[p][u][m].vaultTracker).transferNotionalFrom(
                msg.sender,
                t,
                a
            )
        ) {
            revert Exception(27, 0, 0, address(0), address(0));
        }

        emit TransferVaultNotional(p, u, m, msg.sender, t, a);
        return true;
    }

    /// @notice Transfers notional fee to the Swivel contract without recalculating marginal interest for from
    /// @param p Protocol Enum value associated with this market
    /// @param u Underlying token address associated with the market
    /// @param m Maturity timestamp of the market
    /// @param f Owner of the amount
    /// @param a Amount to transfer
    function transferVaultNotionalFee(
        uint8 p,
        address u,
        uint256 m,
        address f,
        uint256 a
    ) external authorized(swivel) returns (bool) {
        return
            IVaultTracker(markets[p][u][m].vaultTracker).transferNotionalFee(
                f,
                a
            );
    }

    /// @notice Called by admin at any point to pause / unpause market transactions in a specified protocol
    /// @param p Protocol Enum value of the protocol to be paused
    /// @param b Boolean which indicates the (protocol) markets paused status
    function pause(uint8 p, bool b) external authorized(admin) returns (bool) {
        paused[p] = b;
        return true;
    }

    modifier authorized(address a) {
        if (msg.sender != a) {
            revert Exception(0, 0, 0, msg.sender, a);
        }
        _;
    }

    modifier unpaused(uint8 p) {
        if (paused[p]) {
            revert Exception(1, 0, 0, address(0), address(0));
        }
        _;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

import 'src/Protocols.sol';

import 'src/lib/LibCompound.sol';

import 'src/interfaces/IERC4626.sol';
import 'src/interfaces/ICERC20.sol';
import 'src/interfaces/IAavePool.sol';
import 'src/interfaces/IAaveToken.sol';
import 'src/interfaces/IEulerToken.sol';
import 'src/interfaces/ICompoundToken.sol';
import 'src/interfaces/ILidoToken.sol';
import 'src/interfaces/IYearnVault.sol';

library Compounding {
    /// @param p Protocol Enum value
    /// @param c Compounding token address
    function underlying(uint8 p, address c) internal view returns (address) {
        if (p == uint8(Protocols.Compound) || p == uint8(Protocols.Rari)) {
            return ICompoundToken(c).underlying();
        } else if (p == uint8(Protocols.Yearn)) {
            return IYearnVault(c).token();
        } else if (p == uint8(Protocols.Aave)) {
            return IAaveToken(c).UNDERLYING_ASSET_ADDRESS();
        } else if (p == uint8(Protocols.Euler)) {
            return IEulerToken(c).underlyingAsset();
        } else if (p == uint8(Protocols.Lido)) {
            return ILidoToken(c).stETH();
        } else {
            return IERC4626(c).asset();
        }
    }

    /// @param p Protocol Enum value
    /// @param c Compounding token address
    function exchangeRate(uint8 p, address c) internal returns (uint256) {
        // in contrast to the below, LibCompound provides a lower gas alternative to exchangeRateCurrent()
        if (p == uint8(Protocols.Compound)) {
            return LibCompound.viewExchangeRate(ICERC20(c));
            // with the removal of LibFuse we will direct Rari to the exposed Compound CToken methodology
        } else if (p == uint8(Protocols.Rari)) {
            return ICompoundToken(c).exchangeRateCurrent();
        } else if (p == uint8(Protocols.Yearn)) {
            return IYearnVault(c).pricePerShare();
        } else if (p == uint8(Protocols.Aave)) {
            IAaveToken aToken = IAaveToken(c);
            return
                IAavePool(aToken.POOL()).getReserveNormalizedIncome(
                    aToken.UNDERLYING_ASSET_ADDRESS()
                );
        } else if (p == uint8(Protocols.Euler)) {
            // NOTE: the 1e26 const is a degree of precision to enforce on the return
            return IEulerToken(c).convertBalanceToUnderlying(1e26);
        } else if (p == uint8(Protocols.Lido)) {
            return ILidoToken(c).stEthPerToken();
        } else {
            // NOTE: the 1e26 const is a degree of precision to enforce on the return
            return IERC4626(c).convertToAssets(1e26);
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IMarketPlace {
    function setSwivel(address) external returns (bool);

    function setAdmin(address) external returns (bool);

    function createMarket(
        uint8,
        uint256,
        address,
        string memory,
        string memory
    ) external returns (bool);

    function matureMarket(
        uint8,
        address,
        uint256
    ) external returns (bool);

    function authRedeem(
        uint8,
        address,
        uint256,
        address,
        address,
        uint256
    ) external returns (uint256);

    function exchangeRate(uint8, address) external returns (uint256);

    function rates(
        uint8,
        address,
        uint256
    ) external returns (uint256, uint256);

    function transferVaultNotional(
        uint8,
        address,
        uint256,
        address,
        uint256
    ) external returns (bool);

    // adds notional and mints zctokens
    function mintZcTokenAddingNotional(
        uint8,
        address,
        uint256,
        address,
        uint256
    ) external returns (bool);

    // removes notional and burns zctokens
    function burnZcTokenRemovingNotional(
        uint8,
        address,
        uint256,
        address,
        uint256
    ) external returns (bool);

    // returns the amount of underlying principal to send
    function redeemZcToken(
        uint8,
        address,
        uint256,
        address,
        uint256
    ) external returns (uint256);

    // returns the amount of underlying interest to send
    function redeemVaultInterest(
        uint8,
        address,
        uint256,
        address
    ) external returns (uint256);

    // returns the cToken address for a given market
    function cTokenAddress(
        uint8,
        address,
        uint256
    ) external returns (address);

    // EVFZE FF EZFVE call this which would then burn zctoken and remove notional
    function custodialExit(
        uint8,
        address,
        uint256,
        address,
        address,
        uint256
    ) external returns (bool);

    // IVFZI && IZFVI call this which would then mint zctoken and add notional
    function custodialInitiate(
        uint8,
        address,
        uint256,
        address,
        address,
        uint256
    ) external returns (bool);

    // IZFZE && EZFZI call this, tranferring zctoken from one party to another
    function p2pZcTokenExchange(
        uint8,
        address,
        uint256,
        address,
        address,
        uint256
    ) external returns (bool);

    // IVFVE && EVFVI call this, removing notional from one party and adding to the other
    function p2pVaultExchange(
        uint8,
        address,
        uint256,
        address,
        address,
        uint256
    ) external returns (bool);

    // IVFZI && IVFVE call this which then transfers notional from msg.sender (taker) to swivel
    function transferVaultNotionalFee(
        uint8,
        address,
        uint256,
        address,
        uint256
    ) external returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface ICreator {
    function create(
        uint8,
        address,
        uint256,
        address,
        address,
        string calldata,
        string calldata,
        uint8
    ) external returns (address, address);

    function setAdmin(address) external returns (bool);

    function setMarketPlace(address) external returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

import 'src/lib/Hash.sol';
import 'src/lib/Sig.sol';

// the behavioral Swivel Interface, Implemented by Swivel.sol
interface ISwivel {
    function initiate(
        Hash.Order[] calldata,
        uint256[] calldata,
        Sig.Components[] calldata
    ) external returns (bool);

    function exit(
        Hash.Order[] calldata,
        uint256[] calldata,
        Sig.Components[] calldata
    ) external returns (bool);

    function cancel(Hash.Order[] calldata) external returns (bool);

    function setAdmin(address) external returns (bool);

    function scheduleWithdrawal(address) external returns (bool);

    function scheduleFeeChange(uint16[4] calldata) external returns (bool);

    function blockWithdrawal(address) external returns (bool);

    function blockFeeChange() external returns (bool);

    function withdraw(address) external returns (bool);

    function changeFee(uint16[4] calldata) external returns (bool);

    function approveUnderlying(address[] calldata, address[] calldata)
        external
        returns (bool);

    function splitUnderlying(
        uint8,
        address,
        uint256,
        uint256
    ) external returns (bool);

    function combineTokens(
        uint8,
        address,
        uint256,
        uint256
    ) external returns (bool);

    function authRedeem(
        uint8,
        address,
        address,
        address,
        uint256
    ) external returns (bool);

    function redeemZcToken(
        uint8,
        address,
        uint256,
        uint256
    ) external returns (bool);

    function redeemVaultInterest(
        uint8,
        address,
        uint256
    ) external returns (bool);

    function redeemSwivelVaultInterest(
        uint8,
        address,
        uint256
    ) external returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IVaultTracker {
    function addNotional(address, uint256) external returns (bool);

    function removeNotional(address, uint256) external returns (bool);

    function redeemInterest(address) external returns (uint256);

    function matureVault(uint256) external returns (bool);

    function transferNotionalFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function transferNotionalFee(address, uint256) external returns (bool);

    function rates() external returns (uint256, uint256);

    function balancesOf(address) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IZcToken {
    function mint(address, uint256) external returns (bool);

    function burn(address, uint256) external returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

enum Protocols {
    Erc4626,
    Compound,
    Rari,
    Yearn,
    Aave,
    Euler,
    Lido
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import {FixedPointMathLib} from 'src/lib/FixedPointMathLib.sol';

import 'src/interfaces/ICERC20.sol';

/// @notice Get up to date cToken data without mutating state.
/// @author Transmissions11 (https://github.com/transmissions11/libcompound)
library LibCompound {
    using FixedPointMathLib for uint256;

    function viewUnderlyingBalanceOf(ICERC20 cToken, address user)
        internal
        view
        returns (uint256)
    {
        return cToken.balanceOf(user).mulWadDown(viewExchangeRate(cToken));
    }

    function viewExchangeRate(ICERC20 cToken) internal view returns (uint256) {
        uint256 accrualBlockNumberPrior = cToken.accrualBlockNumber();

        if (accrualBlockNumberPrior == block.number)
            return cToken.exchangeRateStored();

        uint256 totalCash = cToken.underlying().balanceOf(address(cToken));
        uint256 borrowsPrior = cToken.totalBorrows();
        uint256 reservesPrior = cToken.totalReserves();

        uint256 borrowRateMantissa = cToken.interestRateModel().getBorrowRate(
            totalCash,
            borrowsPrior,
            reservesPrior
        );

        require(borrowRateMantissa <= 0.0005e16, 'RATE_TOO_HIGH'); // Same as borrowRateMaxMantissa in CTokenInterfaces.sol

        uint256 interestAccumulated = (borrowRateMantissa *
            (block.number - accrualBlockNumberPrior)).mulWadDown(borrowsPrior);

        uint256 totalReserves = cToken.reserveFactorMantissa().mulWadDown(
            interestAccumulated
        ) + reservesPrior;
        uint256 totalBorrows = interestAccumulated + borrowsPrior;
        uint256 totalSupply = cToken.totalSupply();

        return
            totalSupply == 0
                ? cToken.initialExchangeRateMantissa()
                : (totalCash + totalBorrows - totalReserves).divWadDown(
                    totalSupply
                );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IERC4626 {
    function deposit(uint256, address) external returns (uint256);

    function withdraw(
        uint256,
        address,
        address
    ) external returns (uint256);

    /// @dev Converts the given 'assets' (uint256) to 'shares', returning that amount
    function convertToAssets(uint256) external view returns (uint256);

    /// @dev The address of the underlying asset
    function asset() external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (bool);

    function allowance(address, address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);

    function decimals() external returns (uint8);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

interface InterestRateModel {
    function getBorrowRate(
        uint256,
        uint256,
        uint256
    ) external view returns (uint256);

    function getSupplyRate(
        uint256,
        uint256,
        uint256,
        uint256
    ) external view returns (uint256);
}

interface ICERC20 is IERC20 {
    function mint(uint256) external returns (uint256);

    function borrow(uint256) external returns (uint256);

    function underlying() external view returns (IERC20);

    function totalBorrows() external view returns (uint256);

    function totalFuseFees() external view returns (uint256);

    function repayBorrow(uint256) external returns (uint256);

    function totalReserves() external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function totalAdminFees() external view returns (uint256);

    function fuseFeeMantissa() external view returns (uint256);

    function adminFeeMantissa() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function accrualBlockNumber() external view returns (uint256);

    function redeemUnderlying(uint256) external returns (uint256);

    function balanceOfUnderlying(address) external returns (uint256);

    function reserveFactorMantissa() external view returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function interestRateModel() external view returns (InterestRateModel);

    function initialExchangeRateMantissa() external view returns (uint256);

    function repayBorrowBehalf(address, uint256) external returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IAavePool {
    /// @dev Returns the normalized income of the reserve given the address of the underlying asset of the reserve
    function getReserveNormalizedIncome(address)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IAaveToken {
    // @dev Deployed ddress of the associated Aave Pool
    function POOL() external view returns (address);

    /// @dev The address of the underlying asset
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IEulerToken {
    /// @notice Convert an eToken balance to an underlying amount, taking into account current exchange rate
    function convertBalanceToUnderlying(uint256)
        external
        view
        returns (uint256);

    /// @dev The address of the underlying asset
    function underlyingAsset() external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface ICompoundToken {
    function exchangeRateCurrent() external returns (uint256);

    /// @dev The address of the underlying asset
    function underlying() external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface ILidoToken {
    /// @dev The address of the stETH underlying asset
    function stETH() external view returns (address);

    /// @notice Returns amount of stETH for one wstETH
    function stEthPerToken() external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

interface IYearnVault {
    function pricePerShare() external view returns (uint256);

    /// @dev The address of the underlying asset
    function token() external view returns (address);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

/**
  @notice Encapsulation of the logic to produce EIP712 hashed domain and messages.
  Also to produce / verify hashed and signed Orders.
  See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md
  See/attribute https://github.com/0xProject/0x-monorepo/blob/development/contracts/utils/contracts/src/LibEIP712.sol
*/

library Hash {
    /// @dev struct represents the attributes of an offchain Swivel.Order
    struct Order {
        bytes32 key;
        uint8 protocol;
        address maker;
        address underlying;
        bool vault;
        bool exit;
        uint256 principal;
        uint256 premium;
        uint256 maturity;
        uint256 expiry;
    }

    // EIP712 Domain Separator typeHash
    // keccak256(abi.encodePacked(
    //     'EIP712Domain(',
    //     'string name,',
    //     'string version,',
    //     'uint256 chainId,',
    //     'address verifyingContract',
    //     ')'
    // ));
    bytes32 internal constant DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // EIP712 typeHash of an Order
    // keccak256(abi.encodePacked(
    //     'Order(',
    //     'bytes32 key,',
    //     'uint8 protocol,',
    //     'address maker,',
    //     'address underlying,',
    //     'bool vault,',
    //     'bool exit,',
    //     'uint256 principal,',
    //     'uint256 premium,',
    //     'uint256 maturity,',
    //     'uint256 expiry',
    //     ')'
    // ));
    bytes32 internal constant ORDER_TYPEHASH =
        0xbc200cfe92556575f801f821f26e6d54f6421fa132e4b2d65319cac1c687d8e6;

    /// @param n EIP712 domain name
    /// @param version EIP712 semantic version string
    /// @param i Chain ID
    /// @param verifier address of the verifying contract
    function domain(
        string memory n,
        string memory version,
        uint256 i,
        address verifier
    ) internal pure returns (bytes32) {
        bytes32 hash;

        assembly {
            let nameHash := keccak256(add(n, 32), mload(n))
            let versionHash := keccak256(add(version, 32), mload(version))
            let pointer := mload(64)
            mstore(pointer, DOMAIN_TYPEHASH)
            mstore(add(pointer, 32), nameHash)
            mstore(add(pointer, 64), versionHash)
            mstore(add(pointer, 96), i)
            mstore(add(pointer, 128), verifier)
            hash := keccak256(pointer, 160)
        }

        return hash;
    }

    /// @param d Type hash of the domain separator (see Hash.domain)
    /// @param h EIP712 hash struct (order for example)
    function message(bytes32 d, bytes32 h) internal pure returns (bytes32) {
        bytes32 hash;

        assembly {
            let pointer := mload(64)
            mstore(
                pointer,
                0x1901000000000000000000000000000000000000000000000000000000000000
            )
            mstore(add(pointer, 2), d)
            mstore(add(pointer, 34), h)
            hash := keccak256(pointer, 66)
        }

        return hash;
    }

    /// @param o A Swivel Order
    function order(Order calldata o) internal pure returns (bytes32) {
        // TODO assembly
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    o.key,
                    o.protocol,
                    o.maker,
                    o.underlying,
                    o.vault,
                    o.exit,
                    o.principal,
                    o.premium,
                    o.maturity,
                    o.expiry
                )
            );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.13;

library Sig {
    /// @dev ECDSA V,R and S components encapsulated here as we may not always be able to accept a bytes signature
    struct Components {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    error S();
    error V();
    error Length();
    error ZeroAddress();

    /// @param h Hashed data which was originally signed
    /// @param c signature struct containing V,R and S
    /// @return The recovered address
    function recover(bytes32 h, Components calldata c)
        internal
        pure
        returns (address)
    {
        // EIP-2 and malleable signatures...
        // see https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol
        if (
            uint256(c.s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            revert S();
        }

        if (c.v != 27 && c.v != 28) {
            revert V();
        }

        address recovered = ecrecover(h, c.v, c.r, c.s);

        if (recovered == address(0)) {
            revert ZeroAddress();
        }

        return recovered;
    }

    /// @param sig Valid ECDSA signature
    /// @return v The verification bit
    /// @return r First 32 bytes
    /// @return s Next 32 bytes
    function split(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        if (sig.length != 65) {
            revert Length();
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                              CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error ExpOverflow();

    error Undefined();

    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    function powWad(int256 x, int256 y) internal pure returns (int256) {
        // Equivalent to x to the power of y because x ** y = (e ** ln(x)) ** y = e ** (ln(x) * y)
        return expWad((lnWad(x) * y) / int256(WAD)); // Using ln(x) means x must be greater than 0.
    }

    function expWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            // When the result is < 0.5 we return zero. This happens when
            // x <= floor(log(0.5e18) * 1e18) ~ -42e18
            if (x <= -42139678854452767551) return 0;

            // When the result is > (2**255 - 1) / 1e18 we can not represent it as an
            // int. This happens when x >= floor(log((2**255 - 1) / 1e18) * 1e18) ~ 135.
            if (x >= 135305999368893231589) revert ExpOverflow();

            // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
            // for more intermediate precision and a binary basis. This base conversion
            // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
            x = (x << 78) / 5**18;

            // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers
            // of two such that exp(x) = exp(x') * 2**k, where k is an integer.
            // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2**95) >>
                96;
            x = x - k * 54916777467707473351141471128;

            // k is in the range [-61, 195].

            // Evaluate using a (6, 7)-term rational approximation.
            // p is made monic, we'll multiply by a scale factor later.
            int256 y = x + 1346386616545796478920950773328;
            y = ((y * x) >> 96) + 57155421227552351082224309758442;
            int256 p = y + x - 94201549194550492254356042504812;
            p = ((p * y) >> 96) + 28719021644029726153956944680412240;
            p = p * x + (4385272521454847904659076985693276 << 96);

            // We leave p in 2**192 basis so we don't need to scale it back up for the division.
            int256 q = x - 2855989394907223263936484059900;
            q = ((q * x) >> 96) + 50020603652535783019961831881945;
            q = ((q * x) >> 96) - 533845033583426703283633433725380;
            q = ((q * x) >> 96) + 3604857256930695427073651918091429;
            q = ((q * x) >> 96) - 14423608567350463180887372962807573;
            q = ((q * x) >> 96) + 26449188498355588339934803723976023;

            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial won't have zeros in the domain as all its roots are complex.
                // No scaling is necessary because p is already 2**96 too large.
                r := sdiv(p, q)
            }

            // r should be in the range (0.09, 0.25) * 2**96.

            // We now need to multiply r by:
            // * the scale factor s = ~6.031367120.
            // * the 2**k factor from the range reduction.
            // * the 1e18 / 2**96 factor for base conversion.
            // We do this all at once, with an intermediate result in 2**213
            // basis, so the final right shift is always by a positive amount.
            r = int256(
                (uint256(r) *
                    3822833074963236453042738258902158003155416615667) >>
                    uint256(195 - k)
            );
        }
    }

    function lnWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            if (x < 0) revert Undefined();

            // We want to convert x from 10**18 fixed point to 2**96 fixed point.
            // We do this by multiplying by 2**96 / 10**18. But since
            // ln(x * C) = ln(x) + ln(C), we can simply do nothing here
            // and add ln(2**96 / 10**18) at the end.

            // Reduce range of x to (1, 2) * 2**96
            // ln(2^k * x) = k * ln(2) + ln(x)
            int256 k = int256(log2(uint256(x))) - 96;
            x <<= uint256(159 - k);
            x = int256(uint256(x) >> 159);

            // Evaluate using a (8, 8)-term rational approximation.
            // p is made monic, we will multiply by a scale factor later.
            int256 p = x + 3273285459638523848632254066296;
            p = ((p * x) >> 96) + 24828157081833163892658089445524;
            p = ((p * x) >> 96) + 43456485725739037958740375743393;
            p = ((p * x) >> 96) - 11111509109440967052023855526967;
            p = ((p * x) >> 96) - 45023709667254063763336534515857;
            p = ((p * x) >> 96) - 14706773417378608786704636184526;
            p = p * x - (795164235651350426258249787498 << 96);

            // We leave p in 2**192 basis so we don't need to scale it back up for the division.
            // q is monic by convention.
            int256 q = x + 5573035233440673466300451813936;
            q = ((q * x) >> 96) + 71694874799317883764090561454958;
            q = ((q * x) >> 96) + 283447036172924575727196451306956;
            q = ((q * x) >> 96) + 401686690394027663651624208769553;
            q = ((q * x) >> 96) + 204048457590392012362485061816622;
            q = ((q * x) >> 96) + 31853899698501571402653359427138;
            q = ((q * x) >> 96) + 909429971244387300277376558375;
            assembly {
                // Div in assembly because solidity adds a zero check despite the unchecked.
                // The q polynomial is known not to have zeros in the domain.
                // No scaling required because p is already 2**96 too large.
                r := sdiv(p, q)
            }

            // r is in the range (0, 0.125) * 2**96

            // Finalization, we need to:
            // * multiply by the scale factor s = 5.549…
            // * add ln(2**96 / 10**18)
            // * add k * ln(2)
            // * multiply by 10**18 / 2**96 = 5**18 >> 78

            // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
            r *= 1677202110996718588342820967067443963516166;
            // add ln(2) * k * 5e18 * 2**192
            r +=
                16597577552685614221487285958193947469193820559219878177908093499208371 *
                k;
            // add ln(2**96 / 10**18) * 5e18 * 2**192
            r += 600920179829731861736702779321621459595472258049074101567377883020018308;
            // base conversion: mul 2**18 / 2**192
            r >>= 174;
        }
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(
                and(
                    iszero(iszero(denominator)),
                    or(iszero(x), eq(div(z, x), y))
                )
            ) {
                revert(0, 0)
            }

            // Divide z by the denominator.
            z := div(z, denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            // Store x * y in z for now.
            z := mul(x, y)

            // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
            if iszero(
                and(
                    iszero(iszero(denominator)),
                    or(iszero(x), eq(div(z, x), y))
                )
            ) {
                revert(0, 0)
            }

            // First, divide z - 1 by the denominator and add 1.
            // We allow z - 1 to underflow if z is 0, because we multiply the
            // end result by 0 if z is zero, ensuring we return 0 if z is zero.
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function log2(uint256 x) internal pure returns (uint256 r) {
        if (x < 0) revert Undefined();

        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, shl(1, lt(0x3, shr(r, x))))
            r := or(r, lt(0x1, shr(r, x)))
        }
    }
}