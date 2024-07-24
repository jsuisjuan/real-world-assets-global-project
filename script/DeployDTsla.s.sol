// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from 'forge-std/Script.sol';
import { HelperConfig } from './HelperConfig.sol';
import { dTSLA } from '../src/dTSLA.sol';
import { IGetTslaReturnTypes } from '../src/interfaces/IGetTslaReturnTypes.sol';

/**
* @title DeployDTsla
* @notice This contract is used to deploy the dTSLA contract with necessary configurations.
*/
contract DeployDTsla is Script {
    string constant alpacaMintSource = './functions/sources/alpacaBalance.js';
    string constant alpacaRedeemSource = './functions/sources/sellTslaAndSendUsdc.js';

    /**
    * @notice Main function to run the deployment script.
    */
    function run() external {
        IGetTslaReturnTypes.GetTslaReturnType memory tslaReturnType = getdTslaRequirements();
        deployTransactions(tslaReturnType);
    }

    /**
    * @notice Retrieves the required parameters for deploying the dTSLA contract.
    * @return The structure containing all the necessary parameters for deployment.
    */
    function getdTslaRequirements() public returns (IGetTslaReturnTypes.GetTslaReturnType memory) {
        HelperConfig helperConfig = new HelperConfig();
        (address tslaFeed, address usdcFeed, address functionsRouter, bytes32 donId, uint64 subId, address redemptionCoin, uint64 secretVersion, uint8 secretSlot) = helperConfig.activeNetworkConfig();
        verifyEmptyAttributes(tslaFeed, usdcFeed, functionsRouter, donId, subId);
        (string memory mintSource, string memory redeemSource) = readSourceFiles();
        return IGetTslaReturnTypes.GetTslaReturnType(subId, mintSource, redeemSource, functionsRouter, donId, tslaFeed, usdcFeed, redemptionCoin, secretVersion, secretSlot);
    }

    /**
    * @notice Verifies that none of the required attributes are empty.
    * @param tslaFeed The address of the TSLA price feed.
    * @param usdcFeed The address of the USDC price feed.
    * @param functionsRouter The address of the functions router.
    * @param donId The ID of the Decentralized Oracle Network.
    * @param subId The subscription ID.
    */
    function verifyEmptyAttributes(address tslaFeed, address usdcFeed, address functionsRouter, bytes32 donId, uint64 subId) public pure {
        if (tslaFeed == address(0) || usdcFeed == address(0) || functionsRouter == address(0) || donId == bytes32(0) || subId == 0) {
            revert('DeployDTsla :: verifyEmptyAttributes() :: there is empty attributes');
        }
    }

    /**
    * @notice Reads the source files for minting and redeeming operations.
    * @return mintSource The source code for minting operations.
    * @return redeemSource The source code for redeeming operations.
    */
    function readSourceFiles() internal view returns (string memory mintSource, string memory redeemSource) {
        mintSource = vm.readFile(alpacaMintSource);
        redeemSource = vm.readFile(alpacaRedeemSource);
    }

    /**
    * @notice Deploys the dTSLA contract with the provided parameters.
    * @param tslaReturnType The structure containing all the necessary parameters for deployment.
    */
    function deployTransactions(IGetTslaReturnTypes.GetTslaReturnType memory tslaReturnType) public {
        vm.startBroadcast();
        deployDTSLA(tslaReturnType.subId, tslaReturnType.mintSource, tslaReturnType.redeemSource, tslaReturnType.functionsRouter, tslaReturnType.donId, tslaReturnType.tslaFeed, tslaReturnType.usdcFeed, tslaReturnType.redemptionCoin, tslaReturnType.secretVersion, tslaReturnType.secretSlot); 
        vm.stopBroadcast();
    }

    /**
    * @notice Deploys the dTSLA contract.
    * @param subId The subscription ID.
    * @param mintSource The source code for minting operations.
    * @param redeemSource The source code for redeeming operations.
    * @param functionsRouter The address of the functions router.
    * @param donId The ID of the Decentralized Oracle Network.
    * @param tslaFeed The address of the TSLA price feed.
    * @param usdcFeed The address of the USDC price feed.
    * @param redemptionCoin The address of the redemption coin.
    * @param secretVersion The version of the secret.
    * @param secretSlot The slot of the secret.
    * @return dTsla The deployed dTSLA contract.
    */
    function deployDTSLA(uint64 subId, string memory mintSource, string memory redeemSource, address functionsRouter, bytes32 donId, address tslaFeed, address usdcFeed, address redemptionCoin, uint64 secretVersion, uint8 secretSlot) public returns (dTSLA) {
        dTSLA dTsla = new dTSLA(subId, mintSource, redeemSource, functionsRouter, donId, tslaFeed, usdcFeed, redemptionCoin, secretVersion, secretSlot);
        return dTsla;
    }
}