//
//  BeaconScanner.swift
//  MapMeasure
//
//  Created by Chris Gelles on 9/8/25.
//

import Foundation
import CoreBluetooth
import SwiftUI

class BeaconScanner: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var distances: [String: Double] = [:] // Beacon name -> distance
    @Published var rssi: [String: Int] = [:] // Beacon name -> RSSI
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var targetBeaconNames = ["14-jazzyWombat", "15-frostyIbis", "16-emberMarmot", "17-thornyPangolin"]
    private var discoveredDevices: [String] = []
    private var slot0Readings: [Int] = [] // RSSI readings from Slot 0 (iBeacon)
    private var slot1Readings: [Int] = [] // RSSI readings from Slot 1 (UID)
    
    // MARK: - Calibration Constants (Based on user's real data - EXACT MATCH to BeaconMadness)
    private let calibratedRSSIAt1Meter: Double = -80.0 // User's actual reading at 1m
    private let beaconTXPower: Int = -12 // User's beacon TX power setting
    private let maxReadingsToKeep = 10 // Keep last 10 readings for averaging
    
    // MARK: - Outlier Rejection (EXACT MATCH to BeaconMadness)
    private var lastValidRSSI: Int = 0
    private let maxRSSIChange: Int = 25 // Maximum allowed RSSI change between readings
    private let minReadingsForOutlierDetection = 2 // Need at least 2 readings to detect outliers
    
    // MARK: - Distance Smoothing (EXACT MATCH to BeaconMadness)
    private var lastDistance: Double = 0.0
    private var smoothingFactor: Double = 0.7 // Higher = more stable, less responsive
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Initialize beacon data structures
        for beaconName in targetBeaconNames {
            distances[beaconName] = 0.0
            rssi[beaconName] = 0
        }
    }
    
    // MARK: - Public Methods
    func start() {
        guard centralManager.state == .poweredOn else {
            print("❌ Bluetooth is not powered on. State: \(centralManager.state.rawValue)")
            return
        }
        
        discoveredDevices.removeAll()
        slot0Readings.removeAll()
        slot1Readings.removeAll()
        lastDistance = 0.0 // Reset smoothing
        lastValidRSSI = 0 // Reset outlier detection
        
        // Reset all beacon data
        for beaconName in targetBeaconNames {
            distances[beaconName] = 0.0
            rssi[beaconName] = 0
        }
        
        print("🔍 Starting beacon scan for \(targetBeaconNames.count) beacons")
        print("📡 Calibrated for: TX Power = \(beaconTXPower) dBm, RSSI at 1m = \(calibratedRSSIAt1Meter) dBm")
        
        // Scan for all devices and filter by name
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
    }
    
    func stop() {
        centralManager.stopScan()
        print("🛑 Stopped beacon scanning")
    }
    
    // MARK: - Outlier Detection and Rejection (EXACT MATCH to BeaconMadness)
    private func isRSSIOutlier(_ newRSSI: Int) -> Bool {
        // If we don't have enough readings yet, accept the RSSI
        if slot0Readings.count < minReadingsForOutlierDetection {
            return false
        }
        
        // If this is the first valid RSSI, accept it
        if lastValidRSSI == 0 {
            return false
        }
        
        // Check if the RSSI change is too dramatic
        let rssiChange = abs(newRSSI - lastValidRSSI)
        if rssiChange > maxRSSIChange {
            print("🚫 RSSI outlier rejected: \(newRSSI) (change: \(rssiChange)dBm from \(lastValidRSSI))")
            return true
        }
        
        // Check if RSSI is within reasonable bounds for the environment
        let expectedRange = -110...(-20) // More permissive RSSI range for indoor BLE
        if !expectedRange.contains(newRSSI) {
            print("🚫 RSSI out of range rejected: \(newRSSI)")
            return true
        }
        
        return false
    }
    
    // MARK: - Calibrated Distance Calculation (EXACT MATCH to BeaconMadness)
    private func calculateDistance(rssi: Int, txPower: Int, slotType: String) -> Double {
        if rssi == 0 {
            return -1.0
        }
        
        let measuredRSSI = Double(rssi)
        
        // Different calculation methods based on slot type
        switch slotType {
        case "Slot 0 (iBeacon)":
            return calculateDistanceForSlot0(rssi: measuredRSSI)
        case "Slot 1 (UID)":
            return calculateDistanceForSlot1(rssi: measuredRSSI)
        default:
            return calculateDistanceForSlot0(rssi: measuredRSSI) // Default to Slot 0 method
        }
    }
    
    // MARK: - Slot-Specific Distance Calculations (EXACT MATCH to BeaconMadness)
    private func calculateDistanceForSlot0(rssi: Double) -> Double {
        // Calibrated formula for Slot 0 (iBeacon, -12 dBm)
        // Using user's real data: RSSI -80 dBm at 1 meter
        
        // More stable distance calculation with less sensitivity to RSSI changes
        let rssiDifference = calibratedRSSIAt1Meter - rssi
        
        // For every 10 dBm difference, distance doubles/halves (less sensitive than 6 dBm)
        // -80 dBm = 1.0m, -70 dBm = 0.5m, -90 dBm = 2.0m
        
        // ADJUSTMENT: Increase base distance to compensate for underestimation
        // Based on user's data: RSSI -79 = 0.80m, should be closer to 1.0m
        let baseDistance = 1.25 // Increased from 1.0 to compensate for underestimation
        
        let distanceMultiplier = pow(2.0, rssiDifference / 10.0)
        let calculatedDistance = baseDistance * distanceMultiplier
        
        // Apply smoothing to reduce jumping
        let smoothedDistance = smoothDistance(calculatedDistance)
        
        // Ensure reasonable bounds (0.1m to 20m)
        let clampedDistance = max(0.1, min(20.0, smoothedDistance))
        
        print("📏 Slot 0 Distance: RSSI=\(rssi)dBm, Diff=\(rssiDifference)dBm, Raw=\(calculatedDistance)m, Smoothed=\(clampedDistance)m")
        
        return clampedDistance
    }
    
    private func calculateDistanceForSlot1(rssi: Double) -> Double {
        // Calibrated formula for Slot 1 (UID, 0 dBm)
        // Adjust for different TX power: 0 dBm vs -12 dBm = +12 dBm difference
        
        let adjustedRSSI = rssi - 12.0 // Compensate for higher TX power
        return calculateDistanceForSlot0(rssi: adjustedRSSI)
    }
    
    // MARK: - Distance Smoothing (EXACT MATCH to BeaconMadness)
    private func smoothDistance(_ newDistance: Double) -> Double {
        if lastDistance == 0.0 {
            lastDistance = newDistance
            return newDistance
        }
        
        // Apply exponential smoothing to reduce jumping
        let smoothed = (smoothingFactor * lastDistance) + ((1.0 - smoothingFactor) * newDistance)
        lastDistance = smoothed
        return smoothed
    }
    
    // MARK: - Slot Detection (EXACT MATCH to BeaconMadness)
    private func detectSlotType(advertisementData: [String : Any]) -> String {
        // Check for iBeacon format (Slot 0)
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            if manufacturerData.count >= 23 {
                let companyId = manufacturerData.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self) }
                if companyId == 0x004C { // Apple's company ID
                    return "Slot 0 (iBeacon)"
                }
            }
        }
        
        // Check for Eddystone UID format (Slot 1)
        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            for (uuid, data) in serviceData {
                if uuid.uuidString.hasPrefix("FEAA") && data.count >= 20 {
                    let frameType = data[0]
                    if frameType == 0x00 { // UID frame
                        return "Slot 1 (UID)"
                    }
                }
            }
        }
        
        return "Unknown Slot"
    }
}

