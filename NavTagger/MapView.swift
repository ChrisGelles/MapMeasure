//
//  MapView.swift
//  NavTagger
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI

struct MapView: View {
    @ObservedObject var mapManager: MapManager
    @ObservedObject var beaconManager: BeaconManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Container (can be panned and zoomed with gestures. Everything inside moves together)
                ZStack {
                    // b. Map Image
                    Image("myFirstFloor_v03-metric")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: .infinity)
                    
                    // a. Beacon dots/pins placed by user (stacked above map)
                    ForEach(beaconManager.placedBeacons, id: \.name) { beacon in
                        BeaconDot(beacon: beacon)
                    }
                }
                .scaleEffect(mapManager.scale)
                .offset(mapManager.offset)
                .clipped()
                .gesture(
                    SimultaneousGesture(
                        // Pan gesture
                        DragGesture()
                            .onChanged { value in
                                mapManager.updatePan(translation: value.translation)
                            }
                            .onEnded { _ in
                                mapManager.endPan()
                            },
                        
                        // Zoom gesture
                        MagnificationGesture()
                            .onChanged { value in
                                mapManager.updateZoom(magnification: value)
                            }
                            .onEnded { _ in
                                mapManager.endZoom()
                            }
                    )
                )
                .onTapGesture { location in
                    // Handle tap for beacon placement
                    handleMapTap(at: location, in: geometry)
                }
                
                // Armed Beacon Hint (outside the container so it doesn't move)
                if let armedBeacon = beaconManager.armedBeacon {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Text("Tap the map to place")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("'\(armedBeacon.name)'")
                                    .font(.headline)
                                    .foregroundColor(armedBeacon.color)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(armedBeacon.color.opacity(0.1))
                                    )
                                Button("Cancel") {
                                    beaconManager.cancelArmedBeacon()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 4)
                            )
                            Spacer()
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func handleMapTap(at location: CGPoint, in geometry: GeometryProxy) {
        guard let armedBeacon = beaconManager.armedBeacon else { 
            print("No armed beacon for placement")
            return 
        }
        
        print("Map tapped at: \(location)")
        
        // Convert tap location to normalized coordinates (0-1)
        // Since the container handles scaling/offsetting, we need to account for that
        let containerScale = mapManager.scale
        let containerOffset = mapManager.offset
        
        // Reverse the container transformations to get the original tap location
        let originalLocation = CGPoint(
            x: (location.x - containerOffset.width) / containerScale,
            y: (location.y - containerOffset.height) / containerScale
        )
        
        // Convert to normalized coordinates
        let normalizedLocation = CGPoint(
            x: originalLocation.x / geometry.size.width,
            y: originalLocation.y / geometry.size.height
        )
        
        print("Normalized location: \(normalizedLocation)")
        
        // Clamp to bounds
        let clampedLocation = CGPoint(
            x: max(0, min(1, normalizedLocation.x)),
            y: max(0, min(1, normalizedLocation.y))
        )
        
        print("Clamped location: \(clampedLocation)")
        
        // Place the beacon
        beaconManager.placeBeacon(armedBeacon, at: clampedLocation)
        print("Beacon placed: \(armedBeacon.name)")
    }
}

struct BeaconDot: View {
    let beacon: PlacedBeacon
    
    var body: some View {
        // Position the dot relative to the map image within the container
        // The container handles all scaling and offsetting, so we just use normalized coordinates
        Circle()
            .fill(beacon.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
        .position(
            x: beacon.position.x * UIScreen.main.bounds.width,
            y: beacon.position.y * UIScreen.main.bounds.height
        )
    }
}

#Preview {
    MapView(mapManager: MapManager(), beaconManager: BeaconManager())
}
