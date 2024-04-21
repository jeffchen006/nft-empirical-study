/**
 *Submitted for verification at Etherscan.io on 2022-11-28
*/

contract mycoin{

mapping (address => uint) public balances;
mapping (address => mapping (address=>uint)) public allowance;
 uint public totalSupply = 700000000 * 10 ** 18;
 string public name = "Mycoin";
 string public symbol = "MY";
 uint public decimals = 18;
 constructor(){
     balances[msg.sender] = totalSupply;
 }
 
 function balanceOf(address owner) public view returns (uint){
     return balances[owner];
 }
 
 event Transfer(address indexed from, address indexed to, uint value);
 event Approval(address indexed owner, address indexed spender, uint value);
 
 function transfer(address to, uint value) public returns(bool){
     require (balanceOf(msg.sender) >= value, 'balance too low');
  balances[to] = balances[to]+ value;
  balances[msg.sender] =  balances[msg.sender]-value;
  emit Transfer(msg.sender, to, value);
  return true;
 }
 
 function transferFrom(address from, address to, uint value) public returns(bool){
     
     require(balanceOf(from)>=value, 'balance too low');
     require(allowance[from][msg.sender] >= value, 'allowance to low');
     balances[to] += value;
     balances[from] -= value;
     emit Transfer(from, to, value);
     return true;
 }
 
 function approve(address spender, uint value) public returns(bool){
     
     allowance[msg.sender][spender] = value; 
     emit Approval(msg.sender, spender, value);
     return true;
 }


 
}