// MARK: - CBCentralManagerDelegate
extension BeaconScanner: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                print("✅ Bluetooth is powered on - starting scan")
                self.start()
            case .poweredOff:
                print("❌ Bluetooth is powered off")
                self.stop()
            case .unauthorized:
                print("❌ Bluetooth permission denied")
            case .unsupported:
                print("❌ Bluetooth not supported")
            case .resetting:
                print("🔄 Bluetooth is resetting")
            case .unknown:
                print("❓ Unknown Bluetooth state")
            @unknown default:
                print("❓ Unknown Bluetooth state")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // Log all discovered devices for debugging
        let deviceName = peripheral.name ?? "Unknown"
        let deviceId = peripheral.identifier.uuidString
        
        if !discoveredDevices.contains(deviceName) {
            discoveredDevices.append(deviceName)
            print("📱 Discovered device: \(deviceName) (ID: \(deviceId)) RSSI: \(RSSI)")
        }
        
        // Check if this is our target beacon - try multiple name formats
        _ = checkIfTargetBeacon(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    
    // MARK: - Beacon Detection Logic (EXACT MATCH to BeaconMadness)
    private func checkIfTargetBeacon(peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) -> Bool {
        guard let name = peripheral.name else { return false }
        
        // Check if this is any of our target beacons
        for targetName in targetBeaconNames {
            // Method 1: Check exact name match
            if name == targetName {
                print("🎯 FOUND TARGET BEACON by exact name: \(name) RSSI: \(rssi)")
                processBeaconData(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi, detectionMethod: "Exact name", beaconName: targetName)
                return true
            }
            
            // Method 2: Check for partial name match (in case of truncated names)
            if name.contains(targetName) {
                print("🎯 FOUND TARGET BEACON by partial name: \(name) RSSI: \(rssi)")
                processBeaconData(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi, detectionMethod: "Partial name", beaconName: targetName)
                return true
            }
        }
        
        // Method 3: Check for any device with keywords in the name
        if name.contains("jazzyWombat") || name.contains("frostyIbis") || name.contains("emberMarmot") || name.contains("thornyPangolin") {
            print("🎯 FOUND TARGET BEACON by keyword: \(name) RSSI: \(rssi)")
            // Determine which beacon this is based on the keyword
            let beaconName: String
            if name.contains("jazzyWombat") {
                beaconName = "14-jazzyWombat"
            } else if name.contains("frostyIbis") {
                beaconName = "15-frostyIbis"
            } else if name.contains("emberMarmot") {
                beaconName = "16-emberMarmot"
            } else {
                beaconName = "17-thornyPangolin"
            }
            processBeaconData(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi, detectionMethod: "Keyword search", beaconName: beaconName)
            return true
        }
        
        return false
    }
    
    private func processBeaconData(peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber, detectionMethod: String, beaconName: String) {
        print("📊 Processing beacon data - Method: \(detectionMethod)")
        
        // Detect which slot this signal is from
        let slotType = detectSlotType(advertisementData: advertisementData)
        print("🎯 Detected slot type: \(slotType)")
        
        // Store RSSI reading based on slot type
        let rssiValue = rssi.intValue
        
        // Apply outlier rejection for Slot 0 (primary distance calculation)
        // TEMPORARILY: Force all readings through as Slot 0 for debugging
        if slotType == "Slot 0 (iBeacon)" || true {
            if isRSSIOutlier(rssiValue) {
                print("🚫 RSSI \(rssiValue) would be rejected as outlier, but allowing through for debugging")
                // TEMPORARILY DISABLED: return // Skip this reading
            }
            
            // RSSI passed outlier detection - store it
            slot0Readings.append(rssiValue)
            if slot0Readings.count > maxReadingsToKeep {
                slot0Readings.removeFirst()
            }
            
            // Update last valid RSSI for future outlier detection
            lastValidRSSI = rssiValue
        } else if slotType == "Slot 1 (UID)" {
            slot1Readings.append(rssiValue)
            if slot1Readings.count > maxReadingsToKeep {
                slot1Readings.removeFirst()
            }
        }
        
        // Use Slot 0 readings for primary distance calculation (iBeacon format)
        guard !slot0Readings.isEmpty else { 
            print("⚠️ slot0Readings is empty, returning early")
            return 
        }
        
        let primaryRSSI = slot0Readings.last!
        let primarySlotType = "Slot 0 (iBeacon)"
        
        // Calculate distance using calibrated formula
        let calculatedDistance = calculateDistance(rssi: primaryRSSI, txPower: beaconTXPower, slotType: primarySlotType)
        
        // Update published properties for the specific beacon
        DispatchQueue.main.async {
            self.rssi[beaconName] = primaryRSSI
            self.distances[beaconName] = calculatedDistance
            
            print("🎯 \(beaconName) - \(primarySlotType) - Distance: \(String(format: "%.2f", calculatedDistance))m - RSSI: \(primaryRSSI)dBm")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 Disconnected from peripheral")
        
        // Find which beacon this was and mark it as disconnected
        if let name = peripheral.name {
            for beaconName in self.targetBeaconNames {
                if name.contains(beaconName) || beaconName.contains(name) {
                    DispatchQueue.main.async {
                        self.distances[beaconName] = 0.0
                        self.rssi[beaconName] = 0
                    }
                    break
                }
            }
        }
        
        // Restart scanning after disconnection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.start()
        }
    }
}