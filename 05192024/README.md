Explored both energy trading smart contracts and lottery smart contracts. 


1. Searched over 20 most cited papers containing keywords "energy", "trading" and "smart contract", as listed in [file](../energyTradingExamples/README.md). Unfortunately, none of the papers has Solidity/Vyper code available. There is only one paper that has a code snippet for energy trading, but it is written in Python and Javascript.

We should either ash Aron to provide us more guidance on how to search energy trading smart contracts, or we should work on lottery smart contracts.


2. Lottery smart contracts. 

The reasons I selected lottery smart contracts are:

(i) Lottery Smart Contracts are popular: I find 955 instances of lottery smart contracts from the open sourced smart contracts on EtherScan. They are collected under the [folder](../selectedLotteryContracts/)

(ii) Lottery Smart Contracts are simple and have universal features: almost all of them has a process of buying tickets, drawing winners, and distributing rewards. 

(iii) Lottery Smart Contracts contain bugs. By simply manually reviewing the code, I found 1 bug which could be checked by VeriSolid, see details in [file](../selectedLotteryContracts/README.md). This example is very similar to "King of the Ether" example in the VeriSolid paper, I believe it is a good example to start with. I'm confident that we can find more bugs in other lottery smart contracts.

I also collected the function frequencies of lottery smart contracts, see [file](../selectedLotteryContracts/README.md). This information could be useful to decompose the functions to lower-level primitives, but for now, I prefer to first confirm with Aron and Anastasia before moving forward.


