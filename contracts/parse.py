import sys, os
import random

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
CONTRACT_DIR = SCRIPT_DIR + "/mainnet/"
import requests, json
import re

# interactively search in CONTRACT_DIR, find all files ending with .sol
# and print the file name
def search_files():
    nft_marketplace_contracts = []
    for root, dirs, files in os.walk(CONTRACT_DIR):
        for file in files:
            if file.endswith(".sol"):
                # print(os.path.join(root, file))
                # search whether "NFTMarketplace" keywork is in the file
                # ignore upper or lower case
                with open(os.path.join(root, file), 'r') as f:
                    content = f.read()
                    content = content.lower()

                    if "energy" in content and "trad" in content and \
                        "buy" in content and "sell" in content and "msg.sender" in content and \
                        "uniswap" not in content and "erc721" not in content:
                        print("energy found in " + os.path.join(root, file))
                        nft_marketplace_contracts.append(os.path.join(root, file))
                    else:
                        # print("NFTMarketplace not found in " + os.path.join(root, file))
                        pass
    return nft_marketplace_contracts


path = os.path.join(SCRIPT_DIR, "cache.json")
print("Path: " + path)


class CrawlEtherscan:
    def __init__(self):
        EtherScanApiKeys = [ "8SD5GA6IKF28CJQ6PF7IJPUMA2RTYSM158", "T36ZIMU3MF25YFFWD723FTQB9QWWBV1R57", "GMUISR1UKTHXUQZ1VVHBAPXHA3V6HPSSSM", "V63CW1KDZUB5CAP1IBDWX79J2T5FWA3JDQ", "I7R59ER7AQ8HEBYTNR15ETXJSMTD86BHA4", "3PCW417G8C6U4CZDEWA54Q97DNMDZ4ER7A", "MTCCCJ1BW2I8EA5EJN714N6ZH67DY74HHF", "W9C78R6J4B7ABDWK5149P73CP2JSMX8QTW", "H8CKJDHKBPU6AUD7UJGVA4E31J6RTHUJES",]
        self.etherscanAPIkeys = EtherScanApiKeys
        self.counter = random.randint(0, len(self.etherscanAPIkeys))
        self.ABIMap = {}

        path = os.path.join(SCRIPT_DIR, "cache.json")
        print("Path: " + path)

        if os.path.exists(path):
            with open(path, 'r') as f:
                self.ABIMap = json.load(f)
    


    def getEtherScanAPIkey(self):
        self.counter += 1
        numOfAPIkeys = len(self.etherscanAPIkeys)
        return self.etherscanAPIkeys[self.counter % numOfAPIkeys]


    def Contract2ABI(self, contractAddress: str):
        """Given a contract address, return the ABI"""
        if contractAddress in self.ABIMap:
            return self.ABIMap[contractAddress]
        GETrequest = 'https://api.etherscan.io/api?module=contract'\
            '&action=getabi'\
            '&address={}'\
            '&apikey={}'.format(contractAddress, self.getEtherScanAPIkey())
        response = requests.get(GETrequest).json()
        if response['result'] == 'Contract source code not verified':
            self.ABIMap[contractAddress] = {}
            return {}
        result = json.loads(response['result'])
        self.ABIMap[contractAddress] = result

        with open(path, 'w') as f:
            json.dump(self.ABIMap, f)

        return result


def filterFunctionABI(result):
    print("Filtering function ABI")
    print(result)
    new_functionNames = []
    for map in result:
        if "type" not in map:
            continue
        if "type" in map and map["type"] != "function":
            continue
        if "stateMutability" in map and (map["stateMutability"] == "view" or map["stateMutability"] == "pure"):
            continue

        if "name" in map:
            new_functionNames.append(map["name"])
    return new_functionNames



