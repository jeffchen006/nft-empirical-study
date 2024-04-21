/**
 *Submitted for verification at Etherscan.io on 2022-11-08
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);
}

interface IProject {
    function claimRank(uint256 term) external;

    function claimMintReward() external;
}

interface IMint {
    function claim() external;
}

contract Mint {
    // address owner = 0xFbA0014D3a9DBe8A0cda6AFfd3da7b541a1Ec32f;
    // address _contract = 0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8;
    // address _contract =  0xca41f293A32d25c2216bC4B30f5b0Ab61b6ed2CB; //testnet

    constructor(uint8 _term) public {
        IProject(address(0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8)).claimRank(_term);
    }

    function claim() external {
        address  owner = 0xFbA0014D3a9DBe8A0cda6AFfd3da7b541a1Ec32f;
        address  _contract =  0x06450dEe7FD2Fb8E39061434BAbCFC05599a6Fb8; 

        IProject(_contract).claimMintReward();
        uint256 balance = IERC20(_contract).balanceOf(address(this));
        IERC20(_contract).transfer(owner, balance);

        delete  owner;
        delete  _contract;
    }
}

contract factory {
    // address[] public addrs;
    event Log(address);

    function deploy(uint8 _count, uint8 _term) public {
        for (uint8 i = 0; i < _count; i++) {
            Mint addr = new Mint(_term);
            emit Log(address(addr));
            // addrs.push(address(addr));
        }
    }

    function batchClaimReward( address[] memory  addrs) public {
        uint256 len = addrs.length;
        for (uint256 i = 0; i < len; i++) {
            try IMint(addrs[i]).claim() {} catch {}
        }
    }

}