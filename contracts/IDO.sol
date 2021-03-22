pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

/*

*/
contract IDO is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public redeemTime;
    //record if the buyer has bought
    mapping(address => bool) public purchasedBuyer;
    //if purchasedAmount(targetToken's amountFactor) is 0, mean the guy didn't buy it, or it has redeemed
    mapping(address => uint256) public purchasedAmountFactor;
    //an auxiliary array for loop
    address[] public purchasedList;
    IERC20 public targetToken;
    mapping(IERC20 => uint256) public sourceAmounts;//need source token amount per subscription, zero for not allowed
    uint256 public targetAmountFactor;//redeem target token amount per subscription
    uint256 public targetTotalSupply;//for targetAmountFactor, in
    uint256 public targetTokenMultiplicationFactor;

    event Purchase(address indexed buyer, address sourceToken, uint256 sourceAmount, uint256 targetAmountFactor);
    event Redeem(address indexed buyer, uint256 targetAmount);
    event Disqualification(address indexed buyer, uint256 targetAmountFactor);

    constructor(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _redeemTime,
        IERC20[] memory _sourceTokens,
        IERC20 _targetToken,
        uint256[] memory _sourceAmounts,
        uint256 _targetAmountFactor,
        uint256 _targetTotalSupply,
        uint256 _targetTokenMultiplicationFactor
    ) public {
        require(_startTime < _endTime, "_startTime < _endTime");
        require(_endTime < _redeemTime, "_endTime< _redeemTime");
        require(_sourceTokens.length == _sourceAmounts.length, "_sourceTokens.length == _sourceAmounts.length");
        startTime = _startTime;
        endTime = _endTime;
        redeemTime = _redeemTime;
        for (uint256 i = 0; i < _sourceTokens.length; i++) {
            sourceAmounts[_sourceTokens[i]] = _sourceAmounts[i];
        }
        targetToken = _targetToken;
        targetAmountFactor = _targetAmountFactor;
        targetTotalSupply = _targetTotalSupply;
        targetTokenMultiplicationFactor = _targetTokenMultiplicationFactor;
    }

    modifier inPurchase(){
        require(startTime <= block.timestamp, "IDO has not started");
        require(block.timestamp < endTime, "");
        _;
    }

    modifier inRedeem(){
        require(redeemTime <= block.timestamp, "Redeem has not started");
        _;
    }

    modifier isTargetTokenReady(){
        require(address(targetToken) != address(0), "Target token addres not set");
        require(targetTokenMultiplicationFactor >0, "targetTokenMultiplicationFactor should not be zero");
        _;
    }

    function purchase(IERC20 sourceToken) inPurchase nonReentrant external {
        address buyer = _msgSender();
        require(purchasedBuyer[buyer] == false, "You have bought");
        require(targetTotalSupply >= targetAmountFactor, "Not enough target quota");
        uint256 sourceAmount = sourceAmounts[sourceToken];
        require(sourceAmount > 0, "Source token is not permitted");

        purchasedBuyer[buyer] = true;
        // twice is not allowed
        purchasedAmountFactor[buyer] = targetAmountFactor;
        purchasedList.push(buyer);
        targetTotalSupply = targetTotalSupply.sub(targetAmountFactor);

        SafeERC20.safeTransferFrom(sourceToken, buyer, address(this), sourceAmount);

        emit Purchase(buyer, address(sourceToken), sourceAmount, targetAmountFactor);
    }


    /*
    before redeem, target token must be transferred into this contract
    */
    function redeem() inRedeem isTargetTokenReady nonReentrant external {
        address buyer = _msgSender();
        uint256 amountFactor = purchasedAmountFactor[buyer];
        require(amountFactor != uint256(0), "You didn't purchase or you have redeemed, or you have disqualified");
        purchasedAmountFactor[buyer] = 0;
        uint256 amount = amountFactor.mul(targetTokenMultiplicationFactor);
        uint256 balance = targetToken.balanceOf(address(this));
        require(balance >= amount, "Target token balance not enough");
        SafeERC20.safeTransfer(targetToken, buyer, amount);
        emit Redeem(buyer, amount);
    }

    function redeemAll(uint256 batch) inRedeem isTargetTokenReady onlyOwner external {

        for (uint256 index = 0; index < batch; index++) {
            address buyer = purchasedList[purchasedList.length - 1];
            delete purchasedList[purchasedList.length - 1];
            uint256 amountFactor = purchasedAmountFactor[buyer];
            if (amountFactor == uint256(0)) {
                //the buyer has redeemed by himself
                continue;
            }

            purchasedAmountFactor[buyer] = 0;
            uint256 amount = amountFactor.mul(targetTokenMultiplicationFactor);
            uint256 balance = targetToken.balanceOf(address(this));
            require(balance >= amount, "Target token balance not enough");

            SafeERC20.safeTransfer(targetToken, buyer, amount);
            emit Redeem(buyer, amount);
        }
    }

    //force to flush data at any time
    function disqualify(address buyer, uint256 amountFactor) onlyOwner external {
        purchasedAmountFactor[buyer] = amountFactor;
        emit Disqualification(buyer, amountFactor);
    }

    //admin can transfer any token in emergency
    function transferSourceToken(IERC20 tokenAddress, address to, uint256 amount) onlyOwner external {
        SafeERC20.safeTransfer(tokenAddress, to, amount);
    }

    //admin can transfer any eth in emergency
    function transferETH(address to, uint256 amount) onlyOwner external {
        payable(to).transfer(amount);
    }

    function initSet(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _redeemTime
    ) onlyOwner external {
        require(block.timestamp < startTime, "updateConfig must happens before it starts");


        require(_startTime < _endTime, "_startTime < _endTime");
        require(_endTime < _redeemTime, "_endTime < _redeemTime");

        require(block.timestamp < _startTime, "new startTime must not before now");

        startTime = _startTime;
        endTime = _endTime;
        redeemTime = _redeemTime;
    }

    function updateConfig(
        uint256 _endTime,
        uint256 _redeemTime
    ) onlyOwner external {
        require(block.timestamp < endTime, "updateConfig must happens before it ends");

        if (_endTime == 0) {
            _endTime = block.timestamp;
        }


        require(startTime < _endTime, "_startTime < _endTime");
        require(_endTime < _redeemTime, "_endTime < _redeemTime");

        require(block.timestamp <= _endTime, "new endTime must not before now");

        endTime = _endTime;
        redeemTime = _redeemTime;
    }

    function changeRedeemTime(uint256 _redeemTime) onlyOwner external {
        require(endTime < _redeemTime, "endTime < _redeemTime");
        redeemTime = _redeemTime;
    }

    function changeTargetToken(IERC20 _targetToken) onlyOwner external {
        targetToken = _targetToken;
    }

    function changeSourceTokenAmmout(IERC20 _sourceToken, uint256 _sourceAmount) onlyOwner external {
        sourceAmounts[_sourceToken] = _sourceAmount;
    }
}
