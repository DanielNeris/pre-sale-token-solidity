// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyToken.sol";
import "./interfaces/IPreSaleToken.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title  PreSaleToken
/// @notice ERC-20 token that mints a fixed supply and runs a fixed-price presale
/// @dev    Implements IPreSaleToken; inherits MyToken (ERC20) and ReentrancyGuard
contract PreSaleToken is MyToken, ReentrancyGuard, IPreSaleToken {
    /// @notice Price per smallest token unit, in wei
    uint256 public immutable override tokenPrice;
    /// @notice Minimum ETH per purchase, in wei
    uint256 public immutable override minPurchase;
    /// @notice Maximum ETH per purchase, in wei
    uint256 public immutable override maxPurchase;
    /// @notice Sale start timestamp (inclusive)
    uint32  public immutable override saleStart;
    /// @notice Sale end timestamp (inclusive)
    uint32  public immutable override saleEnd;

    /// @notice Total ETH raised, in wei
    uint256 public override totalRaised;
    /// @notice Has `finalizeSale` been called?
    bool    public override finalized;
    /// @dev    Cached multiplier for 10**decimals() to save gas
    uint256 private immutable _decimalsMultiplier;

    /// @param name_           Token name
    /// @param symbol_         Token symbol
    /// @param initialSupply_  Minted to deployer (whole tokens)
    /// @param _tokenPrice     Price per smallest token unit, in wei
    /// @param _saleDuration   Duration of sale, in seconds
    /// @param _minPurchase    Minimum ETH per buy, in wei
    /// @param _maxPurchase    Maximum ETH per buy, in wei
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        uint256 _tokenPrice,
        uint32  _saleDuration,
        uint256 _minPurchase,
        uint256 _maxPurchase
    )
        MyToken(name_, symbol_, initialSupply_)
        ReentrancyGuard()
    {
        require(_saleDuration > 0, "duration>0");
        require(_minPurchase > 0, "min>0");
        require(_maxPurchase >= _minPurchase, "max>=min");

        // Seed full supply into this contract
        uint256 supply = totalSupply();
        _transfer(_msgSender(), address(this), supply);

        // Cache multiplier & init sale params
        _decimalsMultiplier = 10 ** decimals();
        tokenPrice        = _tokenPrice;
        minPurchase       = _minPurchase;
        maxPurchase       = _maxPurchase;
        saleStart         = uint32(block.timestamp);
        saleEnd           = saleStart + _saleDuration;

        emit TokensSeeded(_msgSender(), supply);
        emit SaleInitialized(_tokenPrice, saleStart, saleEnd, _minPurchase, _maxPurchase, supply);
    }

    /// @notice Purchase tokens at the fixed price during the sale window
    function buyTokens() public payable override nonReentrant {
        if (block.timestamp < saleStart || block.timestamp > saleEnd || finalized) revert SaleNotActive();
        if (msg.value < minPurchase) revert BelowMinimum();
        if (msg.value > maxPurchase) revert AboveMaximum();

        uint256 amount = (msg.value * _decimalsMultiplier) / tokenPrice;
        if (balanceOf(address(this)) < amount) revert SoldOut();

        totalRaised += msg.value;
        emit ReceivedETH(_msgSender(), msg.value);

        _transfer(address(this), _msgSender(), amount);
        emit TokensPurchased(_msgSender(), msg.value, amount);
    }

    /// @notice Finalize sale, unlock transfers, and forward ETH to owner
    function finalizeSale() external override onlyOwner {
        if (finalized) revert AlreadyFinalized();
        if (block.timestamp <= saleEnd) revert SaleNotEnded();

        finalized = true;
        uint256 sold = totalSupply() - balanceOf(address(this));

        (bool ok, ) = payable(owner()).call{ value: address(this).balance }("");
        if (!ok) revert EthTransferFailed();

        emit SaleFinalized(totalRaised, sold);
    }

    /// @notice Lock token transfers until after `finalizeSale`
    function transfer(address to, uint256 amount)
        public
        override(ERC20, IPreSaleToken)
        returns (bool)    {
        if (!finalized && _msgSender() != owner() && _msgSender() != address(this)) revert Locked();
        return super.transfer(to, amount);
    }
    /// @notice Lock `transferFrom` until after `finalizeSale`
    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20, IPreSaleToken)
        returns (bool)    {
        if (!finalized && from != address(this)) revert Locked();
        return super.transferFrom(from, to, amount);
    }

    /// @notice Remaining seconds in sale (0 if ended)
    function timeRemaining() external view override returns (uint32) {
        return block.timestamp >= saleEnd ? 0 : saleEnd - uint32(block.timestamp);
    }

    /// @notice Tokens still available for purchase
    function tokensAvailable() external view override returns (uint256) {
        return balanceOf(address(this));
    }

    /// @notice Fallback to allow direct ETH → `buyTokens()`
    receive() external payable {
        buyTokens();
    }
}
