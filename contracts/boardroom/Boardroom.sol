pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


import '@openzeppelin/contracts/math/Math.sol';

import '@openzeppelin/contracts/math/SafeMath.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@openzeppelin/contracts/utils/Address.sol';

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

contract Boardroom is Ownable, ReentrancyGuard
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 constant public Period = 3 days;
    uint256 constant public Percent = 100;

    IERC20 public paymentToken;
    uint256 public creationFee;
    address internal tokenCollector;
    address public operator;

    struct Record {
        bytes topic;
        bytes content;
        bytes[10] options;
        uint256[10] votes;
        uint256 deadline;
        bool ban;
    }

    Record[] public records;

    constructor(
        IERC20 _paymentToken,
        uint256 _creationFee,
        address _tokenCollector,
        address _operator
    ) public {
        paymentToken = _paymentToken;
        creationFee = _creationFee;
        tokenCollector = _tokenCollector;
        operator = _operator;
    }


    function propose(bytes memory topic, bytes memory content, bytes[10] memory options) nonReentrant public returns (uint256){
        require(topic.length < 50, "topic.length < 50");
        require(content.length < 500, "content.length < 500");
        for (uint256 i = 0; i < 10; i++) {
            require(options[i].length < 20, "options[i].length < 20");
        }
        Record memory input = Record(topic, content, options, [uint256(0), 0, 0, 0, 0, 0, 0, 0, 0, 0], block.timestamp + Period, false);
        paymentToken.safeTransferFrom(msg.sender, tokenCollector, creationFee);
        records.push(input);
        return records.length.sub(1);
    }

    function vote(uint256 pid, uint256 index, uint256 amount) nonReentrant public {
        Record storage record = records[pid];
        require(block.timestamp <= record.deadline, "The proposal has been closed, or does not exist");
        require(!record.ban, "The proposal has been banned");
        record.votes[index] = record.votes[index].add(amount);
        paymentToken.safeTransferFrom(msg.sender, tokenCollector, amount);
    }

    function ban(uint256 pid) external {
        require(msg.sender == operator || msg.sender == owner(), "only owner and operator");
        Record storage record = records[pid];
        require(record.deadline != 0, "The proposal does not exist");
        record.ban = true;
        record.topic = bytes("banned proposal");
        record.content = bytes("banned proposal");
        for (uint256 i = 0; i < 10; i++) {
            record.options[i] = bytes("banned proposal");
        }
    }

    function getTenProposals(uint256 skip, uint256 page) public view returns (Record[] memory){
        Record[] memory ret = new Record[](page);
        uint256 start = records.length.sub(1).sub(skip);
        for (uint256 i = start; i >= 0 && page > 0; i--) {
            ret[start.sub(i)] = records[i];
            page --;
        }
        return ret;
    }

    function changeOperator(address _operator) external onlyOwner {
        operator = _operator;
    }
}
