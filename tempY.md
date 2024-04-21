Path: /home/zhiychen/Documents/smart-contract-sanctuary-ethereum/contracts/cache.json
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L146)
sender ownerOf
require(_nft.ownerOf(_tokenId)==msg.sender,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L180)
enforce specification
require(marketplaceEnabled,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L185)
owner permission checks
require(_binConf.creator==_nft.ownerOf(_tokenId),"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L186)
filtered
require(_binConf.erc20==_buyItNowToken,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L187)
amount enforcement
require(_binConf.amount==_buyItNowAmount,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L226)
sender ownerOf
require(msg.sender==_nft.ownerOf(_tokenId),"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L227)
filtered
require(_offer.offerERC20==_offerToken,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L228)
amount enforcement
require(_offer.amount==_offerAmount,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L270)
sender ownerOf
require(_nft.ownerOf(_tokenId)!=msg.sender,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L273)
msg.value control
require(msg.value>addOfferFee,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L274)
filtered
require(validOfferERC20[address(weth)],"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L288)
msg.value control
require(msg.value==addOfferFee,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L289)
filtered
require(validOfferERC20[_offerToken],"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L298)
enforce specification
require(_success,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L310)
Ignore: check with 0
require(expiration==0||expiration>block.timestamp,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L341)
sender ownerOf
require(_offer.owner==msg.sender,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L377)
owner permission checks
require(_offer.owner!=address(0),"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L412)
msg.value control
require(msg.value>=_amount,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L419)
enforce specification
require(_royaltySuccess,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L426)
enforce specification
require(_treasSuccess,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L430)
balance control
require(address(this).balance>=_before-_amount)
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L460)
owner permission checks
require(_nft.ownerOf(_tokenId)==_oldOwner,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L492)
filtered
require(validOfferERC20[_token]!=_isValid,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L510)
filtered
require(_percent<=(DENOMENATOR*10)/100,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L523)
filtered
require(marketplaceEnabled!=_isEnabled,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L533)
Ignore: check with 0
require(_amount>0)
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L592)
sender ownerOf
require(owner()==_msgSender(),"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L611)
owner permission checks
require(newOwner!=address(0),"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L785)
msg.value control
require(oldAllowance>=value,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L804)
filtered
require(nonceAfter==nonceBefore+1,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L821)
filtered
require(abi.decode(returndata,(bool)),"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L996)
balance control
require(address(this).balance>=amount,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L999)
enforce specification
require(success,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L1069)
msg.value control
require(address(this).balance>=value,"")
[Code File](contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L1070)
EOA validation
require(isContract(target),"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L296)
msg.value control
require(msg.value==price,"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L389)
filtered
require(isTokenAllowed(token),"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L484)
filtered
require(!paused(),"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L641)
enforce specification
require(sent,"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L1139)
Ignore: check with 0
require(value==0,"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L1454)
filtered
require(_status!=_ENTERED,"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L1545)
filtered
require(paused(),"")
[Code File](contracts/mainnet/c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol#L1867)
sender permission checks
require(account==_msgSender(),"")
[Code File](contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L288)
Ignore: safe math
require(b<=a,errorMessage)
[Code File](contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L311)
Ignore: check with 0
require(b>0,errorMessage)
[Code File](contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1116)
sender permission checks
require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender())||hasRole(SC_GATEWAY_ORACLE_ROLE,_msgSender()),"")
[Code File](contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1121)
sender permission checks
require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender())||hasRole(SC_MINTER_ROLE,_msgSender()),"")
[Code File](contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1126)
sender permission checks
require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender()),"")
[Code File](contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1138)
address(0)
require(_governanceAdress!=address(0),"")
[Code File](contracts/mainnet/b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol#L1161)
sender permission checks
require(kotketGatewayOracle.hasRole(DEFAULT_ADMIN_ROLE,msg.sender)||kotketGatewayOracle.hasRole(SC_GATEWAY_ORACLE_ROLE,msg.sender),"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L81)
sender permission checks
require(msg.sender==address(this),"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L314)
sender ownerOf
require(tokenContract.ownerOf(tokenId)==msg.sender,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L315)
filtered
require(tokenContract.getApproved(tokenId)==address(this),"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L317)
Ignore: check with 0
require(purchasePrice>0||startingBidPrice>0,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L318)
Ignore: check with 0
require(startingBidPrice==0||biddingTime>60,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L355)
array length control
require(id<itemsOnMarket.length,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L357)
filtered
require(item.state==ON_MARKET,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L358)
msg.value control
require(msg.value>=item.purchasePrice,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L359)
Ignore: check with 0
require(item.purchasePrice>0,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L360)
sender permission checks
require(msg.sender!=item.seller,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L389)
address(0)
require(block.timestamp<item.auctionEndTime||item.highestBidder==address(0),"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L392)
msg.value control
require(msg.value>=item.bidPrice*nextBidPricePercentage/100,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L394)
msg.value control
require(msg.value>=item.bidPrice,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L439)
Ignore: check with 0
require(item.bidPrice>0,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L440)
address(0)
require(item.highestBidder!=address(0),"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L441)
time control
require(block.timestamp>item.auctionEndTime,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L469)
sender permission checks
require(msg.sender==item.seller,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L470)
time control
require(block.timestamp>=item.listingCreationTime+delistCooldown,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L471)
address(0)
require(item.highestBidder==address(0),"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L472)
Ignore: check with 0
require(reducedBidPrice>0||reducedPrice>0,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L510)
time control
require(block.timestamp>=item.listingCreationTime+600,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L537)
enforce specification
require(result,"")
[Code File](contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L548)
array length control
require(0<bidHistoryLength,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L85)
filtered
require(recoverSigner(message,signature)==admin,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L90)
msg.value control
require(price==msg.value,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L98)
owner permission checks
require(assetOwner!=address(0),"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L99)
owner permission checks
require(assetOwner!=buyer,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L104)
Ignore: check with 0
require(orderId!=0,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L247)
sender ownerOf
require(sender==assetOwner,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L253)
Ignore: check with 0
require(priceAsset>0,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L289)
Ignore: check with 0
require(order.id!=0,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L481)
Ignore: safe math
require(c>=a,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L533)
Ignore: safe math
require(c/a==b,"")
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L600)
Ignore: check with 0
require(b!=0,errorMessage)
[Code File](contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L2487)
array length control
require(sig.length==65)
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L43)
filtered
require(_gene<=uint8(KOTKET_GENES.KING),"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L44)
filtered
require(_commission<=1000,"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L52)
owner permission checks
require(depositItemInfoMap[_tokenId].owner!=address(0),"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L65)
filtered
require(kotketNFT.tokenExisted(_tokenId),"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L66)
sender ownerOf
require(kotketNFT.ownerOf(_tokenId)==_msgSender(),"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L67)
filtered
require(kotketNFT.getApproved(_tokenId)==address(this),"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L80)
sender ownerOf
require(depositItemInfoMap[_tokenId].owner==_msgSender(),"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L83)
filtered
require(kotketNFT.isApprovedForAll(governance.kotketWallet(),address(this)),"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L120)
Ignore: check with 0
require(benefit>0,"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L123)
balance control
require(kotketToken.balanceOf(governance.kotketWallet())>=benefit,"")
[Code File](contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L124)
filtered
require(kotketToken.allowance(governance.kotketWallet(),address(this))>=benefit,"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L84)
time control
require(block.timestamp>startTime,"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L85)
time control
require(block.timestamp<endTime,"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L91)
filtered
require(allowance>=price,"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L141)
sender permission checks
require(msg.sender==address(endpoint))
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L188)
Ignore: check with 0
require(remaining>0,"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1172)
owner permission checks
require(owner!=address(0),"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1203)
filtered
require(_exists(tokenId),"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1223)
owner permission checks
require(to!=owner,"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1265)
sender ownerOf
require(_isApprovedOrOwner(_msgSender(),tokenId),"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1319)
filtered
require(_checkOnERC721Received(from,to,tokenId,_data),"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1390)
address(0)
require(to!=address(0),"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1391)
filtered
require(!_exists(tokenId),"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1441)
owner permission checks
require(ERC721.ownerOf(tokenId)==from,"")
[Code File](contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1476)
owner permission checks
require(owner!=operator,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L187)
Ignore: check with 0
require(listedNFT.seller==address(0)&&listedNFT.price==0,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L193)
filtered
require(auctionNft.addr==nft.addr&&auctionNft.tokenId==nft.tokenId,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L199)
address(0)
require(auction.nft.addr==address(0)||auction.success,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L205)
filtered
require(offer.offerer==params.offerer&&offer.offerPrice==params.price,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L206)
enforce specification
require(!offer.accepted,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L215)
time control
require(block.timestamp<=params.startTime&&params.endTime>params.startTime,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L216)
filtered
require(params.price>MINIMUM_BUYING_FEE,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L224)
sender permission checks
require(listedNFT.seller==msg.sender,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L227)
sender ownerOf
require(nftContract.ownerOf(params.nft.tokenId)==msg.sender,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L229)
sender permission checks
require(loveToken.balanceOf(msg.sender)>=platformListingFee,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L285)
filtered
require(price>=listedNft.price,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L337)
sender permission checks
require(params.offerer==msg.sender,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L366)
sender permission checks
require(msg.sender==list.seller,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L370)
sender ownerOf
require(IERC721(params.nft.addr).ownerOf(params.nft.tokenId)==msg.sender,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L405)
sender ownerOf
require(nft.ownerOf(params.nft.tokenId)==msg.sender,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L445)
sender permission checks
require(auction.creator==msg.sender,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L446)
enforce specification
require(!auction.success,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L447)
address(0)
require(auction.lastBidder==address(0),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L463)
time control
require(block.timestamp>=auction.startTime,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L464)
time control
require(block.timestamp<=auction.endTime,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L465)
filtered
require(bidPrice>=auction.highestBid+auction.minBidStep,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L532)
address(0)
require(feeReceiver!=address(0),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L533)
balance control
require(getAvailableBalance()>=amount,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L534)
filtered
require(loveToken.transfer(feeReceiver,amount),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L551)
address(0)
require(newFeeReceiver!=address(0),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L583)
time control
require(block.timestamp>auction.endTime,"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L604)
filtered
require(loveToken.transfer(creator,amount),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L887)
filtered
require(feeNumerator<=_feeDenominator(),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L888)
address(0)
require(receiver!=address(0),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L1249)
sender ownerOf
require(users[msg.sender][role]||msg.sender==owner(),"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L1254)
enforce specification
require(!users[account][role],"")
[Code File](contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L1261)
enforce specification
require(users[account][role],"")
[Code File](contracts/mainnet/dc/dc4838bb0496b351875d7e418f91f1a49d060b5f_NFTMarket.sol#L454)
sender permission checks
require(treasury==msg.sender,"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L787)
filtered
require(currentAllowance>=amount,"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L828)
msg.value control
require(currentAllowance>=subtractedValue,"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L855)
sender permission checks
require(sender!=address(0),"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L856)
address(0)
require(recipient!=address(0),"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L861)
sender permission checks
require(senderBalance>=amount,"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L882)
address(0)
require(account!=address(0),"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L910)
balance control
require(accountBalance>=amount,"")
[Code File](contracts/mainnet/60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol#L940)
address(0)
require(spender!=address(0),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L136)
filtered
require(!_initializing&&_initialized<version,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L149)
enforce specification
require(_initializing,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L160)
enforce specification
require(!_initializing,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L479)
address(0)
require(from!=address(0),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L485)
balance control
require(fromBalance>=amount,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1536)
address(0)
require(newImplementation==address(0)||AddressUpgradeable.isContract(newImplementation),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1604)
address(0)
require(newAdmin!=address(0),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1630)
enforce specification
require(success)
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1659)
sender permission checks
require(msg.sender!=_admin(),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1762)
sender permission checks
require(msg.sender==_admin(),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1944)
sender permission checks
require(msg.sender==governor||msg.sender==_admin())
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L1972)
address(0)
require(newGovernor!=address(0))
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2077)
Ignore: check with 0
require(_entered==0,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2129)
enforce specification
require(!make_.isBid,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2141)
address(0)
require(makes[makeID].maker!=address(0),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2142)
sender permission checks
require(makes[makeID].maker==msg.sender,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2143)
filtered
require(makes[makeID].status==Status.None,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2178)
sender permission checks
require(takes[takeID].taker==msg.sender,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2180)
filtered
require(takes[takeID].status<=Status.Paid,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2188)
sender permission checks
require(msg.sender==takes[takeID].taker,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2189)
filtered
require(takes[takeID].status==Status.Take,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2198)
address(0)
require(takes[takeID].taker!=address(0),"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2201)
sender permission checks
require(msg.sender==makes[makeID].maker,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2214)
sender permission checks
require(msg.sender==makes[makeID].maker||msg.sender==takes[takeID].taker,"")
[Code File](contracts/mainnet/60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol#L2228)
enforce specification
require(isArbiter[msg.sender],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L138)
array length control
require(launchpadId<launchpads.length,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L142)
sender permission checks
require(tx.origin==msg.sender,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L149)
address(0)
require(_yfiagNftMarketplace!=address(0),"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L150)
EOA validation
require(_yfiagNftMarketplace.isContract(),"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L226)
filtered
require(blockNumber<=block.number,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L449)
filtered
require(amount>=launchpad.minTotalStake,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L550)
enforce specification
require(!addElseSub,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L625)
Ignore: check with 0
require(_weightAccrualRate!=0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L626)
time control
require(_endTime>_startTime,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L627)
time control
require(_endTime>block.timestamp,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L628)
address(0)
require(address(stakeToken)!=address(0),"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L629)
EOA validation
require(stakeToken.isContract(),"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L630)
sender ownerOf
require(IYFIAGNftMarketplace(yfiagNftMarketplace).isOwnerOfRoot(_rootId,msg.sender),"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L677)
Ignore: check with 0
require(amount>0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L682)
time control
require(launchpad.startTime<block.timestamp,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L685)
time control
require(block.timestamp<launchpad.endTime,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L691)
enforce specification
require(!isDisabled,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L714)
enforce specification
require(launchpadDisabled[launchpadId],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L721)
sender permission checks
require(!winners[launchpadId][_msgSender()],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L730)
Ignore: check with 0
require(userCheckpointCount>0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L739)
Ignore: check with 0
require(checkpoint.staked>0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L757)
enforce specification
require(!launchpadDisabled[launchpadId],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L758)
Ignore: check with 0
require(_winners.length>0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L759)
array length control
require(_winners.length<=IYFIAGNftMarketplace(yfiagNftMarketplace).getMaxFragment(),"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L761)
sender permission checks
require(_winners[i]!=msg.sender,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L762)
enforce specification
require(isStakers[launchpadId][_winners[i]],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L763)
address(0)
require(_winners[i]!=address(0),"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L786)
sender permission checks
require(winners[launchpadId][_msgSender()],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L789)
sender permission checks
require(!isClaimed[launchpadId][_msgSender()],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L828)
Ignore: check with 0
require(launchpadIds.length>0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L831)
array length control
require(launchpadIds[i]<launchpads.length,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L832)
Ignore: check with 0
require(balanceOfLaunchpad[launchpadIds[i]]>0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L833)
filtered
require(!hasWithdrawFund[uint24(launchpadIds[i])],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L834)
filtered
require(hasSetLaunchpadWinner[uint24(launchpadIds[i])],"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L835)
Ignore: check with 0
require(amountOfWinners[uint24(launchpadIds[i])]>0,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L843)
balance control
require(_balance>=amountAdminWithdraw,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L857)
time control
require(_newEndTime>_newStartTime,"")
[Code File](contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L858)
time control
require(_newEndTime>block.timestamp,"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L76)
array length control
require(sig.length==65,"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L495)
balance control
require(balance>=amount,"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L507)
enforce specification
require(!seenNonces[msg.sender][_transferData.nonce],"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L509)
sender permission checks
require(verify(msg.sender,msg.sender,_transferData.amount,_transferData.encodeKey,_transferData.nonce,_transferData.signature),"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L567)
enforce specification
require(!seenNonces[msg.sender][_buyData.nonce],"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L569)
sender permission checks
require(verify(msg.sender,msg.sender,_buyData.amount,_buyData.encodeKey,_buyData.nonce,_buyData.signature),"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L595)
enforce specification
require(!seenNonces[msg.sender][_createData.nonce],"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L597)
sender permission checks
require(verify(msg.sender,msg.sender,_createData.amount,_createData.encodeKey,_createData.nonce,_createData.signature),"")
[Code File](contracts/mainnet/3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol#L717)
Ignore: check with 0
require(balance>=0,"")
[Code File](contracts/mainnet/9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol#L55)
sender ownerOf
require(msg.sender==owner)
[Code File](contracts/mainnet/9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol#L61)
sender permission checks
require(mod==msg.sender,"")
[Code File](contracts/mainnet/9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol#L152)
Ignore: check with 0
require(price>0,"")
[Code File](contracts/mainnet/9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol#L153)
msg.value control
require(msg.value==listingFee,"")
[Code File](contracts/mainnet/9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol#L398)
Ignore: check with 0
require(value>0,"")
[Code File](contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L332)
filtered
require(_initialized<version,"")
[Code File](contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L716)
array length control
require(accounts.length==ids.length,"")
[Code File](contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L833)
array length control
require(ids.length==amounts.length,"")
[Code File](contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1301)
filtered
require(supply>=amount,"")
[Code File](contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1368)
sender ownerOf
require(msg.sender==owner,"")
[Code File](contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1381)
sender permission checks
require(msg.sender==Operator,"")
[Code File](contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1382)
filtered
require(!isDuplicate(__uri),"")
[Code File](contracts/mainnet/e6/e6d721ae851e90c2870df2d4526faae5c5cd2405_NFTMarketplace.sol#L1198)
sender ownerOf
require(owner==msg.sender,"")
[Code File](contracts/mainnet/e6/e6d721ae851e90c2870df2d4526faae5c5cd2405_NFTMarketplace.sol#L1223)
msg.value control
require(msg.value==listingPrice,"")
[Code File](contracts/mainnet/e6/e6d721ae851e90c2870df2d4526faae5c5cd2405_NFTMarketplace.sol#L1245)
sender ownerOf
require(idToMarketItem[tokenId].owner==msg.sender,"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L66)
address(0)
require(referrer!=address(0),"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L72)
enforce specification
require(activeRefMap[_referrer],"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L73)
sender permission checks
require(_referrer!=_msgSender(),"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L75)
sender permission checks
require(parentRefMap[_msgSender()]==address(0)||parentRefMap[_msgSender()]==_referrer,"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L82)
sender permission checks
require(parentRefMap[_msgSender()]!=address(0),"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L112)
enforce specification
require(allowedWeiPurchase,"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L117)
Ignore: check with 0
require(bredAmountAllowanceMap[gene]>0,"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L120)
filtered
require(weiAmount>=kotketPriceMap[gene].eWei,"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L140)
enforce specification
require(allowedKotketTokenPurchase,"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L150)
sender permission checks
require(kotketToken.balanceOf(_msgSender())>=price,"")
[Code File](contracts/mainnet/e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol#L153)
filtered
require(tokenAllowance>=price,"")
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L50)
msg.value control
require(msg.value>=fees.offerFee)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L62)
sender ownerOf
require(IERC721(asset.collection).ownerOf(asset.ids[j])==msg.sender)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L64)
Ignore: check with 0
require(swap.assets[asset.collection].length==0)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L73)
Ignore: check with 0
require(swap.quantity[wantedAsset.collection]==0)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L82)
sender permission checks
require(receiver!=sender)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L83)
Ignore: check with 0
require(assets.length>0&&assets.length<=MAX_ASSET_SIZE)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L84)
Ignore: check with 0
require(wantedAssets.length>0&&wantedAssets.length<=MAX_ASSET_SIZE)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L88)
filtered
require(!ArrayUtils.hasDuplicate(asset.ids))
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L89)
Ignore: check with 0
require(asset.ids.length>0&&asset.ids.length<=MAX_QUANTITY)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L90)
filtered
require(isAllowedCollection(asset.collection))
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L94)
Ignore: check with 0
require(asset.quantity>0&&asset.quantity<=MAX_QUANTITY&&asset.quantity>=asset.ids.length)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L107)
filtered
require(swap.status==Status.CREATED)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L108)
sender permission checks
require(swap.maker!=msg.sender)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L124)
msg.value control
require(msg.value>=nftCounter*fees.swapFeePerNft+fees.swapFee)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L130)
Ignore: check with 0
require(quantity==asset.ids.length&&quantity>0)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L134)
filtered
requiredIdsCount++
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L138)
array length control
require(requiredIdsCount==requiredIds.length)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L146)
enforce specification
require(receiverIsValid)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L152)
sender permission checks
require(swap.maker==msg.sender)
[Code File](contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L191)
enforce specification
require(os)
[Code File](contracts/mainnet/19/19537635595aac362D8FC6d14CCdF6b54D8cFC28_YFIAGNftPool.sol#L67)
Ignore: check with 0
require(subOwnerFee>0,"")
[Code File](contracts/mainnet/19/19537635595aac362D8FC6d14CCdF6b54D8cFC28_YFIAGNftPool.sol#L68)
owner permission checks
require(address(this).balance>=subOwnerFee,"")
[Code File](contracts/mainnet/19/19537635595aac362D8FC6d14CCdF6b54D8cFC28_YFIAGNftPool.sol#L91)
address(0)
require(marketPlaceAddress!=address(0),"")
[Code File](contracts/mainnet/19/19537635595aac362D8FC6d14CCdF6b54D8cFC28_YFIAGNftPool.sol#L92)
EOA validation
require(marketPlaceAddress.isContract(),"")
[Code File](contracts/mainnet/19/19537635595aac362D8FC6d14CCdF6b54D8cFC28_YFIAGNftPool.sol#L100)
address(0)
require(newPool!=address(0),"")
[Code File](contracts/mainnet/19/19537635595aac362D8FC6d14CCdF6b54D8cFC28_YFIAGNftPool.sol#L101)
EOA validation
require(newPool.isContract(),"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L776)
sender permission checks
require(BERC20.allowance(msg.sender,address(this))>=_offer,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L809)
sender ownerOf
require(IERC721(_nft).ownerOf(_tokenId)==msg.sender,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L813)
enforce specification
require(!offer.isAccepted,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L814)
sender ownerOf
require(msg.sender==offer.owner,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L829)
filtered
require(BERC20.allowance(_offerer,address(this))>=offerAmount,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L896)
sender ownerOf
require(nft.ownerOf(_tokenId)==msg.sender,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L923)
sender permission checks
require(msg.sender!=listedNft.seller,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L942)
filtered
require(success0,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L962)
enforce specification
require(!listedNft.sold,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L964)
sender permission checks
require(listedNft.seller==msg.sender,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L994)
sender ownerOf
require(msg.sender==IERC721(_nft).ownerOf(_tokenId),"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L995)
Ignore: check with 0
require(_price>0,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L996)
time control
require(_duration>block.timestamp,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1017)
filtered
require(_amount>=auction.price,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1018)
sender permission checks
require(BERC20.allowance(msg.sender,address(this))>=_amount,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1019)
enforce specification
require(auction.isActive,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1020)
time control
require(auction.duration>block.timestamp,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1030)
filtered
require(auction.bidAmounts[lastIndex]<_amount,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1050)
sender permission checks
require(auction.maxBidUser==msg.sender||msg.sender==auction.seller,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1051)
time control
require(auction.duration<=block.timestamp,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1058)
filtered
require(BERC20.allowance(auction.maxBidUser,address(this))>=auction.maxBid,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1099)
sender permission checks
require(auction.seller==msg.sender,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1121)
sender permission checks
require(IERC1155(_nft).balanceOf(msg.sender,tokenId)>=amount,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1122)
sender permission checks
require(IERC1155(_nft).isApprovedForAll(msg.sender,address(this)),"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1145)
whitelist control
require(whitelisted==true,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1148)
sender permission checks
require(msg.sender!=idToListing1155[listingId].seller,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1149)
msg.value control
require(msg.value>=idToListing1155[listingId].price*amount,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1150)
balance control
require(IERC1155(idToListing1155[listingId].nft).balanceOf(idToListing1155[listingId].seller,idToListing1155[listingId].tokenId)>=amount,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1151)
filtered
require(idToListing1155[listingId].completed==false,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1152)
filtered
require(idToListing1155[listingId].tokensAvailable>=amount,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1204)
sender permission checks
require(msg.sender==idToListing1155[_listingId].seller,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1205)
filtered
require(idToListing1155[_listingId].completed==false,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1223)
balance control
require(_amount<address(this).balance,"")
[Code File](contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L1230)
balance control
require(IERC20(_token).balanceOf(address(this))>_amount,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L55)
filtered
require(_serviceCommissionByDay<=1000,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L61)
time control
require(_serviceCommissionByEndOfPeriod<=1000,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L67)
owner permission checks
require(rentalItemInfoMap[_tokenId].owner!=address(0),"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L68)
address(0)
require(rentalItemInfoMap[_tokenId].renter!=address(0),"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L83)
filtered
require(_interestRate<=1000,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L86)
Ignore: check with 0
require(_period>0,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L90)
time control
require(_profitReceivingMethod<=uint8(PROFIT_RECEIVING_METHOD.END_OF_PERIOD),"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L113)
sender ownerOf
require(rentalItemInfoMap[_tokenId].owner==_msgSender(),"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L114)
address(0)
require(rentalItemInfoMap[_tokenId].renter==address(0),"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L144)
time control
require(timeStamp<rentalItemInfoMap[_tokenId].extensionFrom||timeStamp>rentalItemInfoMap[_tokenId].endAt,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L156)
time control
require(timeStamp>rentalItemInfoMap[_tokenId].endAt,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L172)
sender permission checks
require(rentalItemInfoMap[_tokenId].renter==_msgSender(),"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L173)
time control
require(rentalItemInfoMap[_tokenId].endAt>=timeStamp,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L186)
address(0)
require(_beneficiary!=address(0),"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L189)
enforce specification
require(!rentalItemInfoMap[_tokenId].stopForRent,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L210)
filtered
require(rentalItemInfoMap[_tokenId].renter==_beneficiary,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L212)
time control
require(rentalItemInfoMap[_tokenId].extensionFrom<=timeStamp,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L235)
sender permission checks
require(kotketToken.balanceOf(_msgSender())>=priceInPeriod,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L238)
time control
require(tokenAllowance>=priceInPeriod,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L276)
Ignore: check with 0
require(reward>0,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L279)
balance control
require(kotketToken.balanceOf(address(this))>=reward,"")
[Code File](contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L323)
balance control
require(kotketToken.balanceOf(address(this))>=amount,"")
[Code File](contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L82)
sender ownerOf
require(msg.sender==tokenContract.ownerOf(tokenId),"")
[Code File](contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L83)
Ignore: check with 0
require(minimumOffer>0,"")
[Code File](contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L100)
sender permission checks
require(msg.sender==tokenMarkets[tokenId].bidder,"")
[Code File](contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L114)
msg.value control
require(msg.value>existingLockedBid,"")
[Code File](contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L146)
Ignore: check with 0
require(msg.value>0,"")
[Code File](contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L170)
filtered
require(newFeePortion<=1000,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L318)
filtered
require(denominator>prod1)
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L1408)
filtered
require(_checkOnERC721Received(from,to,tokenId,data),"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2056)
address(0)
require(_nftContract!=address(0),"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2057)
address(0)
require(_nftHolder!=address(0),"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2058)
address(0)
require(_randomContract!=address(0),"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2096)
filtered
require(nftSoldData[voucher.signature]<numberOfNfts,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2097)
msg.value control
require(msg.value>=price,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2098)
address(0)
require(campaigns[campaignId].creatorAddress!=address(0),"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2099)
filtered
require(campaignId==voucherToCampaignID[voucher.signature],"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2100)
enforce specification
require(!campaigns[campaignId].isEnded,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2121)
time control
require(_campaignDTO.drawTime>block.timestamp,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2165)
enforce specification
require(!isOnAuction,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2166)
time control
require(bidEndTime>block.timestamp,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2172)
filtered
require(numberOfNfts==1,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2196)
filtered
require(currentlyOnAuction[itemId].nftID==itemId,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2197)
time control
require(currentlyOnAuction[itemId].biddingTime>block.timestamp,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2198)
enforce specification
require(!currentlyOnAuction[itemId].sold,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2199)
msg.value control
require(msg.value>=price&&msg.value>bidderInfo[itemId].bidderAmount,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2215)
enforce specification
require(currentlyOnAuction[itemId].isOnAuction,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2216)
time control
require(currentlyOnAuction[itemId].biddingTime<=block.timestamp,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2220)
sender permission checks
require(bidderInfo[itemId].bidderAddress==msg.sender,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2244)
enforce specification
require(isOnAuction,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2245)
time control
require(currentlyOnAuction[currentlyOnAuctionTokenID].biddingTime<block.timestamp,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2273)
address(0)
require(campaigns[_campaignId].creatorAddress!=address(0),"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2274)
enforce specification
require(!campaigns[_campaignId].isEnded,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2278)
Ignore: check with 0
require(campaigns[_campaignId].currentNoOfParticipants>0,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2304)
Ignore: check with 0
require(campaigns[_campaignId].campaignID!=0,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2306)
time control
require(_drawTime>block.timestamp,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2311)
Ignore: check with 0
require(tokenId!=0,"")
[Code File](contracts/mainnet/4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol#L2315)
time control
require(_bidEndTime>block.timestamp,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L442)
Ignore: check with 0
require(gotMaxTokenSupply>0,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L457)
sender ownerOf
require(msg.sender==marketOwner,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L458)
filtered
require(gotNewMaxTokenSupply>_maxTokenSupply,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L463)
Ignore: check with 0
require(tempTokenURI.length>0,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L467)
filtered
require(_tokenIds.current()!=_maxTokenSupply,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L477)
sender ownerOf
require((msg.sender==MarketItemDatabase[tokenId].nftCreator&&MarketItemDatabase[tokenId].nftOwner==address(0))||msg.sender==MarketItemDatabase[tokenId].nftOwner,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L484)
sender ownerOf
require((msg.sender==MarketItemDatabase[tokenId].nftCreator&&MarketItemDatabase[tokenId].nftOwner==address(0))||msg.sender==MarketItemDatabase[tokenId].nftOwner||msg.sender==marketOwner,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L485)
filtered
require(MarketItemDatabase[tokenId].forSale==true,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L496)
sender ownerOf
require(msg.sender!=marketOwner,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L498)
msg.value control
require(msg.value==marketItemPrice,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L512)
filtered
require(MarketItemDatabase[tokenId].forSale==false,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L513)
msg.value control
require(msg.value==gotTransferFee,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L527)
msg.value control
require(msg.value==withdrawAmount,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L528)
filtered
require(mpWallets[sendTo]>=withdrawAmount,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L534)
Ignore: check with 0
require(mpWallets[userWallet]>0,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L535)
owner permission checks
require((userWallet==MarketItemDatabase[tokenID].nftCreator&&MarketItemDatabase[tokenID].nftOwner!=address(0))||userWallet!=MarketItemDatabase[tokenID].nftOwner,"")
[Code File](contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L544)
msg.value control
require(msg.value==bidAmount,"")
[Code File](contracts/mainnet/bc/bc3Fc7bf165456d059012Cd9873F2999Bdd4de56_EKotketNFTPlatformRenting.sol#L54)
Ignore: check with 0
require(_dayInPeriod>0,"")
[Code File](contracts/mainnet/bc/bc3Fc7bf165456d059012Cd9873F2999Bdd4de56_EKotketNFTPlatformRenting.sol#L102)
filtered
require(_startAt>depositItemInfoMap[_tokenId].endAt,"")
[Code File](contracts/mainnet/bc/bc3Fc7bf165456d059012Cd9873F2999Bdd4de56_EKotketNFTPlatformRenting.sol#L116)
filtered
require(_current>depositItemInfoMap[_tokenId].endAt,"")
[Code File](contracts/mainnet/88/887067939fA33E1c9B755B222fE92BAd2717691b_TransferManagerERC1155.sol#L23)
sender permission checks
require(msg.sender==MNFTMarketplace,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L42)
address(0)
require(usdtAddress!=address(0)&&kotketTokenAddress!=address(0),"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L46)
balance control
require(usdtBalance>=_amountUSDT,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L49)
filtered
require(usdtAllowance>=_amountUSDT,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L53)
Ignore: check with 0
require(amountKOKE>0,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L57)
balance control
require(kokeBalance>=amountKOKE,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L60)
filtered
require(kokeAllowance>=amountKOKE,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L76)
balance control
require(kokeBalance>=_amountKOKE,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L79)
filtered
require(kokeAllowance>=_amountKOKE,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L83)
Ignore: check with 0
require(amountUSDT>0,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L87)
balance control
require(usdtBalance>=amountUSDT,"")
[Code File](contracts/mainnet/30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol#L90)
filtered
require(usdtAllowance>=amountUSDT,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L211)
filtered
require(_initializing||_isConstructor()||!_initialized,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L449)
Ignore: safe math
require(b<=a,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L483)
Ignore: check with 0
require(b>0,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L1206)
msg.value control
require(set._values.length>index,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L1639)
address(0)
require(signer!=address(0),"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3327)
enforce specification
require(!isPaused,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3333)
sender ownerOf
require(_sender==owner(),"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3437)
Ignore: check with 0
require(_priceInWei>0,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3438)
msg.value control
require(msg.value==nftListingFee,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3489)
Ignore: check with 0
require(_priceInErc20Token>0,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3538)
filtered
require(_listedNftTokenIds.contains(_nftListingId),"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3552)
sender permission checks
require(nftListing.listedBy!=_sender,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3556)
Ignore: check with 0
require(nftListing.paymentType==0,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3563)
msg.value control
require(msg.value==expectedAmountWei,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3602)
filtered
require(nftListing.paymentType==1,"")
[Code File](contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3669)
enforce specification
require(hasUserLikedNftListing[_sender][_nftListingId],"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1660)
filtered
require(!authorizedManagers.contains(_manager),"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1667)
filtered
require(authorizedManagers.contains(_manager),"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1674)
sender permission checks
require(authorizedManagers.contains(msg.sender),"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1675)
filtered
require(_fee<101,"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1698)
sender permission checks
require(collections[_collection].creator==msg.sender,"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1714)
sender ownerOf
require(IERC721(_collection).ownerOf(_tokenId)==msg.sender,"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1715)
Ignore: check with 0
require(_listingPrice>0,"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1749)
enforce specification
require(collection.listings[_tokenId].active,"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1750)
sender permission checks
require(collection.listings[_tokenId].seller==msg.sender,"")
[Code File](contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1781)
msg.value control
require(collection.listings[_tokenId].listing_price==msg.value,"")
[Code File](contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L49)
filtered
require(_winrate<=1000,"")
[Code File](contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L71)
filtered
require(!tokenExisted(_tokenId),"")
[Code File](contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L1193)
sender permission checks
require(operator!=_msgSender(),"")
[Code File](contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L1859)
owner permission checks
require(index<ERC721.balanceOf(owner),"")
[Code File](contracts/mainnet/e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol#L1892)
filtered
require(index<ERC721Enumerable.totalSupply(),"")
[Code File](contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L830)
filtered
require(address(this)!=__self,"")
[Code File](contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L831)
filtered
require(_getImplementation()==__self,"")
[Code File](contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L840)
filtered
require(address(this)==__self,"")
[Code File](contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L2540)
EOA validation
require(AddressUpgradeable.isContract(newImplementation),"")
[Code File](contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L2587)
filtered
require(slot==_IMPLEMENTATION_SLOT,"")
[Code File](contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L2654)
EOA validation
require(AddressUpgradeable.isContract(newBeacon),"")
[Code File](contracts/mainnet/f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol#L2687)
EOA validation
require(AddressUpgradeable.isContract(target),"")
[Code File](contracts/mainnet/43/438AbFE329C0F38c02C971B8d34307beB06aD778_IndigenaNFTMarketplace.sol#L103)
sender ownerOf
require(msg.sender==proxyOwner(),"")
[Code File](contracts/mainnet/43/438AbFE329C0F38c02C971B8d34307beB06aD778_IndigenaNFTMarketplace.sol#L121)
owner permission checks
require(_newOwner!=address(0))
[Code File](contracts/mainnet/43/438AbFE329C0F38c02C971B8d34307beB06aD778_IndigenaNFTMarketplace.sol#L185)
filtered
require(currentImplementation!=_newImplementation)
[Code File](contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L139)
sender permission checks
require(IERC721(nftContract).isApprovedForAll(msg.sender,address(this)),"")
[Code File](contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L183)
filtered
require(itemId<=_itemCounter.current(),"")
[Code File](contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L184)
filtered
require(marketItems[itemId].state==State.Created,"")
[Code File](contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L187)
sender permission checks
require(item.seller==msg.sender,"")
[Code File](contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L218)
filtered
require(item.state==State.Created,"")
[Code File](contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L219)
amount enforcement
require(amount==price,"")
[Code File](contracts/mainnet/43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol#L220)
filtered
require(IERC721(nftContract).isApprovedForAll(item.seller,address(this)),"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L135)
enforce specification
require(!_locked,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L158)
owner permission checks
require(sales[_nftContract][_tokenId].owner!=address(0),"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L388)
balance control
require(_erc20contract.balanceOf(address(this))>=amount,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L399)
filtered
require(_fee<=10000,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L409)
Ignore: check with 0
require(_marginSecondsDutchAuction>0,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L428)
array length control
require(prices.length<=10,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L429)
Ignore: check with 0
require(prices.length>0,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L462)
array length control
require(_tokenIds.length<301,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L495)
sender ownerOf
require(_msgSender()==sales[_nftContract][_tokenId].owner,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L541)
Ignore: check with 0
require(msg.value==0,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L542)
sender permission checks
require(erc20.balanceOf(_msgSender())>=price,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L607)
filtered
require(amount>=englishAuctions[_nftContract][_tokenId].amount,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L622)
msg.value control
require(msg.value==amount,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L719)
filtered
require(startPrice>endPrice,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L720)
filtered
require(start<end,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L799)
msg.value control
require(msg.value<price+marginSecondsDutchAuction*_priceDropPerSecondForDutchAuction(_nftContract,_tokenId),"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L826)
sender ownerOf
require(_msgSender()==dutchAuctions[_nftContract][_tokenId].owner,"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L885)
filtered
require(isInEnglishAuction(_nftContract,tokenId),"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L905)
filtered
require(isInDutchAuction(_nftContract,tokenId),"")
[Code File](contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L915)
filtered
require(isBeingSold(_nftContract,tokenId),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L85)
filtered
require(_from<_to,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L202)
Ignore: check with 0
require(_balance>0,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L203)
balance control
require(_balance>=_amount,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L204)
address(0)
require(_user!=address(0),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L212)
Ignore: check with 0
require(_totalBalance>0,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L218)
filtered
require(_newFee<=1000,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L230)
Ignore: check with 0
require(_max!=MAX_FRAGMENT&&_max>0,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L234)
address(0)
require(pool!=address(0),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L235)
EOA validation
require(pool.isContract(),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L245)
address(0)
require(launchPad!=address(0),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L246)
EOA validation
require(launchPad.isContract(),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L254)
enforce specification
require(_rootTokens[_tokenId],"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L259)
sender ownerOf
require(ownerOf(_tokenId)==msg.sender,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L264)
sender permission checks
require(msg.sender==yfiagPool,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L269)
address(0)
require(newPlatformFeeAddess!=address(0),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L275)
address(0)
require(_token==address(0)||_token.isContract(),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L276)
filtered
require(_royalty<=maxRoyalties&&_royalty>=minRoyalties,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L295)
address(0)
require(tokenAddress[_rootTokenId]==address(0)||tokenAddress[_rootTokenId].isContract(),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L296)
enforce specification
require(_rootTokens[_rootTokenId],"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L309)
enforce specification
require(!tokenStatus[_tokenId],"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L318)
enforce specification
require(tokenStatus[_tokenId],"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L319)
sender ownerOf
require(ownerOf(_tokenId)!=msg.sender,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L320)
address(0)
require(tokenAddress[_tokenId]==address(0),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L337)
msg.value control
require(prices[_tokenId]==msg.value,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L537)
sender permission checks
require(_launchPad==msg.sender,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L542)
filtered
require(exists(_tokenId),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L547)
enforce specification
require(!_rootTokens[_tokenId],"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L552)
enforce specification
require(!_fragmentTokens[_tokenId],"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L576)
owner permission checks
require(_owner!=address(0),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L604)
owner permission checks
require(to!=_owner,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L621)
filtered
require(exists(tokenId),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L736)
filtered
require(!exists(tokenId),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L803)
Ignore: check with 0
require(accountBalance>0,"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L873)
owner permission checks
require(index<ERC721.balanceOf(_owner),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L888)
filtered
require(index<totalSupply(),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L948)
filtered
require(ERC721.exists(tokenId),"")
[Code File](contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L958)
address(0)
require(_user!=address(0))
[Code File](contracts/mainnet/7b/7b380299C8eDA4527C83174918199d702611e876_APONFT.sol#L26)
array length control
require(ids.length<=idsLength,"")
[Code File](contracts/mainnet/7b/7b380299C8eDA4527C83174918199d702611e876_APONFT.sol#L883)
address(0)
require(_checkOnERC721Received(address(0),to,tokenId,_data),"")
[Code File](contracts/mainnet/7b/7b380299C8eDA4527C83174918199d702611e876_APONFT.sol#L1520)
sender permission checks
require(hasRole(MINTER_ROLE,_msgSender()),"")
[Code File](contracts/mainnet/7b/7b380299C8eDA4527C83174918199d702611e876_APONFT.sol#L1537)
sender permission checks
require(hasRole(PAUSER_ROLE,_msgSender()),"")
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1083)
time control
require(presaleDatas[presaleCounter].endTime<_startTime)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1095)
time control
require(_presaleTime<=presaleCounter)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1108)
msg.value control
require(msg.value==salesPrice,"")
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1109)
time control
require(block.timestamp>=presaleDatas[_salesTime].startTime,"")
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1110)
time control
require(block.timestamp<=presaleDatas[_salesTime].endTime,"")
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1111)
time control
require(_offerId>=presaleDatas[_salesTime].startId,"")
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1112)
time control
require(_offerId<=presaleDatas[_salesTime].endId,"")
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1113)
filtered
require(presaleFinished[_offerId]==false,"")
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1114)
sender permission checks
require(whiteList(presaleDatas[_salesTime].whiteListAddress).checkWhiteListRemainAmount(msg.sender)>=1)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1344)
Ignore: check with 0
require(whiteListValue[_walletAddress]==0)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1350)
whitelist control
require((whiteListValue[_walletAddress]-whiteListUsed[_walletAddress])>=_value)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1356)
Ignore: check with 0
require(whiteListValue[_walletAddress]!=0)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1363)
whitelist control
require(whiteListValue[_walletAddress]>=1)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1364)
msg.value control
require(_value>=1)
[Code File](contracts/mainnet/20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol#L1372)
whitelist control
require(whiteListValue[_walletAddress]>whiteListUsed[_walletAddress])
[Code File](contracts/mainnet/db/db891C608eeB12c1A0842Cb2A96BC58E65E5d971_NFTMarketplace.sol#L76)
filtered
require(recoverSigner(message,signature)==_admin,"")
[Code File](contracts/mainnet/db/db891C608eeB12c1A0842Cb2A96BC58E65E5d971_NFTMarketplace.sol#L952)
Ignore: check with 0
require(expireAt==0||expireAt>datetime,"")
[Code File](contracts/mainnet/4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol#L2195)
EOA validation
require(address(token).isContract(),"")
[Code File](contracts/mainnet/4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol#L2569)
address(0)
require(swap_.token==address(0),"")
[Code File](contracts/mainnet/4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol#L2581)
address(0)
require(swaps[swapId].seller!=address(0),"")
[Code File](contracts/mainnet/4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol#L2582)
sender permission checks
require(swaps[swapId].seller==msg.sender,"")
[Code File](contracts/mainnet/4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol#L2583)
filtered
require(swaps[swapId].status==Status.None,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L54)
EOA validation
require(_tokenErc20.isContract(),"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L63)
filtered
require(_newFee<10000,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L79)
filtered
require(_royalty+platformFee<10000,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L115)
msg.value control
require(_price==msg.value,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L120)
sender permission checks
require(IERC20(tokenAddress[_tokenId]).balanceOf(msg.sender)>=_price,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L178)
sender ownerOf
require(msg.sender==ownerOf(_tokenId),"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L179)
filtered
require(_newRoyalty>royalties[_tokenId]&&_newRoyalty<=10000&&_newRoyalty+platformFee<=10000,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L187)
filtered
require(isLock(_tokenId),"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L194)
owner permission checks
require(ownerOf(_tokenId)==_to,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L209)
sender permission checks
require(IERC20(_token).balanceOf(msg.sender)>=_price,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L219)
address(0)
require(_token.isContract()||_token==address(0),"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L224)
sender permission checks
require(IERC20(_token).balanceOf(msg.sender)>=_amount,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1351)
sender ownerOf
require(admins[msg.sender]||owner==msg.sender,"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1361)
filtered
require(!isLock(_tokenId),"")
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1601)
filtered
require(ERC721.exists(tokenId))
[Code File](contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1639)
filtered
require(!isAdmin(_user),"")
[Code File](contracts/mainnet/ca/caE3aB3D711bccCaE4f2C58ce0F146EB8bB840Bf_NFTMarketplace.sol#L1487)
enforce specification
require(!item.sold,"")
[Code File](contracts/mainnet/ca/caE3aB3D711bccCaE4f2C58ce0F146EB8bB840Bf_NFTMarketplace.sol#L1488)
filtered
require(item.status==ListingStatus.Active,"")
[Code File](contracts/mainnet/ca/caE3aB3D711bccCaE4f2C58ce0F146EB8bB840Bf_NFTMarketplace.sol#L1524)
array length control
require(nftContracts.length==itemIds.length,"")
[Code File](contracts/mainnet/ca/caE3aB3D711bccCaE4f2C58ce0F146EB8bB840Bf_NFTMarketplace.sol#L1525)
Ignore: check with 0
require(nftContracts.length>0,"")
[Code File](contracts/mainnet/b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol#L36)
filtered
require(_serviceCommission<=1000,"")
[Code File](contracts/mainnet/b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol#L56)
sender ownerOf
require(saleItemInfoMap[_tokenId].owner==_msgSender(),"")
[Code File](contracts/mainnet/b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol#L79)
owner permission checks
require(saleItemInfoMap[_tokenId].owner!=address(0),"")
[Code File](contracts/mainnet/b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol#L84)
filtered
require(weiAmount>=price,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L556)
Ignore: check with 0
require(interfaceId!=0xffffffff,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L788)
sender ownerOf
require(nft.ownerOf(tokenId)==msg.sender,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L789)
Ignore: check with 0
require(_initialPrice>=0,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L989)
time control
require(value>=minimumAcceptedBid&&block.timestamp<listIds[listId].endTime,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L990)
sender permission checks
require(ammo.balanceOf(msg.sender)>=minimumAcceptedBid,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L997)
msg.value control
require(value>=price,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L1030)
time control
require(block.timestamp>listIds[listId].endTime,"")
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L1031)
sender permission checks
require(msg.sender==listIds[listId].currentWinner)
[Code File](contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L1032)
sender permission checks
require(ammo.balanceOf(msg.sender)>=price,"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1368)
EOA validation
require(Address.isContract(_nftContract),"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1369)
filtered
require(marketRegistrations[_nftContract]==nullBytes,"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1385)
array length control
require(_conductKeys.length==_prices.length,"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1391)
msg.value control
require(sum==msg.value,"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1405)
filtered
require(_conductKey==marketRegistrations[_nftContract]&&_conductKey!=nullBytes,"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1406)
sender permission checks
require(msg.sender==_seller,"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1407)
filtered
require(_status==ListingStatus.Active,"")
[Code File](contracts/mainnet/18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol#L1426)
filtered
require(_royaltyFeePercent+_marketFeePercent<=10000,"")
[Code File](contracts/mainnet/11/115ac133b7267ea05d146caa64d4140425a43dc8_EmillionNftMarketPlace.sol#L1264)
Ignore: check with 0
require(balance>0,"")
[Code File](contracts/mainnet/11/115ac133b7267ea05d146caa64d4140425a43dc8_EmillionNftMarketPlace.sol#L1340)
sender permission checks
require(order.seller==msg.sender,"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L74)
sender permission checks
require(hasRole(ROLE_ADMIN,msg.sender),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L87)
address(0)
require(_admin!=address(0),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L92)
address(0)
require(_tbnNFTAddress!=address(0),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L93)
address(0)
require(_oracleAddress!=address(0),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L98)
address(0)
require(_wethAddress!=address(0),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L99)
filtered
require(_basisPointFee<10000,"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L114)
address(0)
require(newWeth!=address(0),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L119)
address(0)
require(newOracle!=address(0),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L146)
address(0)
require(_tbnNftAddress!=address(0),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L154)
filtered
require(_basisPointFee<=10000,"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L250)
filtered
require(nftTokenAddress==tbnNftAddress,"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L293)
filtered
require(listingIds.contains(listingId),"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L329)
Ignore: check with 0
require(TBNAmount>0,"")
[Code File](contracts/mainnet/7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol#L438)
msg.value control
require(msg.value>=fullCost,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2314)
filtered
require(amount<=MAX_ROYALTY)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2335)
filtered
require(!IERC165(nftContract).supportsInterface(0x2a55205a),"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2346)
filtered
require(_newPublic<=MAX_PROTOCOL_FEE)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2352)
filtered
require(_newProfile<=MAX_PROTOCOL_FEE)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2358)
whitelist control
require(whitelistERC20[_token]!=_val)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2374)
filtered
require(_discount<=10000)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2391)
array length control
require(success&&data.length>=32)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2415)
array length control
require(optionalNftAssets.length==1,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2416)
filtered
require(optionalNftAssets[0].assetType.assetClass==LibAsset.ERC721_ASSET_CLASS,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2425)
filtered
require(success3,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2435)
filtered
require(success1&&success2,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2457)
address(0)
require(nftBuyContract!=address(0))
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2458)
address(0)
require(to!=address(0)&&from!=address(0))
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2464)
Ignore: check with 0
require(value!=0)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2470)
whitelist control
require(whitelistERC20[token],"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2512)
msg.value control
require(value==1,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2867)
filtered
require(order.maker!=address(0x0),"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2868)
Ignore: check with 0
require(order.start==0||order.start<block.timestamp,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2869)
Ignore: check with 0
require(order.end==0||order.end>block.timestamp,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2870)
Ignore: check with 0
require(order.makeAssets.length!=0,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2871)
Ignore: check with 0
require(order.takeAssets.length!=0,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2900)
array length control
require(signature.length==65,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L2948)
sender permission checks
require(msg.sender==marketPlace)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3192)
filtered
require(validateOrder(hash,order,sig))
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3203)
Ignore: check with 0
require(order.salt!=0)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3271)
sender permission checks
require(msg.sender==order.maker)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3289)
Ignore: check with 0
require(_approvedOrdersByNonce[hash]==0)
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3314)
sender permission checks
require(validationLogic.validateBuyNow(sellOrder,msg.sender))
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3315)
sender permission checks
require(msg.sender!=sellOrder.maker,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3365)
filtered
require(marketplaceEvent.emitBuyNow(sellHash,sellOrder,v,r,s))
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3386)
sender permission checks
require(msg.sender==sellOrder.maker||msg.sender==buyOrder.maker||aggregator[msg.sender],"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3387)
sender permission checks
require(validationLogic.validateMatch_(sellOrder,buyOrder,msg.sender,false))
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3439)
filtered
require(marketplaceEvent.emitExecuteSwap(sellHash,buyHash,sellOrder,buyOrder,v,r,s))
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3507)
filtered
require(buyMakeAddress==sellTakeAddress,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3605)
enforce specification
require(!ETH_ASSET_USED,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3606)
sender permission checks
require(viewOnly||sender!=buyOrder.maker,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3618)
array length control
require(sellOrder.takeAssets.length==buyOrder.makeAssets.length,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3628)
sender permission checks
require(viewOnly||sender!=sellOrder.maker,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3642)
array length control
require(sellOrder.takeAssets.length==1,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3657)
address(0)
require((sellOrder.taker==address(0)||sellOrder.taker==buyer),"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3658)
Ignore: check with 0
require(sellOrder.makeAssets.length!=0,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3659)
Ignore: check with 0
require(sellOrder.takeAssets.length!=0,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3664)
Ignore: check with 0
require(sellOrder.start!=0&&sellOrder.start<block.timestamp,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3665)
Ignore: check with 0
require(sellOrder.end!=0&&sellOrder.end>block.timestamp,"")
[Code File](contracts/mainnet/6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol#L3693)
filtered
require(sellOrder.auctionType==LibSignature.AuctionType.Decreasing,"")
[Code File](contracts/mainnet/1a/1a22d99d1853b8804ea5c95c87dfdef8a41f6c88_DentistCoinNFTMarketPlace.sol#L641)
address(0)
require(_addressToCheck!=address(0),"")
[Code File](contracts/mainnet/1a/1a22d99d1853b8804ea5c95c87dfdef8a41f6c88_DentistCoinNFTMarketPlace.sol#L766)
filtered
require(!dentistCoinNFT.exists(_tokenId),"")
[Code File](contracts/mainnet/1a/1a22d99d1853b8804ea5c95c87dfdef8a41f6c88_DentistCoinNFTMarketPlace.sol#L833)
Ignore: check with 0
require(_newCategoryPrice>0,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1335)
Ignore: check with 0
require(withheldSupply>0,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1354)
Ignore: check with 0
require(availSupply>0,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1355)
sender permission checks
require(mintedTotal[msg.sender]<maxCountPerWallet,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1356)
msg.value control
require(msg.value==mintPrice,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1382)
sender permission checks
require(msg.sender!=address(0),"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1384)
filtered
require(_exists(_tokenId),"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1386)
enforce specification
require(!allCruiseElite[_tokenId].isWithheld,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1390)
sender ownerOf
require(tokenOwner==msg.sender,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1442)
owner permission checks
require(tokenOwner!=address(0),"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1446)
sender ownerOf
require(tokenOwner!=msg.sender,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1450)
msg.value control
require(msg.value==cruiseElite.price,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1452)
enforce specification
require(cruiseElite.isForSale,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1454)
sender permission checks
require(msg.sender!=cruiseOperationsWallet,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1473)
sender permission checks
require(msg.sender==cruiseOperationsWallet,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1475)
enforce specification
require(allCruiseElite[_tokenId].isWithheld,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1477)
address(0)
require(_to!=address(0),"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1497)
sender permission checks
require(msg.sender==daoContract,"")
[Code File](contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1499)
filtered
require(cruiseSelect.votingCount>=_decreaseCount,"")
[Code File](contracts/mainnet/1a/1ab6cb2780087feef3c61ad2c5e0cce43a8e93dd_NftMarketplace.sol#L141)
enforce specification
require(royaltyTransfer,"")
[Code File](contracts/mainnet/1a/1ab6cb2780087feef3c61ad2c5e0cce43a8e93dd_NftMarketplace.sol#L142)
enforce specification
require(transfer,"")
[Code File](contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L99)
sender ownerOf
require(_owner==_msgSender(),"")
[Code File](contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L238)
enforce specification
require(!bots[from]&&!bots[to])
[Code File](contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L253)
filtered
require(amount<=_maxTxAmount,"")
[Code File](contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L254)
balance control
require(balanceOf(to)+amount<=_maxWalletSize,"")
[Code File](contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L328)
enforce specification
require(!tradingOpen,"")
[Code File](contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L340)
sender permission checks
require(_msgSender()==_taxWallet)
[Code File](contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L341)
filtered
require(_newFee<=_finalBuyTax&&_newFee<=_finalSellTax)
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L122)
sender ownerOf
require(owner()==msg.sender,"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L295)
sender permission checks
require(_msgSender()!=operator,"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L718)
filtered
require(mintedNFT[RareNFT]<copiesRareNFT,"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L719)
sender permission checks
require(BundNFT.balanceOf(msg.sender)>=basePriceRareNFT.mul(_copiesNFT),"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L730)
filtered
require(mintedNFT[SpecialNFT]<copiesSpecialNFT,"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L731)
sender permission checks
require(BundNFT.balanceOf(msg.sender)>=basePriceSpecialNFT.mul(_copiesNFT),"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L742)
filtered
require(mintedNFT[LegendNFT]<copiesLegendNFT,"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L743)
sender permission checks
require(BundNFT.balanceOf(msg.sender)>=basePriceLegendNFT,"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L754)
balance control
require(BundNFT.balanceOf(address(this))>=basePriceLegendNFT,"")
[Code File](contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L760)
Ignore: check with 0
require(BundNFT.balanceOf(address(this))>0,"")
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1786)
Ignore: check with 0
require(bytes(_name).length>0&&bytes(_symbol).length>0&&bytes(_initBaseURI).length>0)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1802)
balance control
require(amount<=lastBalance)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1814)
enforce specification
require(!voucher.isAuction)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1818)
sender permission checks
require(_signer==msg.sender&&_signer==voucher.target)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1834)
enforce specification
require(voucher.isRedeem&&voucher.isForSale)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1836)
msg.value control
require(msg.value==voucher.price)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1840)
sender permission checks
require(_signer!=msg.sender)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1844)
time control
require(voucher.startDate<voucher.endDate&&(block.timestamp*1000)>voucher.endDate)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1848)
sender permission checks
require(voucher.isAuction?voucher.target==msg.sender:voucher.target==_signer)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1876)
sender ownerOf
require(msg.sender!=ownerAddress)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1880)
enforce specification
require(item.isForSale)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1882)
msg.value control
require(msg.value==item.price)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1908)
sender ownerOf
require(msg.sender==ERC721.ownerOf(tokenId))
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1936)
filtered
require(changeToIsForSale?!item.isForSale:item.isForSale)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L2154)
filtered
require(newSc<100000)
[Code File](contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L2248)
Ignore: check with 0
require(price>0)
[Code File](contracts/mainnet/3d/3dc7941f028f7b5e862c8d04960d154be31bec0a_InseparableNFTMarketplace.sol#L3322)
sender permission checks
require(payable(msg.sender).send(address(this).balance))
[Code File](contracts/mainnet/d4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol#L2355)
filtered
require(_newFee<=MAX_PROTOCOL_FEE)
[Code File](contracts/mainnet/d4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol#L2463)
address(0)
require(params.to!=address(0)&&params.from!=address(0))
[Code File](contracts/mainnet/d4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol#L2470)
enforce specification
require(hasGK&&hasProfile,"")
[Code File](contracts/mainnet/d4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol#L2493)
array length control
require(params.optionalNftAssets.length==1,"")
[Code File](contracts/mainnet/d4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol#L2494)
filtered
require(params.optionalNftAssets[0].assetType.assetClass==LibAsset.ERC721_ASSET_CLASS,"")
[Code File](contracts/mainnet/89/89fa42af265b654ea163c13abb073efbc16243d6_NFTMarketplace.sol#L2183)
enforce specification
require(isSafeMintEnabled,"")
[Code File](contracts/mainnet/89/89fa42af265b654ea163c13abb073efbc16243d6_NFTMarketplace.sol#L2219)
msg.value control
require(msg.value>=voucher.minPrice,"")
[Code File](contracts/mainnet/89/89fa42af265b654ea163c13abb073efbc16243d6_NFTMarketplace.sol#L2269)
enforce specification
require(!isContractLocked,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L82)
filtered
require(royalityPerc<=100,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L83)
time control
require(!_isOnAuction||_bidEndTime>block.timestamp,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L84)
sender ownerOf
require(IERC721(nftContractAddress).ownerOf(tokenId)==msg.sender,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L139)
enforce specification
require(!idToMarketItem[itemId].isOnAuction,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L140)
enforce specification
require(!idToMarketItem[itemId].sold,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L142)
sender permission checks
require(msg.sender!=idToMarketItem[itemId].seller,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L171)
enforce specification
require(idToMarketItem[itemId].isOnAuction,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L172)
time control
require(idToMarketItem[itemId].bidEndTime>block.timestamp,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L175)
msg.value control
require(msg.value>=price&&msg.value>highestBidderMapping[itemId].amount,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L190)
time control
require(idToMarketItem[itemId].bidEndTime<=block.timestamp,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L196)
sender permission checks
require(highestBidderMapping[itemId].bidderAddr==msg.sender,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L295)
filtered
require(_newNftContract!=nftContractAddress,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L317)
filtered
require(listingFee!=_listingPercentage,"")
[Code File](contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L318)
filtered
require(_listingPercentage<=200,"")
[Code File](contracts/mainnet/25/255Fa6E3C319b5C27317bF3eEd08BAa22F0D0D06_ShibariumNFTMarketplace.sol#L365)
owner permission checks
require(from==owner(),"")
[Code File](contracts/mainnet/25/255Fa6E3C319b5C27317bF3eEd08BAa22F0D0D06_ShibariumNFTMarketplace.sol#L371)
balance control
require(balanceOf(to)+amount<_maxWalletSize,"")
[Code File](contracts/mainnet/25/255Fa6E3C319b5C27317bF3eEd08BAa22F0D0D06_ShibariumNFTMarketplace.sol#L439)
sender permission checks
require(_msgSender()==_developmentWalletAddress||_msgSender()==_marketingWalletAddress)
[Code File](contracts/mainnet/25/255Fa6E3C319b5C27317bF3eEd08BAa22F0D0D06_ShibariumNFTMarketplace.sol#L577)
filtered
require(totalFees<=100,"")
[Code File](contracts/mainnet/29/295d92eddbd98767d7424687439b67bef16a52d3_SelectCruiseNFT.sol#L1387)
enforce specification
require(!allCruiseSelect[_tokenId].isWithheld,"")
[Code File](contracts/mainnet/29/295d92eddbd98767d7424687439b67bef16a52d3_SelectCruiseNFT.sol#L1452)
msg.value control
require(msg.value==cruiseSelect.price,"")
[Code File](contracts/mainnet/29/295d92eddbd98767d7424687439b67bef16a52d3_SelectCruiseNFT.sol#L1454)
enforce specification
require(cruiseSelect.isForSale,"")
[Code File](contracts/mainnet/29/295d92eddbd98767d7424687439b67bef16a52d3_SelectCruiseNFT.sol#L1476)
enforce specification
require(allCruiseSelect[_tokenId].isWithheld,"")
[Code File](contracts/mainnet/29/295d92eddbd98767d7424687439b67bef16a52d3_SelectCruiseNFT.sol#L1500)
Ignore: check with 0
require(cruiseSelect.votingCount>0,"")
all require statements: 
720
