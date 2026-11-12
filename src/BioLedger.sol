// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract BioLedger is AccessControl {
    bytes32 public constant HOSPITAL_ROLE = keccak256("HOSPITAL_ROLE");
    bytes32 public constant TRANSPORTER_ROLE = keccak256("TRANSPORTER_ROLE");
    bytes32 public constant DISPOSAL_FACILITY_ROLE = keccak256("DISPOSAL_FACILITY_ROLE");

    enum WasteStatus { GENERATED, IN_TRANSIT, DISPOSED }

    struct WasteBag {
        uint256 bagId;
        address hospital;
        address transporter;
        address disposalFacility;
        uint256 initialWeight;
        uint256 finalWeight;
        string ipfsHash;
        WasteStatus status;
        bool isDiscrepancyFlagged;
    }

    uint256 public weightTolerancePercent = 5;
    uint256 private _bagIdCounter;
    mapping(uint256 => WasteBag) private _wasteBags;

    error InvalidWeight();
    error EmptyIPFSHash();
    error BagDoesNotExist(uint256 bagId);
    error InvalidStateTransition(uint256 bagId, WasteStatus currentStatus);

    event WasteRegistered(uint256 indexed bagId, address indexed hospital, uint256 initialWeight, string ipfsHash);
    event CustodyTransferred(uint256 indexed bagId, address indexed transporter);
    event WasteDisposed(uint256 indexed bagId, address indexed disposalFacility, uint256 finalWeight);
    event DiscrepancyFlagged(uint256 indexed bagId, uint256 initialWeight, uint256 finalWeight);

    constructor(address defaultAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    function registerWaste(uint256 weightInitial, string calldata ipfsHash) external onlyRole(HOSPITAL_ROLE) returns (uint256) {
        if (weightInitial == 0) revert InvalidWeight();
        if (bytes(ipfsHash).length == 0) revert EmptyIPFSHash();

        _bagIdCounter++;
        uint256 currentId = _bagIdCounter;

        _wasteBags[currentId] = WasteBag({
            bagId: currentId,
            hospital: msg.sender,
            transporter: address(0),
            disposalFacility: address(0),
            initialWeight: weightInitial,
            finalWeight: 0,
            ipfsHash: ipfsHash,
            status: WasteStatus.GENERATED,
            isDiscrepancyFlagged: false
        });

        emit WasteRegistered(currentId, msg.sender, weightInitial, ipfsHash);
        return currentId;
    }

    function transferCustody(uint256 bagId) external onlyRole(TRANSPORTER_ROLE) {
        WasteBag storage bag = _wasteBags[bagId];
        if (bag.bagId == 0) revert BagDoesNotExist(bagId);
        if (bag.status != WasteStatus.GENERATED) revert InvalidStateTransition(bagId, bag.status);

        bag.transporter = msg.sender;
        bag.status = WasteStatus.IN_TRANSIT;
        emit CustodyTransferred(bagId, msg.sender);
    }

    function confirmDisposal(uint256 bagId, uint256 weightFinal) external onlyRole(DISPOSAL_FACILITY_ROLE) {
        WasteBag storage bag = _wasteBags[bagId];
        if (bag.bagId == 0) revert BagDoesNotExist(bagId);
        if (bag.status != WasteStatus.IN_TRANSIT) revert InvalidStateTransition(bagId, bag.status);
        if (weightFinal == 0) revert InvalidWeight();

        bag.disposalFacility = msg.sender;
        bag.finalWeight = weightFinal;
        bag.status = WasteStatus.DISPOSED;

        uint256 weightDifference = bag.initialWeight > weightFinal ? bag.initialWeight - weightFinal : weightFinal - bag.initialWeight;
        uint256 allowableDeviation = (bag.initialWeight * weightTolerancePercent) / 100;

        if (weightDifference > allowableDeviation) {
            bag.isDiscrepancyFlagged = true;
            emit DiscrepancyFlagged(bagId, bag.initialWeight, weightFinal);
        }

        emit WasteDisposed(bagId, msg.sender, weightFinal);
    }

    function getWasteBag(uint256 bagId) external view returns (WasteBag memory) {
        return _wasteBags[bagId];
    }
}