// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BioLedger} from "../src/BioLedger.sol";

contract DeployBioLedger is Script {
    function run() external {
        // Read private key from .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions to the testnet
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract and set the deployer as the DEFAULT_ADMIN
        address deployerAddress = vm.addr(deployerPrivateKey);
        BioLedger bioLedger = new BioLedger(deployerAddress);

        console.log("BioLedger deployed successfully at:", address(bioLedger));
        console.log("Admin role granted to:", deployerAddress);

        vm.stopBroadcast();
    }
}