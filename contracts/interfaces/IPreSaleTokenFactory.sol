// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  IPreSaleTokenFactory
/// @notice Interface for a factory that deploys PreSaleToken contracts.
interface IPreSaleTokenFactory {
    /// @notice Emitted when a new presale contract is created.
    /// @param presaleAddress The address of the deployed presale.
    /// @param name           The token name.
    /// @param symbol         The token symbol.
    /// @param saleDuration   The sale duration in seconds.
    event PreSaleCreated(
        address indexed presaleAddress,
        string name,
        string symbol,
        uint32 saleDuration
    );

    function createPreSale(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        uint256 tokenPrice_,
        uint32  saleDuration_,
        uint256 minPurchase_,
        uint256 maxPurchase_
    ) external returns (address);

    function getPreSaleCount() external view returns (uint256);
    function getPreSale(uint256 index) external view returns (address);
    function getAllPreSales() external view returns (address[] memory);
}
