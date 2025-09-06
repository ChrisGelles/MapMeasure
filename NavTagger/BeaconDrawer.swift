//
//  BeaconDrawer.swift
//  NavTagger
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI

struct BeaconDrawer: View {
    @ObservedObject var beaconManager: BeaconManager
    @ObservedObject var mapManager: MapManager
    let geometry: GeometryProxy
    
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Beacon Grid
            if beaconManager.availableBeacons.isEmpty {
                Text("No beacons found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(beaconManager.availableBeacons, id: \.name) { beacon in
                        BeaconButton(
                            beacon: beacon,
                            isArmed: beaconManager.armedBeacon?.name == beacon.name,
                            isPlaced: beaconManager.placedBeacons.contains { $0.name == beacon.name },
                            action: {
                                if beaconManager.armedBeacon?.name == beacon.name {
                                    beaconManager.cancelArmedBeacon()
                                } else {
                                    beaconManager.armBeacon(beacon)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
        .frame(maxHeight: geometry.size.height * 0.2)
    }
}

struct BeaconButton: View {
    let beacon: BeaconInfo
    let isArmed: Bool
    let isPlaced: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Beacon Icon
                ZStack {
                    Circle()
                        .fill(beacon.color)
                        .frame(width: 28, height: 28)
                    
                    if isPlaced {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "target")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                // Beacon Name
                Text(beacon.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Status Indicator
                if isArmed {
                    Text("Ready")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor)
                        )
                } else if isPlaced {
                    Text("Placed")
                        .font(.caption2)
                        .foregroundColor(beacon.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(beacon.color.opacity(0.1))
                        )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isArmed ? beacon.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isArmed ? beacon.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PlacedBeaconChip: View {
    let beacon: PlacedBeacon
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(beacon.color)
                .frame(width: 8, height: 8)
            
            Text(beacon.name)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
        )
    }
}

#Preview {
    GeometryReader { geometry in
        BeaconDrawer(
            beaconManager: BeaconManager(),
            mapManager: MapManager(),
            geometry: geometry
        )
    }
    .frame(width: 400, height: 600)
}
