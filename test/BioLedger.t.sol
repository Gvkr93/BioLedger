// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BioLedger} from "../src/BioLedger.sol";

contract BioLedgerTest is Test {
    BioLedger public bioLedger;
    
    // Mock addresses for simulation
    address admin = address(1);
    address hospital = address(2);
    address transporter = address(3);
    address disposal = address(4);

    function setUp() public {
        // Deploy contract as admin
        vm.prank(admin);
        bioLedger = new BioLedger(admin);

        // Grant roles
        vm.startPrank(admin);
        bioLedger.grantRole(bioLedger.HOSPITAL_ROLE(), hospital);
        bioLedger.grantRole(bioLedger.TRANSPORTER_ROLE(), transporter);
        bioLedger.grantRole(bioLedger.DISPOSAL_FACILITY_ROLE(), disposal);
        vm.stopPrank();
    }

    function testRegisterWaste() public {
        vm.prank(hospital);
        uint256 bagId = bioLedger.registerWaste(1000, "QmTestHash123");
        
        BioLedger.WasteBag memory bag = bioLedger.getWasteBag(bagId);
        assertEq(bag.initialWeight, 1000);
        assertEq(bag.ipfsHash, "QmTestHash123");
        assertEq(uint(bag.status), uint(BioLedger.WasteStatus.GENERATED));
    }

    function testLifecycleAndDiscrepancy() public {
        // 1. Hospital registers
        vm.prank(hospital);
        uint256 bagId = bioLedger.registerWaste(1000, "QmTestHash123");

        // 2. Transporter picks it up
        vm.prank(transporter);
        bioLedger.transferCustody(bagId);
        
        BioLedger.WasteBag memory bagTransit = bioLedger.getWasteBag(bagId);
        assertEq(uint(bagTransit.status), uint(BioLedger.WasteStatus.IN_TRANSIT));

        // 3. Disposal facility confirms (simulating a 10% weight loss - triggers flag)
        vm.prank(disposal);
        bioLedger.confirmDisposal(bagId, 900); 

        BioLedger.WasteBag memory bagDisposed = bioLedger.getWasteBag(bagId);
        assertEq(uint(bagDisposed.status), uint(BioLedger.WasteStatus.DISPOSED));
        assertTrue(bagDisposed.isDiscrepancyFlagged); // 100g diff > 50g tolerance
    }
}