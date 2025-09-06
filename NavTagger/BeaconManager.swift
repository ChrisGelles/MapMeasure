//
//  BeaconManager.swift
//  NavTagger
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI
import Foundation

// MARK: - Data Models
struct BeaconInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    
    static func == (lhs: BeaconInfo, rhs: BeaconInfo) -> Bool {
        lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct PlacedBeacon: Identifiable {
    let id = UUID()
    let name: String
    let position: CGPoint // Normalized coordinates (0-1)
    let color: Color
}

// MARK: - Beacon Manager
class BeaconManager: ObservableObject {
    @Published var availableBeacons: [BeaconInfo] = []
    @Published var placedBeacons: [PlacedBeacon] = []
    @Published var armedBeacon: BeaconInfo? = nil
    
    private let colorPalette: [Color] = [
        .red, .blue, .green, .orange, .purple, .pink, .yellow, .cyan,
        .mint, .indigo, .brown, .gray, .teal, .primary, .secondary
    ]
    
    private let persistenceKey = "placedBeacons"
    
    init() {
        loadPlacedBeacons()
    }
    
    // MARK: - Whitelist Loading
    func loadBeaconWhitelist() {
        guard let url = Bundle.main.url(forResource: "beacon_whitelist", withExtension: "txt") else {
            print("Beacon whitelist file not found")
            return
        }
        
        do {
            let content = try String(contentsOf: url)
            let lines = content.components(separatedBy: .newlines)
            
            var beacons: [BeaconInfo] = []
            var colorIndex = 0
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip empty lines and comments
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }
                
                let color = colorPalette[colorIndex % colorPalette.count]
                beacons.append(BeaconInfo(name: trimmed, color: color))
                colorIndex += 1
            }
            
            DispatchQueue.main.async {
                self.availableBeacons = beacons
                self.cleanupInvalidPlacements()
            }
            
        } catch {
            print("Error loading beacon whitelist: \(error)")
        }
    }
    
    // MARK: - Beacon Placement
    func armBeacon(_ beacon: BeaconInfo) {
        armedBeacon = beacon
    }
    
    func cancelArmedBeacon() {
        armedBeacon = nil
    }
    
    func placeBeacon(_ beacon: BeaconInfo, at position: CGPoint) {
        // Remove any existing placement for this beacon
        placedBeacons.removeAll { $0.name == beacon.name }
        
        // Add new placement
        let placedBeacon = PlacedBeacon(
            name: beacon.name,
            position: position,
            color: beacon.color
        )
        placedBeacons.append(placedBeacon)
        
        // Clear armed state
        armedBeacon = nil
        
        // Save to persistence
        savePlacedBeacons()
    }
    
    // MARK: - Persistence
    private func savePlacedBeacons() {
        let data = placedBeacons.map { beacon in
            [
                "name": beacon.name,
                "x": beacon.position.x,
                "y": beacon.position.y,
                "colorRed": UIColor(beacon.color).red,
                "colorGreen": UIColor(beacon.color).green,
                "colorBlue": UIColor(beacon.color).blue,
                "colorAlpha": UIColor(beacon.color).alpha
            ]
        }
        
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
    
    private func loadPlacedBeacons() {
        // Clear all placed beacons for now
        placedBeacons = []
        print("Cleared all placed beacons.")
    }
    
    func clearAllPlacements() {
        placedBeacons = []
        savePlacedBeacons()
        print("Cleared all beacon placements.")
    }
    
    private func cleanupInvalidPlacements() {
        let validNames = Set(availableBeacons.map { $0.name })
        placedBeacons.removeAll { !validNames.contains($0.name) }
        savePlacedBeacons()
    }
}

// MARK: - Color Extension
extension UIColor {
    var red: CGFloat {
        var red: CGFloat = 0
        getRed(&red, green: nil, blue: nil, alpha: nil)
        return red
    }
    
    var green: CGFloat {
        var green: CGFloat = 0
        getRed(nil, green: &green, blue: nil, alpha: nil)
        return green
    }
    
    var blue: CGFloat {
        var blue: CGFloat = 0
        getRed(nil, green: nil, blue: &blue, alpha: nil)
        return blue
    }
    
    var alpha: CGFloat {
        var alpha: CGFloat = 0
        getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return alpha
    }
}
