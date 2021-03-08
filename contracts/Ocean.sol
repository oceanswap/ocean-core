pragma solidity ^0.6.0;

import './owner/Operator.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Capped.sol';


contract Ocean is ERC20Burnable, ERC20Capped, Operator {
    constructor() public ERC20('ODT', 'ODT') ERC20Capped(1000000000* 10**18) {
        // Mints 1 Basis Share to contract creator for initial Uniswap oracle deployment.
        // Will be burned after oracle deployment
        //_mint(msg.sender, 10 * 10**18);
    }

    /**
     * @notice Operator mints basis cash to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of basis cash to mint to
     */
    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        super.burnFrom(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20Capped,ERC20) {
        ERC20Capped._beforeTokenTransfer(from, to, amount);
    }
}
