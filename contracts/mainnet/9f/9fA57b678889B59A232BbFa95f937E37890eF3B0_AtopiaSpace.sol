// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IBucks.sol";

interface IAtopia {
	function owner() external view returns (address);

	function bucks() external view returns (IBucks);

	function getAge(uint256 tokenId) external view returns (uint256);

	function ownerOf(uint256 tokenId) external view returns (address);

	function update(uint256 tokenId) external;

	function exitCenter(
		uint256 tokenId,
		address center,
		uint256 grown,
		uint256 enjoyFee
	) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBucks {
	function mint(address account, uint256 amount) external;

	function burn(uint256 amount) external;

	function burnFrom(address account, uint256 amount) external;

	function transfer(address recipient, uint256 amount) external returns (bool);

	function transferFrom(
		address sender,
		address recipient,
		uint256 amount
	) external returns (bool);

	function balanceOf(address account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICenter {
	function setId(uint256 _id) external;

	function enter(uint256 tokenId) external returns (uint256);

	function exit(uint256 tokenId) external returns (uint256);

	function work(uint256 tokenId, uint16 task, uint256 working) external returns (uint256);

	function enjoyFee() external view returns (uint16);

	function grown(uint256 tokenId) external view returns (uint256);

	function rewards(uint256 tokenId) external view returns (uint256);

	function metadata() external view returns (string memory);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/// @notice Modern and gas efficient ERC-721 + ERC-20/EIP-2612-like implementation,
/// including the MetaData, and partially, Enumerable extensions.
contract ERC721 {
	/*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

	event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

	event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);

	event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

	/*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

	address implementation_;
	address public admin;

	string public name;
	string public symbol;

	/*///////////////////////////////////////////////////////////////
                             ERC-721 STORAGE
    //////////////////////////////////////////////////////////////*/

	mapping(address => uint256) public balanceOf;

	mapping(uint256 => address) public ownerOf;

	mapping(uint256 => address) public getApproved;

	mapping(address => mapping(address => bool)) public isApprovedForAll;

	/*///////////////////////////////////////////////////////////////
                             VIEW FUNCTION
    //////////////////////////////////////////////////////////////*/

	modifier onlyOwner() {
		require(msg.sender == admin);
		_;
	}

	function owner() external view returns (address) {
		return admin;
	}

	/*///////////////////////////////////////////////////////////////
                              ERC-20-LIKE LOGIC
    //////////////////////////////////////////////////////////////*/

	function transfer(address to, uint256 tokenId) external {
		require(msg.sender == ownerOf[tokenId], "NOT_OWNER");

		_transfer(msg.sender, to, tokenId);
	}

	/*///////////////////////////////////////////////////////////////
                              ERC-721 LOGIC
    //////////////////////////////////////////////////////////////*/

	function supportsInterface(bytes4 interfaceId) external pure returns (bool supported) {
		supported = interfaceId == 0x80ac58cd || interfaceId == 0x5b5e139f;
	}

	function approve(address spender, uint256 tokenId) external {
		address owner_ = ownerOf[tokenId];

		require(msg.sender == owner_ || isApprovedForAll[owner_][msg.sender], "NOT_APPROVED");

		getApproved[tokenId] = spender;

		emit Approval(owner_, spender, tokenId);
	}

	function setApprovalForAll(address operator, bool approved) external {
		isApprovedForAll[msg.sender][operator] = approved;

		emit ApprovalForAll(msg.sender, operator, approved);
	}

	function transferFrom(
		address from,
		address to,
		uint256 tokenId
	) public {
		require(
			msg.sender == from || msg.sender == getApproved[tokenId] || isApprovedForAll[from][msg.sender],
			"NOT_APPROVED"
		);

		_transfer(from, to, tokenId);
	}

	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenId
	) external {
		safeTransferFrom(from, to, tokenId, "");
	}

	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) public {
		transferFrom(from, to, tokenId);

		if (to.code.length != 0) {
			// selector = `onERC721Received(address,address,uint,bytes)`
			(, bytes memory returned) = to.staticcall(
				abi.encodeWithSelector(0x150b7a02, msg.sender, from, tokenId, data)
			);

			bytes4 selector = abi.decode(returned, (bytes4));

			require(selector == 0x150b7a02, "NOT_ERC721_RECEIVER");
		}
	}

	/*///////////////////////////////////////////////////////////////
                          INTERNAL UTILS
    //////////////////////////////////////////////////////////////*/

	function _transfer(
		address from,
		address to,
		uint256 tokenId
	) internal {
		require(ownerOf[tokenId] == from);
		_beforeTokenTransfer(from, to, tokenId);

		balanceOf[from]--;
		balanceOf[to]++;

		delete getApproved[tokenId];

		ownerOf[tokenId] = to;
		emit Transfer(msg.sender, to, tokenId);
	}

	function _mint(address to, uint256 tokenId) internal {
		require(ownerOf[tokenId] == address(0), "ALREADY_MINTED");

		// This is safe because the sum of all user
		// balances can't exceed type(uint256).max!
		unchecked {
			balanceOf[to]++;
		}

		ownerOf[tokenId] = to;

		emit Transfer(address(0), to, tokenId);
	}

	function _burn(uint256 tokenId) internal {
		address owner_ = ownerOf[tokenId];

		require(owner_ != address(0), "NOT_MINTED");
		_beforeTokenTransfer(owner_, address(0), tokenId);

		balanceOf[owner_]--;

		delete ownerOf[tokenId];

		emit Transfer(owner_, address(0), tokenId);
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 tokenId
	) internal virtual {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IAtopia.sol";
import "../interfaces/ICenter.sol";

contract AtopiaSpace is ERC721 {
	bool public initialized;
	using Counters for Counters.Counter;
	Counters.Counter private _tokenIds;

	struct Task {
		uint256 id;
		uint256 info;
		uint256 rewards;
	}

	IAtopia public atopia;
	ICenter[] public centers;
	mapping(uint256 => uint256) public lives;

	Task[] public tasks;

	event TaskUpdated(Task task);
	event LifeUpdated(uint256 tokenId, uint256 life);

	function initialize(address _atopia) public {
		require(!initialized);
		initialized = true;
		name = "Atopia Space";
		symbol = "ATPSPACE";
		atopia = IAtopia(_atopia);
	}

	modifier onlyTokenOwner(uint256 tokenId) {
		require(atopia.ownerOf(tokenId) == msg.sender);
		_;
	}

	modifier onlyAtopia() {
		require(msg.sender == atopia.owner());
		_;
	}

	function totalTasks() external view returns(uint256) {
		return tasks.length;
	}

	function totalCenters() external view returns (uint256) {
		return centers.length;
	}

	function getLife(uint256 tokenId)
		public
		view
		returns (
			uint256 job,
			uint256 task,
			uint256 data
		)
	{
		uint256 life = lives[tokenId];
		data = life & ((1 << 129) - 1);
		life = life >> 128;
		task = life & 0xFFFF;
		job = life >> 64;
	}

	function addTask(uint128 duration, uint128 minAge, uint256 rewards) external onlyAtopia {
		Task memory newTask = Task(tasks.length + 1, (uint256(duration) << 128) | minAge, rewards);
		tasks.push(newTask);
		emit TaskUpdated(newTask);
	}

	function updateTask(uint256 id, uint128 duration, uint128 minAge, uint256 rewards) external onlyAtopia {
		uint256 index = id - 1;
		tasks[index].info = (uint256(duration) << 128) | minAge;
		tasks[index].rewards = rewards;
		emit TaskUpdated(tasks[index]);
	}

	function addCenter(address center) external onlyAtopia {
		ICenter newCenter = ICenter(center);
		centers.push(newCenter);
		uint256 id = centers.length;
		_mint(msg.sender, id);
		newCenter.setId(id);
	}

	function enter(uint256 tokenId, uint256 centerId) external onlyTokenOwner(tokenId) {
		require(lives[tokenId] == 0);
		atopia.update(tokenId);
		lives[tokenId] = centers[centerId - 1].enter(tokenId);
		emit LifeUpdated(tokenId, lives[tokenId]);
	}

	function exit(uint256 tokenId, uint256 centerId) external onlyTokenOwner(tokenId) {
		(uint256 job, uint256 task, ) = getLife(tokenId);
		require(job == centerId && task == 0);
		uint256 centerIndex = centerId - 1;
		atopia.exitCenter(
			tokenId,
			address(centers[centerIndex]),
			centers[centerIndex].exit(tokenId),
			centers[centerIndex].enjoyFee()
		);
		lives[tokenId] = 0;
		emit LifeUpdated(tokenId, 0);
	}

	function work(
		uint256 tokenId,
		uint256 centerId,
		uint16 task
	) external onlyTokenOwner(tokenId) {
		(uint256 job, uint256 currentTask, ) = getLife(tokenId);
		uint256 life;
		if (task > 0) {
			require(job == 0 || job == centerId);
			life = centers[centerId - 1].work(tokenId, task, lives[tokenId]);
		} else {
			require(job == centerId && currentTask > 0);
			centers[centerId - 1].work(tokenId, task, lives[tokenId]);
		}
		lives[tokenId] = life;
		emit LifeUpdated(tokenId, life);
	}

	function tokenURI(uint256 tokenId) public view returns (string memory) {
		return centers[tokenId - 1].metadata();
	}
}