def countFrequency(nft_marketplace_contracts):
    function_frequency = {}
    ce = CrawlEtherscan()
    for contract in nft_marketplace_contracts:
        # extract its address and name
        contract_array = contract.split("_")
        address = contract_array[0]
        address = address.split("/")[-1]
        name = contract_array[1].split(".")[0]
        print("Address: " + address)
        print("Name: " + name)
        functionABI = ce.Contract2ABI( "0x" + address)
        print("Function ABI: ")
        new_functionABI = filterFunctionABI(functionABI)
        path = "contracts/mainnet/" + contract
        for function in new_functionABI:
            if function not in function_frequency:
                function_frequency[function] = [path]
            else:
                function_frequency[function].append(path)
    # sort the function_frequency
    function_frequency_list = sorted(function_frequency.items(), key=lambda x: len(x[1]), reverse=True)
    print("Function frequency list: ")
    for entry in function_frequency_list:
        print("({}, {})".format(entry[0], len(entry[1]) ))
        # print(entry[0], "frequency: ", len(entry[1]))
        # for path in entry[1]:
        #     print("[Code File]({})".format(path))



def statement2Tag(statement):
    tag = "Uncategorizable"
    statement = statement.lower()
    if statement.startswith("//"):
        tag = "Ignore: comment"
    elif "require(false);" in statement:
        tag = "Ignore: always false"
    elif "require(true);" in statement:
        tag = "Ignore: always true"
    elif re.search(r"require\(([abcxyz_+-/*)\(\)><=]+)\)" , statement, re.IGNORECASE):
        tag = "Ignore: safe math"
    elif re.search(r"require\(([abcxyz_+-/*)\(\)><=]+)\," , statement, re.IGNORECASE):
        tag = "Ignore: safe math"
    elif "!=0" in statement or ">0" in statement or ">=0" in statement or "==0" in statement:
        tag = "Ignore: check with 0"
            
    # Suppose no arithmetic operations between the first ! and the first comma in statement
    elif re.search(r"require\(([a-zA-Z_.&|!\[\]]+)," , statement, re.IGNORECASE):
        # tag = "Ignore: check status (belong to enforce specification)"
        tag = "enforce specification"
    
    # Suppose no arithmetic operations between the first ! and the first comma in statement
    elif re.search(r"require\(([a-zA-Z_.&|!\[\]]+)\)" , statement, re.IGNORECASE):
        # tag = "Ignore: check status"
        tag = "enforce specification"
        
    else:
        #  status check 
        if "sender" in statement and "owner" in statement:
            tag = "sender ownerOf"
        elif "sender" in statement:
            tag = "sender permission checks"
        elif "owner" in statement:
            tag = "owner permission checks"
        elif "address(0)" in statement:
            tag = "address(0)"
        elif "time" in statement or "period" in statement:
            tag = "time control"
        elif "_offerId" in statement:
            tag = "offerId control"
        elif "whitelist" in statement:
            tag = "whitelist control"
        elif "value" in statement:
            tag = "msg.value control"
        elif "iscontract" in statement:
            tag = "EOA validation"
        elif "balance" in statement and (">" in statement or "<" in statement):
            tag = "balance control"
        elif "length" in statement:
            tag = "array length control"
        elif "amount" in statement and ("==" in statement or "!=" in statement):
            tag = "amount enforcement"



    return tag 




