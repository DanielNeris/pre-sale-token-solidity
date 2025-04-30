// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  PreSaleToken interface
/// @notice Interface for interacting with PreSaleToken contracts
interface IPreSaleToken {
    /// @dev Errors for gas-efficient reverts
    error SaleNotActive();
    error BelowMinimum();
    error AboveMaximum();
    error SoldOut();
    error AlreadyFinalized();
    error SaleNotEnded();
    error Locked();
    error EthTransferFailed();

    /// @notice Emitted once the full token supply is moved into the contract
    event TokensSeeded(address indexed seedSource, uint256 amount);
    /// @notice Emitted after constructor sets sale parameters
    event SaleInitialized(
        uint256 tokenPrice,
        uint32  saleStart,
        uint32  saleEnd,
        uint256 minPurchase,
        uint256 maxPurchase,
        uint256 totalTokens
    );
    /// @notice Emitted when ETH is received prior to purchase logic
    event ReceivedETH(address indexed buyer, uint256 amount);
    /// @notice Emitted upon each successful token purchase
    event TokensPurchased(address indexed buyer, uint256 ethSpent, uint256 tokensBought);
    /// @notice Emitted once the sale is finalized
    event SaleFinalized(uint256 totalRaised, uint256 tokensSold);

    /// @notice Price per smallest token unit, in wei
    function tokenPrice() external view returns (uint256);
    /// @notice Minimum ETH per purchase, in wei
    function minPurchase() external view returns (uint256);
    /// @notice Maximum ETH per purchase, in wei
    function maxPurchase() external view returns (uint256);
    /// @notice Sale start timestamp (inclusive)
    function saleStart() external view returns (uint32);
    /// @notice Sale end timestamp (inclusive)
    function saleEnd() external view returns (uint32);

    /// @notice Total ETH raised, in wei
    function totalRaised() external view returns (uint256);
    /// @notice Indicates whether finalizeSale has been called
    function finalized() external view returns (bool);

    /// @notice Purchase tokens at the fixed price (payable)
    function buyTokens() external payable;
    /// @notice Finalize sale, unlock transfers, and forward ETH to owner
    function finalizeSale() external;

    /// @notice Lock token transfers until after finalizeSale
    function transfer(address to, uint256 amount) external returns (bool);
    /// @notice Lock transferFrom until after finalizeSale
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /// @notice Remaining seconds in sale (0 if ended)
    function timeRemaining() external view returns (uint32);
    /// @notice Tokens still available for purchase
    function tokensAvailable() external view returns (uint256);
}
