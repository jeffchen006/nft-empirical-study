/**
 *Submitted for verification at Etherscan.io on 2022-11-01
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.8.0;
contract Homework {
mapping(address => string) public submitters;
function store(string memory student_id) public {
submitters[msg.sender] = student_id;
}
}