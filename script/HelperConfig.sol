// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import { console } from "forge-std/console.sol";
contract HelperConfig {
    struct NetworkConfig {
        address tslaPriceFeed;
        address usdcPriceFeed;
        address ethUsdPriceFeed;
        address functionsRouter;
        bytes32 donId;
        uint64 subId;
        address redemptionCoin;
        address linkToken;
        uint64 secretVersion;
        uint8 secretSlot;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[11155111] = getSepoliaConfig();
        activeNetworkConfig = chainIdToNetworkConfig[11155111];
    }

    function getSepoliaConfig() internal pure returns (NetworkConfig memory config) {
        config = NetworkConfig({
            tslaPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
            usdcPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            functionsRouter: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0,
            donId: 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000,
            subId: 2274,
            redemptionCoin: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            secretVersion: 1721067443,
            secretSlot: 0
        });
    }
}