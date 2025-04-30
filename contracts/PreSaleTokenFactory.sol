// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./PreSaleToken.sol";
import "./interfaces/IPreSaleTokenFactory.sol";

/// @title PreSaleTokenFactory
/// @notice Deploys and manages multiple PreSaleToken contracts.
/// @dev    Implements the IPreSaleTokenFactory interface (which defines the `PreSaleCreated` event)
contract PreSaleTokenFactory is IPreSaleTokenFactory {
    /// @notice Array of all deployed PreSaleToken addresses.
    address[] public allPreSales;

    /// @notice Deploys a new PreSaleToken contract.
    /// @dev    The factory initially owns the presale, then transfers ownership to msg.sender.
    /// @param  name_           The name for the token (e.g., "MyToken").
    /// @param  symbol_         The symbol for the token (e.g., "MTK").
    /// @param  initialSupply_  The initial total supply to mint (whole tokens, before decimals).
    /// @param  tokenPrice_     Price per token (smallest unit) in wei.
    /// @param  saleDuration_   Duration of the presale after deployment, in seconds.
    /// @param  minPurchase_    Minimum ETH required per purchase (in wei).
    /// @param  maxPurchase_    Maximum ETH allowed per purchase (in wei).
    /// @return presaleAddress  The address of the newly deployed PreSaleToken.
    function createPreSale(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        uint256 tokenPrice_,
        uint32  saleDuration_,
        uint256 minPurchase_,
        uint256 maxPurchase_
    ) external returns (address presaleAddress) {
        PreSaleToken presale = new PreSaleToken(
            name_,
            symbol_,
            initialSupply_,
            tokenPrice_,
            saleDuration_,
            minPurchase_,
            maxPurchase_
        );

        // Transfer ownership to the caller
        presale.transferOwnership(msg.sender);

        presaleAddress = address(presale);
        allPreSales.push(presaleAddress);

        // This event is declared in the interface
        emit PreSaleCreated(presaleAddress, name_, symbol_, saleDuration_);
    }

    /// @notice Returns the total number of presale contracts created.
    /// @return The count of deployed PreSaleToken contracts.
    function getPreSaleCount() external view returns (uint256) {
        return allPreSales.length;
    }

    /// @notice Retrieves the address of a presale contract by index.
    /// @param index The index in the allPreSales array.
    /// @return The address of the presale contract at the specified index.
    function getPreSale(uint256 index) external view returns (address) {
        require(index < allPreSales.length, "Factory: index out of range");
        return allPreSales[index];
    }

    /// @notice Returns all presale contract addresses.
    /// @return An array of addresses for all deployed PreSaleToken contracts.
    function getAllPreSales() external view returns (address[] memory) {
        return allPreSales;
    }
}
