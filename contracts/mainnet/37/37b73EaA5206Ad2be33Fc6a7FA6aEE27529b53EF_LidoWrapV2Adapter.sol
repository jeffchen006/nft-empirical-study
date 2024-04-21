/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

/**
 * @title LidoWrapV2Adapter
 * @author Jasper Finance
 *
 * Wrap adapter for Yearn that returns data for wraps/unwraps of tokens
 */
contract LidoWrapV2Adapter {
    /* ============ Modifiers ============ */


    // Address of Curve Eth/StEth stableswap pool.
    //0xDC24316b9AE028F1497c275EB9192a3Ea0f67022
    address  public stableswap;
    //weth address
    address public weth; 
    // Index for ETH for Curve stableswap pool.
    int128 internal constant ETH_INDEX = 0;            
    // Index for stETH for Curve stableswap pool.
    int128 internal constant STETH_INDEX = 1;    
    /**
     * Throws if the underlying/wrapped token pair is not valid
     */
    modifier _onlyValidTokenPair(
        address _underlyingToken,
        address _wrappedToken
    ) {
        require(
            validTokenPair(_underlyingToken, _wrappedToken),
            "Must be a valid token pair"
        );
        _;
    }
    address public constant ETH_TOKEN_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


       

    /* ============ Constructor ============ */
    constructor(address _stableswap,address _weth) public {
        //Address of Curve Eth/StEth stableswap pool.
        stableswap=_stableswap;
        weth=_weth;
    }
    /* ============ External Getter Functions ============ */
    /**
     * Generates the calldata to wrap an underlying asset into a wrappedToken.
     *
     * @param _underlyingToken      Address of the component to be wrapped 给的币
     * @param _wrappedToken         Address of the desired wrapped token 要换的币
     * @param _underlyingUnits      Total quantity of underlying units to wrap 数量
     *
     * @return address              Target contract address
     * @return uint256              Total quantity of underlying units (if underlying is ETH)
     * @return bytes                Wrap calldata
     */
     
    function getWrapCallData(
        address _underlyingToken,
        address _wrappedToken,
        uint256 _underlyingUnits,
        address, /* _to */
        bytes memory /* _wrapData */
    )
        external
        view
        _onlyValidTokenPair(_underlyingToken, _wrappedToken)
        returns (
            address,
            uint256,
            bytes memory
        )
    {      
        bytes memory callData = abi.encodeWithSignature(
            "submit(address)",
            0x0000000000000000000000000000000000000000
        );
        return (address(_wrappedToken), _underlyingUnits, callData);
    }

    /**
     * Generates the calldata to unwrap a wrapped asset into its underlying.
     *
     * @param _underlyingToken      Address of the underlying asset
     * @param _wrappedToken         Address of the component to be unwrapped
     * @param _wrappedTokenUnits    Total quantity of wrapped token units to unwrap
     *
     * @return address              Target contract address
     * @return uint256              Total quantity of wrapped token units to unwrap. This will always be 0 for unwrapping
     * @return bytes                Unwrap calldata
     */
    function getUnwrapCallData(
        address _underlyingToken,
        address _wrappedToken,
        uint256 _wrappedTokenUnits,
        address, /* _to */
        bytes memory /* _unwrapData */
    )
        external
        view
        _onlyValidTokenPair(_underlyingToken, _wrappedToken)
        returns (
            address,
            uint256,
            bytes memory
        )
    {
        bytes memory callData = abi.encodeWithSignature(
            "exchange(int128,int128,uint256,uint256)",
            STETH_INDEX,
            ETH_INDEX,
            _wrappedTokenUnits,
            1
        );
        return (address(stableswap), 0, callData);
    }
    /**
     * Returns the address to approve source tokens for wrapping.
     *
     * @return address        Address of the contract to approve tokens to
     */
    function getSpenderAddress(
        address _underlyingToken,
        address _wrappedToken
    ) external view returns (address) {
        if(weth==_underlyingToken){
            return address(stableswap);
        }
        return address(_wrappedToken);
    }
    /* ============ Internal Functions ============ */
    /**
     * Validates the underlying and wrapped token pair
     *
     * @param _underlyingToken     Address of the underlying asset
     * @param _wrappedToken        Address of the wrapped asset
     *
     * @return bool                Whether or not the wrapped token accepts the underlying token as collateral
     */
    function validTokenPair(address _underlyingToken, address _wrappedToken)
        internal
        view
        returns (bool)
    {
        return true;
    }
}