def collectInvariantGuards(nft_marketplace_contracts):
    all_require_statements = []
    all_clickables = []

    for nft_marketplace_contract in nft_marketplace_contracts:
        path = CONTRACT_DIR + nft_marketplace_contract
        relative_path = "../../contracts/mainnet/" + nft_marketplace_contract
        lines = []
        with open(path, 'r') as f:
            lines = f.readlines()

        # find all require statements
        # start from require keyword and end with ;
        # the line should not contain // or /* at the start of the line
        require_statements = []
        for i in range(len(lines)):
            line = lines[i]
            line = line.strip()
            if line.startswith("require")  and ";" in line and (not line.startswith("//")) and (not line.startswith("/*")):
                # prune all comments after ;
                line = line.split(";")[0]
                # remove all error messages in line inside ""
                # remove all space in the statement
                line = re.sub(' ', '', line)
                # remove all contents within ""
                line = re.sub(r'".*?"', r'""', line)
                line = re.sub(r'\'.*?\'', r'""', line)
                
                require_statements.append(line)
                # print(line)
                if line not in all_require_statements:
                    all_require_statements.append(line)
                    clickable = "[Code File]({}#L{})".format(relative_path, i+1)
                    all_clickables.append(clickable)

                    # print(clickable)
                    # tag = statement2Tag(line)
                    # print(tag)
                    # print(line)
    

    for ii in range(len(all_require_statements)):
        tag = statement2Tag(all_require_statements[ii])
        print(tag)
        print(all_require_statements[ii])
        print(all_clickables[ii])
        print("")
        file = SCRIPT_DIR + "/../04212024/invariants/" + tag + ".md"
        with open(file, 'a') as f:
            f.write(all_require_statements[ii] + "\n")
            f.write(all_clickables[ii] + "\n")
            f.write("\n")


    # for require_statement in all_require_statements:
    #     tag = statement2Tag(require_statement)
    #     print(tag)
    #     print(require_statement)
    #     print("")
        
            
            




