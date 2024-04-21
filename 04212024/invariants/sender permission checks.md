require(account==_msgSender(),"")
[Code File](../../contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L1867)

require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender())||hasRole(SC_GATEWAY_ORACLE_ROLE,_msgSender()),"")
[Code File](../../contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1116)

require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender())||hasRole(SC_MINTER_ROLE,_msgSender()),"")
[Code File](../../contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1121)

require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender()),"")
[Code File](../../contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1126)

require(kotketGatewayOracle.hasRole(DEFAULT_ADMIN_ROLE,msg.sender)||kotketGatewayOracle.hasRole(SC_GATEWAY_ORACLE_ROLE,msg.sender),"")
[Code File](../../contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1161)

require(msg.sender==address(this),"")
[Code File](../../contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L81)

require(msg.sender!=item.seller,"")
[Code File](../../contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L360)

require(msg.sender==item.seller,"")
[Code File](../../contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L469)

require(msg.sender==address(endpoint))
[Code File](../../contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L141)

require(listedNFT.seller==msg.sender,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L224)

require(loveToken.balanceOf(msg.sender)>=platformListingFee,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L229)

require(params.offerer==msg.sender,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L337)

require(msg.sender==list.seller,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L366)

require(auction.creator==msg.sender,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L445)

