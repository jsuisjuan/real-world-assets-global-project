// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.25;

import { Script } from 'forge-std/Script.sol';
import { dTSLA } from '../src/dTSLA.sol';
import { console2 } from 'forge-std/console2.sol';

contract DeployDTsla is Script {
    string constant alpacaMintSource = './functions/sources/alpacaBalance.js';
    string constant alpacaRedeemSource = '';
    uint64 constant subId = 2287; // precisa fazer a configuração da ui com chainlink

    function run() public {
        string memory mintSource = vm.readFile(alpacaMintSource);
        vm.startBroadcast();
        dTSLA dTsla = new dTSLA(mintSource, alpacaRedeemSource, subId);
        vm.stopBroadcast();
        console2.log(address(dTsla));
    }
}