if __name__ == "__main__":
    # nft_marketplace_contracts = search_files()

    # print("energy contracts found: ")
    # print(nft_marketplace_contracts)


    # nft_marketplace_contracts = ['c7/C7ddD330A9aE4870d4100363846fE84b40d01e37_NFTMarketplace.sol', 'c7/c731d111023b11EB39606B672Be35f20C6D88Af1_NFTMarketplace.sol', 'b9/b9dccd2226dd494edd39f4f5dbbc0396c2cab369_EKotketDeposit.sol', '74/74a165e5c6548a0acdaf41cb14b87f8873767724_DreamMarketplace.sol', '4c/4c384b89d830acbe01b86f681ebd5799768049d6_NFTMarketplace.sol', '4c/4c8053bE7F94Dc09Bacc9b25185691E9FeeF69E7_NFTMarketplace.sol', '66/66cBDbEbD5939ea74781Fe7Fe24a5EB3d346AD6C_EKotketNFTPlatformRenting.sol', 'ea/EA1Ab2B141cd28A86531Ae256EA95580cC5A469e_NFTMarketplaceMain.sol', '61/611F183e3Bf5bAb879F9182d290eA3d6b1d36cB5_LoveNFTMarketplace.sol', 'dc/dc4838bb0496b351875d7e418f91f1a49d060b5f_NFTMarket.sol', '60/608CBd7fFa4dab279044e55994E60dc6b4b4DfE1_EKotketToken.sol', '60/60c19bc4f6b9e31e13cc648a3f84b57ad811c832_NftMarketplace.sol', '4f/4FC740E85B8CE94ac5793540A3476e4A164eE691_YFIAGLaunchPad.sol', '3e/3eb0c8a43530f0ab82977657055212d045429ed4_ElumntNFTMarketplace.sol', '3e/3e34b6C953E0007fFa321368999356253E806DD9_NFTMarketplace.sol', 'b1/b1Bd9dbf9AE5AfAa56b4714E34aA8354152e75BF_NftMarketplace.sol', '9a/9a4aeB1e97f25A29afE8C954bFb08f098E510889_NFTMarketplace.sol', 'df/dfce2ce8742929275c7dad33be711f4cc0efad58_IndigenaNFTMarketplace.sol', 'e6/e6d721ae851e90c2870df2d4526faae5c5cd2405_NFTMarketplace.sol', 'e5/e55e4479d9184572bce3D74064d112c3eC50F40e_EKotketNFTFactory.sol', '17/1793F72840c11229856474A7F8390b2c922D1C1b_NFTMarketplace.sol', '19/193d0F85AC3016f3d6438947D32a291335258891_NftMarketplace.sol', '19/19537635595aac362D8FC6d14CCdF6b54D8cFC28_YFIAGNftPool.sol', '2a/2a5375d4a764306abbfeb0264836310fb6b58049_BharatNFTMarketplace.sol', '6e/6E2AD06A5B22c91daCedC9F6A9F33aC02Edcba70_EKotketNFTRentalMarket.sol', 'e0/E04b882684CECe7511b9cb1f88Ac07aCdfc0FAEB_NFTMarketplace.sol', '4a/4a84aa90441533da3758f63ec07133b2e5754b8a_LooxooryNFTMarketplace.sol', 'd6/d63b49eb1AfD14C0eD636AC58805a39A29b3B1C4_NFTMarketplace.sol', 'bc/bc3Fc7bf165456d059012Cd9873F2999Bdd4de56_EKotketNFTPlatformRenting.sol', '45/4554a91fBF3eB46c8d743293dECd02166A8a872F_NFTMarketplace.sol', '88/887067939fA33E1c9B755B222fE92BAd2717691b_TransferManagerERC1155.sol', '30/300d329C6A9DACd1A1369FaB1B84BD04b8C28789_EKotketSwap.sol', 'f5/f577959c9071751599b4596c299168d576a55428_NFTMarketplace.sol', '94/948B0DEA9Af7d78C29335f0E47BAa4799F643EBC_NFTMarketplace.sol', 'e8/e8397648725B057bed2bAd5f7Dd06B4d5A67bA46_EKotketNFT.sol', 'f1/f14951143d367d91fc9d265c1315d755352f4029_NFTMarketplaceV2.sol', '43/438AbFE329C0F38c02C971B8d34307beB06aD778_IndigenaNFTMarketplace.sol', '43/4388FB16452487572dd4094CbE0c52E686Aa3B4D_NFTMarketplaceV3.sol', '43/4381D8191bE655C7FDaC93a741A06b8a972B47Dd_VinciNFTMarketplace.sol', 'a6/A67219CF6D5e191B7974d2bE34303112B925975A_YFIAGNftMarketplace.sol', '7b/7b380299C8eDA4527C83174918199d702611e876_APONFT.sol', '20/208E6482f79baAcdf7Dc80d75aaCe77C5fA8306D_CHDNFTMarketplace.sol', 'db/db891C608eeB12c1A0842Cb2A96BC58E65E5d971_NFTMarketplace.sol', '4d/4d28b1d8379f31edf9d9f28492ad720b0dc1a158_NftMarketplace.sol', '1f/1f6158Eee5F6e178149be6723D2292524dFA8B0d_NFTMarketplace.sol', '1f/1fd402c590de2fcd0e9d637593100309dad44c68_PaybNftMarketplace.sol', '9f/9f3f22ea0e4bacac1bb4d3782a6c2cfe8bba2e8b_NFTMarketplace.sol', 'ca/caE3aB3D711bccCaE4f2C58ce0F146EB8bB840Bf_NFTMarketplace.sol', 'b8/B84579206c7c6F17c2f0F09fE36A0112Bb121471_EKotketNFTMarketPlace.sol', '69/69BBA61A3Af1A2d60826c96c8dc21931BdB62918_ElumntNFTMarketplace.sol', '18/189651ffa5edc7e0bbb45c76d303dc9890b4741d_NFTMarketplace.sol', '18/18525F9CaF7A504Babe36749da555528b6187116_TransferManagerERC721.sol', '18/182fE1Af2E5a1a0FFe0BfE963dF263BE8BCA7860_NFTMarketplace.sol', '52/5270F16B34e59338D759d34DDDb9BD3351509274_NFTMarketplace.sol', 'f7/F79C84466bE12275E441C140f836F095c74e06b4_NFTMarketplace.sol', '11/115ac133b7267ea05d146caa64d4140425a43dc8_EmillionNftMarketPlace.sol', '7c/7Cf1651F4fc2381Da17F7eA8658Bb5a07CfefEC7_TNFTMarketplace.sol', '6c/6Ca527a0b0864d1da179C5b5A9Ba90A5Bcfe09c9_NftMarketplace.sol', '1a/1a22d99d1853b8804ea5c95c87dfdef8a41f6c88_DentistCoinNFTMarketPlace.sol', '1a/1a2D6749877DD9C0dba47703ea12Eabffb69F9C0_EliteCruiseNFT.sol', '1a/1ab6cb2780087feef3c61ad2c5e0cce43a8e93dd_NftMarketplace.sol', 'c3/C3585596b9276fe0FC8435Db30696D3C9642D920_ShibariumNftMarketplace.sol', 'c3/C3790515A1c3ecF2df4bA4875cF00200d8723487_BundNFTMarketPlace.sol', '02/02d06e8a3348f5d277d9ff3160c8d3017aa0c4ca_NFTMarketplace.sol', '3d/3dc7941f028f7b5e862c8d04960d154be31bec0a_InseparableNFTMarketplace.sol', 'd4/D4D33d92b26897863725E31267f18309B27851e3_NftMarketplace.sol', '89/89fa42af265b654ea163c13abb073efbc16243d6_NFTMarketplace.sol', '44/446248C193f7abcD35C30E2f3475b0792b1B3643_PhynomNFTMarketplace.sol', '25/255Fa6E3C319b5C27317bF3eEd08BAa22F0D0D06_ShibariumNFTMarketplace.sol', '59/591ca1413d658c80b7b3a43994fa373707d0cb16_IndigenaNFTMarketplace.sol', '2c/2cCb4b249d59725a5E1d347a5a13B4F4fa3b2A36_NFTMarketplace.sol', '29/295d92eddbd98767d7424687439b67bef16a52d3_SelectCruiseNFT.sol', 'dd/dde38EC15dC7D6F56c03C48b59b81fb53B89c4d3_NFTMarketplace.sol', '58/58D33e389e28ad8d5D106C26DAF3334Ff5fDa18F_NFTMarketplace.sol', 'e7/E7043244AB2F1D519DFac2cc53CE68a98B664C87_EKotketToken.sol', '9c/9C180ae7ecD526249B84492964E68FB76a40cd49_NFTMarketplace.sol', '2d/2DE5daB3d894CE05e7BBee181216Ef1aDfa8565C_BundNFTMarketPlace.sol']

    # # # copy all nft marketplace contracts to a new folder selectedContracts
    # # for contract in nft_marketplace_contracts:
    # #     command = "cp " + CONTRACT_DIR + contract + " " + CONTRACT_DIR + "../../selectedContracts/"
    # #     print(command)
    # #     os.system(command)

    # # print(len(nft_marketplace_contracts))
    # # countFrequency(nft_marketplace_contracts)   
    # collectInvariantGuards(nft_marketplace_contracts) 


    energy_contracts = ['ad/ADc6cfA74Bc2547DE15d7505C1aC1cF7BB4BEF14_GreenEnergyToken.sol', '95/95f8eaca2144583e2eb93d66fb13909d07f1a37f_Lithereum.sol', 'ff/ffb3518f60a967839e5ba5b2908c5d6840632c0f_Thera.sol', '36/368ddbe57405eae0d969152a449c013d2c79bf91_TheraAether.sol', '8b/8b9d4a796c55a28e65eb276d7ec016f5cd6a4116_GreenEnergyToken.sol', '71/718916cfd58297fbe92cbd9c5231ff7912327b66_TheraAether.sol', 'e8/e89a194d366a3f18b06ced6474dc7daba66efa83_QuantumEnergy.sol', '91/9157494ecd62333b03c348efa9e7a5af03f87476_EtherKnightGame.sol', '44/44cbf53666ee06327869ff06a10205f83c76ac58_FantasyHeroes.sol', 'ce/ceaf9dfe40f9c0ba586f2990c4b33c4c98a53d8b_QuantumEnergy.sol']
    # # copy all energy trading contracts to a new folder selectedEnergyTradingContracts
    # for contract in energy_contracts:
    #     command = "cp " + CONTRACT_DIR + contract + " " + CONTRACT_DIR + "../../selectedEnergyTradingContracts/"
    #     print(command)
    #     os.system(command)
    
    countFrequency(energy_contracts)   
    # collectInvariantGuards(energy_contracts) 