require(treasury==msg.sender,"")
[Code File](../../contracts/mainnet/dc/dc4838bb0496b351875d7e418f91f1a49d060b5f_NFTMarket.sol#L454)

require(sender!=address(0),"")
[Code File](../../contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L855)

require(senderBalance>=amount,"")
[Code File](../../contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L861)

require(msg.sender!=_admin(),"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1659)

require(msg.sender==_admin(),"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1762)

require(msg.sender==governor||msg.sender==_admin())
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1944)

require(makes[makeID].maker==msg.sender,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2142)

require(takes[takeID].taker==msg.sender,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2178)

require(msg.sender==takes[takeID].taker,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2188)

require(msg.sender==makes[makeID].maker,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2201)

require(msg.sender==makes[makeID].maker||msg.sender==takes[takeID].taker,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2214)

require(tx.origin==msg.sender,"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L142)

require(!winners[launchpadId][_msgSender()],"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L721)

require(_winners[i]!=msg.sender,"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L761)

require(winners[launchpadId][_msgSender()],"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L786)

require(!isClaimed[launchpadId][_msgSender()],"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L789)

require(verify(msg.sender,msg.sender,_transferData.amount,_transferData.encodeKey,_transferData.nonce,_transferData.signature),"")
[Code File](../../contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L509)

require(verify(msg.sender,msg.sender,_buyData.amount,_buyData.encodeKey,_buyData.nonce,_buyData.signature),"")
[Code File](../../contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L569)

require(verify(msg.sender,msg.sender,_createData.amount,_createData.encodeKey,_createData.nonce,_createData.signature),"")
[Code File](../../contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L597)

require(mod==msg.sender,"")
[Code File](../../contracts/mainnet/9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol#L61)

require(msg.sender==Operator,"")
[Code File](../../contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1381)

require(_referrer!=_msgSender(),"")
[Code File](../../contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L73)

require(parentRefMap[_msgSender()]==address(0)||parentRefMap[_msgSender()]==_referrer,"")
[Code File](../../contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L75)

require(parentRefMap[_msgSender()]!=address(0),"")
[Code File](../../contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L82)

require(kotketToken.balanceOf(_msgSender())>=price,"")
[Code File](../../contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L150)

require(receiver!=sender)
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L82)

require(swap.maker!=msg.sender)
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L108)

require(swap.maker==msg.sender)
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L152)

require(BERC20.allowance(msg.sender,address(this))>=_offer,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L776)

require(msg.sender!=listedNft.seller,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L923)

require(listedNft.seller==msg.sender,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L964)

require(BERC20.allowance(msg.sender,address(this))>=_amount,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1018)

require(auction.maxBidUser==msg.sender||msg.sender==auction.seller,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1050)

require(auction.seller==msg.sender,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1099)

require(IERC1155(_nft).balanceOf(msg.sender,tokenId)>=amount,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1121)

require(IERC1155(_nft).isApprovedForAll(msg.sender,address(this)),"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1122)

require(msg.sender!=idToListing1155[listingId].seller,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1148)

require(msg.sender==idToListing1155[_listingId].seller,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1204)

require(rentalItemInfoMap[_tokenId].renter==_msgSender(),"")
[Code File](../../contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L172)

require(kotketToken.balanceOf(_msgSender())>=priceInPeriod,"")
[Code File](../../contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L235)

require(msg.sender==tokenMarkets[tokenId].bidder,"")
[Code File](../../contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L100)

require(bidderInfo[itemId].bidderAddress==msg.sender,"")
[Code File](../../contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2220)

require(msg.sender==MNFTMarketplace,"")
[Code File](../../contracts/mainnet/88/887067939fA33E1c9B755B222fE92BAd2717691b_TransferManagerERC1155.sol#L23)

require(nftListing.listedBy!=_sender,"")
[Code File](../../contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3552)

require(authorizedManagers.contains(msg.sender),"")
[Code File](../../contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1674)

require(collections[_collection].creator==msg.sender,"")
[Code File](../../contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1698)

require(collection.listings[_tokenId].seller==msg.sender,"")
[Code File](../../contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1750)

require(operator!=_msgSender(),"")
[Code File](../../contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L1193)

require(IERC721(nftContract).isApprovedForAll(msg.sender,address(this)),"")
[Code File](../../contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L139)

require(item.seller==msg.sender,"")
[Code File](../../contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L187)

require(erc20.balanceOf(_msgSender())>=price,"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L542)

require(msg.sender==yfiagPool,"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L264)

require(_launchPad==msg.sender,"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L537)

require(hasRole(MINTER_ROLE,_msgSender()),"")
[Code File](../../contracts/mainnet/7b/7b380299C8eDA4527C83174918199d702611e876_APONFT.sol#L1520)

require(hasRole(PAUSER_ROLE,_msgSender()),"")
[Code File](../../contracts/mainnet/7b/7b380299C8eDA4527C83174918199d702611e876_APONFT.sol#L1537)

require(whiteList(presaleDatas[_salesTime].whiteListAddress).checkWhiteListRemainAmount(msg.sender)>=1)
[Code File](../../contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1114)

require(swaps[swapId].seller==msg.sender,"")
[Code File](../../contracts/mainnet/4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol#L2582)

require(IERC20(tokenAddress[_tokenId]).balanceOf(msg.sender)>=_price,"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L120)

require(IERC20(_token).balanceOf(msg.sender)>=_price,"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L209)

require(IERC20(_token).balanceOf(msg.sender)>=_amount,"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L224)

require(ammo.balanceOf(msg.sender)>=minimumAcceptedBid,"")
[Code File](../../contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L990)

require(msg.sender==listIds[listId].currentWinner)
[Code File](../../contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L1031)

require(ammo.balanceOf(msg.sender)>=price,"")
[Code File](../../contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L1032)

require(msg.sender==_seller,"")
[Code File](../../contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1406)

require(order.seller==msg.sender,"")
[Code File](../../contracts/mainnet/11/115ac133b7267ea05d146caa64d4140425a43dc8_EmillionNftMarketPlace.sol#L1340)

require(hasRole(ROLE_ADMIN,msg.sender),"")
[Code File](../../contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L74)

require(msg.sender==marketPlace)
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2948)

require(msg.sender==order.maker)
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3271)

require(validationLogic.validateBuyNow(sellOrder,msg.sender))
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3314)

require(msg.sender!=sellOrder.maker,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3315)

require(msg.sender==sellOrder.maker||msg.sender==buyOrder.maker||aggregator[msg.sender],"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3386)

require(validationLogic.validateMatch_(sellOrder,buyOrder,msg.sender,false))
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3387)

require(viewOnly||sender!=buyOrder.maker,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3606)

require(viewOnly||sender!=sellOrder.maker,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3628)

require(mintedTotal[msg.sender]<maxCountPerWallet,"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1355)

require(msg.sender!=address(0),"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1382)

require(msg.sender!=cruiseOperationsWallet,"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1454)

require(msg.sender==cruiseOperationsWallet,"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1473)

require(msg.sender==daoContract,"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1497)

require(_msgSender()==_taxWallet)
[Code File](../../contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L340)

require(_msgSender()!=operator,"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L295)

require(BundNFT.balanceOf(msg.sender)>=basePriceRareNFT.mul(_copiesNFT),"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L719)

require(BundNFT.balanceOf(msg.sender)>=basePriceSpecialNFT.mul(_copiesNFT),"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L731)

require(BundNFT.balanceOf(msg.sender)>=basePriceLegendNFT,"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L743)

require(_signer==msg.sender&&_signer==voucher.target)
[Code File](../../contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1818)

require(_signer!=msg.sender)
[Code File](../../contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1840)

require(voucher.isAuction?voucher.target==msg.sender:voucher.target==_signer)
[Code File](../../contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1848)

require(payable(msg.sender).send(address(this).balance))
[Code File](../../contracts/mainnet/3d/3dc7941f028f7b5e862c8d04960d154be31bec0a_InseparableNFTMarketplace.sol#L3322)

require(msg.sender!=idToMarketItem[itemId].seller,"")
[Code File](../../contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L142)

require(highestBidderMapping[itemId].bidderAddr==msg.sender,"")
[Code File](../../contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L196)

require(_msgSender()==_developmentWalletAddress||_msgSender()==_marketingWalletAddress)
[Code File](../../contracts/mainnet/25/255Fa6E3C319b5C27317bF3eEd08BAa22F0D0D06_ShibariumNFTMarketplace.sol#L439)

