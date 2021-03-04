pragma solidity ^0.6.0;

library  MdexLibrary {

    function pairFor(
        address factory,
        address tokenA,
        address tokenB)
    internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                address(factory),
                keccak256(abi.encodePacked(token0, token1)),
                hex'2ad889f82040abccb2649ea6a874796c1601fb67f91a747a80e08860c73ddf24'
            ))));
        return pair;
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'MdexSwapFactory: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MdexSwapFactory: ZERO_ADDRESS');
    }

}
