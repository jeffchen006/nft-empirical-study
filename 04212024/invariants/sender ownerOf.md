require(_nft.ownerOf(_tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L146)

require(msg.sender==_nft.ownerOf(_tokenId),"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L226)

require(_nft.ownerOf(_tokenId)!=msg.sender,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L270)

require(_offer.owner==msg.sender,"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L341)

require(owner()==_msgSender(),"")
[Code File](../../contracts/mainnet/c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol#L592)

require(tokenContract.ownerOf(tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol#L314)

require(sender==assetOwner,"")
[Code File](../../contracts/mainnet/4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol#L247)

require(kotketNFT.ownerOf(_tokenId)==_msgSender(),"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L66)

require(depositItemInfoMap[_tokenId].owner==_msgSender(),"")
[Code File](../../contracts/mainnet/66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol#L80)

require(_isApprovedOrOwner(_msgSender(),tokenId),"")
[Code File](../../contracts/mainnet/ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol#L1265)

require(nftContract.ownerOf(params.nft.tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L227)

require(IERC721(params.nft.addr).ownerOf(params.nft.tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L370)

require(nft.ownerOf(params.nft.tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L405)

require(users[msg.sender][role]||msg.sender==owner(),"")
[Code File](../../contracts/mainnet/61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol#L1249)

require(IYFIAGNftMarketplace(yfiagNftMarketplace).isOwnerOfRoot(_rootId,msg.sender),"")
[Code File](../../contracts/mainnet/4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol#L630)

require(msg.sender==owner)
[Code File](../../contracts/mainnet/9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol#L55)

require(msg.sender==owner,"")
[Code File](../../contracts/mainnet/df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol#L1368)

require(owner==msg.sender,"")
[Code File](../../contracts/mainnet/e6/e6d721ae851e90c2870df2d4526faae5c5cd2405_NFTMarketplace.sol#L1198)

require(idToMarketItem[tokenId].owner==msg.sender,"")
[Code File](../../contracts/mainnet/e6/e6d721ae851e90c2870df2d4526faae5c5cd2405_NFTMarketplace.sol#L1245)

require(IERC721(asset.collection).ownerOf(asset.ids[j])==msg.sender)
[Code File](../../contracts/mainnet/19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol#L62)

require(IERC721(_nft).ownerOf(_tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L809)

require(msg.sender==offer.owner,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L814)

require(nft.ownerOf(_tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L896)

require(msg.sender==IERC721(_nft).ownerOf(_tokenId),"")
[Code File](../../contracts/mainnet/2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol#L994)

require(rentalItemInfoMap[_tokenId].owner==_msgSender(),"")
[Code File](../../contracts/mainnet/6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol#L113)

require(msg.sender==tokenContract.ownerOf(tokenId),"")
[Code File](../../contracts/mainnet/e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol#L82)

require(msg.sender==marketOwner,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L457)

require((msg.sender==MarketItemDatabase[tokenId].nftCreator&&MarketItemDatabase[tokenId].nftOwner==address(0))||msg.sender==MarketItemDatabase[tokenId].nftOwner,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L477)

require((msg.sender==MarketItemDatabase[tokenId].nftCreator&&MarketItemDatabase[tokenId].nftOwner==address(0))||msg.sender==MarketItemDatabase[tokenId].nftOwner||msg.sender==marketOwner,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L484)

require(msg.sender!=marketOwner,"")
[Code File](../../contracts/mainnet/d6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol#L496)

require(_sender==owner(),"")
[Code File](../../contracts/mainnet/f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol#L3333)

require(IERC721(_collection).ownerOf(_tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol#L1714)

require(msg.sender==proxyOwner(),"")
[Code File](../../contracts/mainnet/43/438AbFE329C0F38c02C971B8d34307beB06aD778_IndigenaNFTMarketplace.sol#L103)

require(_msgSender()==sales[_nftContract][_tokenId].owner,"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L495)

require(_msgSender()==dutchAuctions[_nftContract][_tokenId].owner,"")
[Code File](../../contracts/mainnet/43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol#L826)

require(ownerOf(_tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L259)

require(ownerOf(_tokenId)!=msg.sender,"")
[Code File](../../contracts/mainnet/a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol#L319)

require(msg.sender==ownerOf(_tokenId),"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L178)

require(admins[msg.sender]||owner==msg.sender,"")
[Code File](../../contracts/mainnet/1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol#L1351)

require(saleItemInfoMap[_tokenId].owner==_msgSender(),"")
[Code File](../../contracts/mainnet/b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol#L56)

require(nft.ownerOf(tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol#L788)

require(tokenOwner==msg.sender,"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1390)

require(tokenOwner!=msg.sender,"")
[Code File](../../contracts/mainnet/1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol#L1446)

require(_owner==_msgSender(),"")
[Code File](../../contracts/mainnet/c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol#L99)

require(owner()==msg.sender,"")
[Code File](../../contracts/mainnet/c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol#L122)

require(msg.sender!=ownerAddress)
[Code File](../../contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1876)

require(msg.sender==ERC721.ownerOf(tokenId))
[Code File](../../contracts/mainnet/02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol#L1908)

require(IERC721(nftContractAddress).ownerOf(tokenId)==msg.sender,"")
[Code File](../../contracts/mainnet/44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol#L84)

