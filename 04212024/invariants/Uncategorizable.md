require(_binConf.erc20==_buyItNowToken,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L186)

require(_offer.offerERC20==_offerToken,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L227)

require(validOfferERC20[address(weth)],"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L274)

require(validOfferERC20[_offerToken],"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L289)

require(validOfferERC20[_token]!=_isValid,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L492)

require(_percent<=(DENOMENATOR*10)/100,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L510)

require(marketplaceEnabled!=_isEnabled,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L523)

require(nonceAfter==nonceBefore+1,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L804)

require(abi.decode(returndata,(bool)),"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L821)

require(isTokenAllowed(token),"")
[Code File](../../contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L389)

require(!paused(),"")
[Code File](../../contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L484)

require(_status!=_ENTERED,"")
[Code File](../../contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L1454)

require(paused(),"")
[Code File](../../contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L1545)

require(tokenContract.getApproved(tokenId)==address(this),"")
[Code File](../../contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L315)

require(item.state==ON_MARKET,"")
[Code File](../../contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L357)

require(recoverSigner(message,signature)==admin,"")
[Code File](../../contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L85)

require(_gene<=uint8(KOTKET_GENES.KING),"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L43)

require(_commission<=1000,"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L44)

require(kotketNFT.tokenExisted(_tokenId),"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L65)

require(kotketNFT.getApproved(_tokenId)==address(this),"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L67)

require(kotketNFT.isApprovedForAll(governance.kotketWallet(),address(this)),"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L83)

require(kotketToken.allowance(governance.kotketWallet(),address(this))>=benefit,"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L124)

require(allowance>=price,"")
[Code File](../../contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L91)

require(_exists(tokenId),"")
[Code File](../../contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1203)

require(_checkOnERC721Received(from,to,tokenId,_data),"")
[Code File](../../contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1319)

require(!_exists(tokenId),"")
[Code File](../../contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1391)

require(auctionNft.addr==nft.addr&&auctionNft.tokenId==nft.tokenId,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L193)

require(offer.offerer==params.offerer&&offer.offerPrice==params.price,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L205)

require(params.price>MINIMUM_BUYING_FEE,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L216)

require(price>=listedNft.price,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L285)

require(bidPrice>=auction.highestBid+auction.minBidStep,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L465)

require(loveToken.transfer(feeReceiver,amount),"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L534)

require(loveToken.transfer(creator,amount),"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L604)

require(feeNumerator<=_feeDenominator(),"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L887)

require(currentAllowance>=amount,"")
[Code File](../../contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L787)

require(!_initializing&&_initialized<version,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L136)

require(makes[makeID].status==Status.None,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2143)

require(takes[takeID].status<=Status.Paid,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2180)

require(takes[takeID].status==Status.Take,"")
[Code File](../../contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2189)

require(blockNumber<=block.number,"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L226)

require(amount>=launchpad.minTotalStake,"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L449)

require(!hasWithdrawFund[uint24(launchpadIds[i])],"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L833)

require(hasSetLaunchpadWinner[uint24(launchpadIds[i])],"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L834)

require(_initialized<version,"")
[Code File](../../contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L332)

require(supply>=amount,"")
[Code File](../../contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1301)

require(!isDuplicate(__uri),"")
[Code File](../../contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1382)

require(weiAmount>=kotketPriceMap[gene].eWei,"")
[Code File](../../contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L120)

require(tokenAllowance>=price,"")
[Code File](../../contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L153)

require(!ArrayUtils.hasDuplicate(asset.ids))
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L88)

require(isAllowedCollection(asset.collection))
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L90)

require(swap.status==Status.CREATED)
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L107)

requiredIdsCount++
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L134)

require(BERC20.allowance(_offerer,address(this))>=offerAmount,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L829)

require(success0,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L942)

require(_amount>=auction.price,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1017)

require(auction.bidAmounts[lastIndex]<_amount,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1030)

require(BERC20.allowance(auction.maxBidUser,address(this))>=auction.maxBid,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1058)

require(idToListing1155[listingId].completed==false,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1151)

require(idToListing1155[listingId].tokensAvailable>=amount,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1152)

require(idToListing1155[_listingId].completed==false,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1205)

require(_serviceCommissionByDay<=1000,"")
[Code File](../../contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L55)

require(_interestRate<=1000,"")
[Code File](../../contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L83)

require(rentalItemInfoMap[_tokenId].renter==_beneficiary,"")
[Code File](../../contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L210)

require(newFeePortion<=1000,"")
[Code File](../../contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L170)

require(denominator>prod1)
[Code File](../../contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L318)

require(_checkOnERC721Received(from,to,tokenId,data),"")
[Code File](../../contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L1408)

require(nftSoldData[voucher.signature]<numberOfNfts,"")
[Code File](../../contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2096)

require(campaignId==voucherToCampaignID[voucher.signature],"")
[Code File](../../contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2099)

require(numberOfNfts==1,"")
[Code File](../../contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2172)

require(currentlyOnAuction[itemId].nftID==itemId,"")
[Code File](../../contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2196)

require(gotNewMaxTokenSupply>_maxTokenSupply,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L458)

require(_tokenIds.current()!=_maxTokenSupply,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L467)

require(MarketItemDatabase[tokenId].forSale==true,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L485)

require(MarketItemDatabase[tokenId].forSale==false,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L512)

require(mpWallets[sendTo]>=withdrawAmount,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L528)

require(_startAt>depositItemInfoMap[_tokenId].endAt,"")
[Code File](../../contracts/mainnet/bc/bc3Fc7bf165456d059012Cd9873F2999Bdd4de56_EKotketNFTPlatformRenting.sol#L102)

require(_current>depositItemInfoMap[_tokenId].endAt,"")
[Code File](../../contracts/mainnet/bc/bc3Fc7bf165456d059012Cd9873F2999Bdd4de56_EKotketNFTPlatformRenting.sol#L116)

require(usdtAllowance>=_amountUSDT,"")
[Code File](../../contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L49)

require(kokeAllowance>=amountKOKE,"")
[Code File](../../contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L60)

require(kokeAllowance>=_amountKOKE,"")
[Code File](../../contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L79)

require(usdtAllowance>=amountUSDT,"")
[Code File](../../contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L90)

require(_initializing||_isConstructor()||!_initialized,"")
[Code File](../../contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L211)

require(_listedNftTokenIds.contains(_nftListingId),"")
[Code File](../../contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3538)

require(nftListing.paymentType==1,"")
[Code File](../../contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3602)

require(!authorizedManagers.contains(_manager),"")
[Code File](../../contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1660)

require(authorizedManagers.contains(_manager),"")
[Code File](../../contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1667)

require(_fee<101,"")
[Code File](../../contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1675)

require(_winrate<=1000,"")
[Code File](../../contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L49)

require(!tokenExisted(_tokenId),"")
[Code File](../../contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L71)

require(index<ERC721Enumerable.totalSupply(),"")
[Code File](../../contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L1892)

require(address(this)!=__self,"")
[Code File](../../contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L830)

require(_getImplementation()==__self,"")
[Code File](../../contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L831)

require(address(this)==__self,"")
[Code File](../../contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L840)

require(slot==_IMPLEMENTATION_SLOT,"")
[Code File](../../contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L2587)

require(currentImplementation!=_newImplementation)
[Code File](../../contracts/mainnet/43/438AbFE329C0F38c02C971B8d34307beB06aD778_IndigenaNFTMarketplace.sol#L185)

require(itemId<=_itemCounter.current(),"")
[Code File](../../contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L183)

require(marketItems[itemId].state==State.Created,"")
[Code File](../../contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L184)

require(item.state==State.Created,"")
[Code File](../../contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L218)

require(IERC721(nftContract).isApprovedForAll(item.seller,address(this)),"")
[Code File](../../contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L220)

require(_fee<=10000,"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L399)

require(amount>=englishAuctions[_nftContract][_tokenId].amount,"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L607)

require(startPrice>endPrice,"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L719)

require(start<end,"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L720)

require(isInEnglishAuction(_nftContract,tokenId),"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L885)

require(isInDutchAuction(_nftContract,tokenId),"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L905)

require(isBeingSold(_nftContract,tokenId),"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L915)

require(_from<_to,"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L85)

require(_newFee<=1000,"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L218)

require(_royalty<=maxRoyalties&&_royalty>=minRoyalties,"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L276)

require(exists(_tokenId),"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L542)

require(exists(tokenId),"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L621)

require(!exists(tokenId),"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L736)

require(index<totalSupply(),"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L888)

require(ERC721.exists(tokenId),"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L948)

require(presaleFinished[_offerId]==false,"")
[Code File](../../contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1113)

require(recoverSigner(message,signature)==_admin,"")
[Code File](../../contracts/mainnet/db/db891C608eeB12c1A0842Cb2A96BC58E65E5d971_NFTMarketplace.sol#L76)

require(swaps[swapId].status==Status.None,"")
[Code File](../../contracts/mainnet/4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol#L2583)

require(_newFee<10000,"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L63)

require(_royalty+platformFee<10000,"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L79)

require(_newRoyalty>royalties[_tokenId]&&_newRoyalty<=10000&&_newRoyalty+platformFee<=10000,"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L179)

require(isLock(_tokenId),"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L187)

require(!isLock(_tokenId),"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1361)

require(ERC721.exists(tokenId))
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1601)

require(!isAdmin(_user),"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1639)

require(item.status==ListingStatus.Active,"")
[Code File](../../contracts/mainnet/ca/caE3aB3D711bccCaE4f2C58ce0F146EB8bB840Bf_NFTMarketplace.sol#L1488)

require(_serviceCommission<=1000,"")
[Code File](../../contracts/mainnet/b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol#L36)

require(weiAmount>=price,"")
[Code File](../../contracts/mainnet/b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol#L84)

require(marketRegistrations[_nftContract]==nullBytes,"")
[Code File](../../contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1369)

require(_conductKey==marketRegistrations[_nftContract]&&_conductKey!=nullBytes,"")
[Code File](../../contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1405)

require(_status==ListingStatus.Active,"")
[Code File](../../contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1407)

require(_royaltyFeePercent+_marketFeePercent<=10000,"")
[Code File](../../contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1426)

require(_basisPointFee<10000,"")
[Code File](../../contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L99)

require(_basisPointFee<=10000,"")
[Code File](../../contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L154)

require(nftTokenAddress==tbnNftAddress,"")
[Code File](../../contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L250)

require(listingIds.contains(listingId),"")
[Code File](../../contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L293)

require(amount<=MAX_ROYALTY)
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2314)

require(!IERC165(nftContract).supportsInterface(0x2a55205a),"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2335)

require(_newPublic<=MAX_PROTOCOL_FEE)
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2346)

require(_newProfile<=MAX_PROTOCOL_FEE)
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2352)

require(_discount<=10000)
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2374)

require(optionalNftAssets[0].assetType.assetClass==LibAsset.ERC721_ASSET_CLASS,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2416)

require(success3,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2425)

require(success1&&success2,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2435)

require(order.maker!=address(0x0),"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2867)

require(validateOrder(hash,order,sig))
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3192)

require(marketplaceEvent.emitBuyNow(sellHash,sellOrder,v,r,s))
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3365)

require(marketplaceEvent.emitExecuteSwap(sellHash,buyHash,sellOrder,buyOrder,v,r,s))
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3439)

require(buyMakeAddress==sellTakeAddress,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3507)

require(sellOrder.auctionType==LibSignature.AuctionType.Decreasing,"")
[Code File](../../contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3693)

require(!dentistCoinNFT.exists(_tokenId),"")
[Code File](../../contracts/mainnet/1a/1a22d99d1853b8804ea5c95c87dfdef8a41f6c88_DentistCoinNFTMarketPlace.sol#L766)

require(_exists(_tokenId),"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1384)

require(cruiseSelect.votingCount>=_decreaseCount,"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1499)

require(amount<=_maxTxAmount,"")
[Code File](../../contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L253)

require(_newFee<=_finalBuyTax&&_newFee<=_finalSellTax)
[Code File](../../contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L341)

require(mintedNFT[RareNFT]<copiesRareNFT,"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L718)

require(mintedNFT[SpecialNFT]<copiesSpecialNFT,"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L730)

require(mintedNFT[LegendNFT]<copiesLegendNFT,"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L742)

require(changeToIsForSale?!item.isForSale:item.isForSale)
[Code File](../../contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1936)

require(newSc<100000)
[Code File](../../contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L2154)

require(_newFee<=MAX_PROTOCOL_FEE)
[Code File](../../contracts/mainnet/d4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol#L2355)

require(params.optionalNftAssets[0].assetType.assetClass==LibAsset.ERC721_ASSET_CLASS,"")
[Code File](../../contracts/mainnet/d4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol#L2494)

require(royalityPerc<=100,"")
[Code File](../../contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L82)

require(_newNftContract!=nftContractAddress,"")
[Code File](../../contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L295)

require(listingFee!=_listingPercentage,"")
[Code File](../../contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L317)

require(_listingPercentage<=200,"")
[Code File](../../contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L318)

require(totalFees<=100,"")
[Code File](../../contracts/mainnet/25/255Fa6E3C319b5C27317bF3eEd08BAa22F0D0D06_ShibariumNFTMarketplace.sol#L577)

