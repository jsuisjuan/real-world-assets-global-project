// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
* @title HelperConfig
* @notice This contract is used to manage network configurations for different blockchain networks.
* It initializes and retrieves configurations based on the chain ID.
*/
contract HelperConfig {
    struct NetworkConfig {
        address tslaPriceFeed;
        address usdcPriceFeed;
        address functionsRouter;
        bytes32 donId;
        uint64 subId;
        address redemptionCoin;
        uint64 secretVersion;
        uint8 secretSlot;
    }

    NetworkConfig public activeNetworkConfig;
    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    /**
    * @notice Constructor that initializes configurations and sets the active network configuration.
    */
    constructor() {
        initializeConfigurations();
        activeNetworkConfig = getActiveNetworkConfig();
    }

    /**
    * @notice Initializes configurations for supported networks.
    */
    function initializeConfigurations() internal {
        chainIdToNetworkConfig[11155111] = getSepoliaConfig();
    }

    /**
    * @notice Retrieves the active network configuration based on the current chain ID.
    * @return config The active NetworkConfig.
    */
    function getActiveNetworkConfig() internal view returns (NetworkConfig memory) {
        NetworkConfig memory config = chainIdToNetworkConfig[block.chainid];
        require(config.functionsRouter != address(0), 'HelperConfig :: getActiveNetworkConfig() :: Network configuration not found');
        return config;
    }

    /**
    * @notice Returns the network configuration for the Sepolia testnet.
    * @return config The NetworkConfig for Sepolia.
    */
    function getSepoliaConfig() internal pure returns (NetworkConfig memory config) {
        return NetworkConfig({
            tslaPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
            usdcPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            functionsRouter: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0,
            donId: 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000,
            subId: 3223,
            redemptionCoin: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            secretVersion: 1721861128,
            secretSlot: 0
        });
    }

    /**
    * @notice Adds a new network configuration for a specific chain ID.
    * @param chainId The chain ID of the network.
    * @param config The NetworkConfig for the network.
    */
    function addNetworkConfig(uint256 chainId, NetworkConfig memory config) external {
        chainIdToNetworkConfig[chainId] = config;
    }
}