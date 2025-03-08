// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IChainlinkOracle.sol";

contract PriceOracle is IOracle, Ownable {
    mapping(address => address) public priceFeeds;  // token => chainlink feed
    
    event PriceFeedSet(address token, address feed);

    function setFeed(address token, address feed) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(feed != address(0), "Invalid feed");
        priceFeeds[token] = feed;
        emit PriceFeedSet(token, feed);
    }

    function getPrice(address token) external view override returns (uint256) {
        address feed = priceFeeds[token];
        require(feed != address(0), "No price feed");
        
        (
            ,
            int256 price,
            ,
            uint256 updatedAt,
            
        ) = IChainlinkOracle(feed).latestRoundData();
        
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= 24 hours, "Stale price");
        
        return uint256(price);
    }
} 