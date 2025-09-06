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
                    
                    // Grid overlay for coordinate system testing
                    Image("blackGrid")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: .infinity)
                        .opacity(0.5) // Make it semi-transparent so we can see the map underneath
                    
                    // a. Beacon dots/pins placed by user (stacked above map and grid)
                    ForEach(beaconManager.placedBeacons, id: \.name) { beacon in
                        BeaconDot(beacon: beacon, mapManager: mapManager, geometry: geometry)
                    }
                    
                    // Debug overlay - border around the original map rect (before transforms)
                    Rectangle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(
                            width: geometry.size.height/2,  // Original map width (square)
                            height: geometry.size.height/2  // Original map height (square)
                        )
                        .position(
                            x: geometry.size.width / 2,   // Center horizontally
                            y: geometry.size.height / 2   // Center vertically
                        )
                }
                .coordinateSpace(name: "mapSpace")
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
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            // Get tap location in the map's coordinate space
                            let tapLocation = value.location
                            handleMapTap(at: tapLocation, in: geometry)
                        }
                )
                
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
        
        // Get the authoritative displayed map rect
        let rect = mapManager.getDisplayedMapRect(in: geometry)
        print("Displayed map rect: \(rect)")
        
        // Normalize tap location within the displayed map rect
        let normalizedLocation = CGPoint(
            x: (location.x - rect.minX) / rect.width,
            y: (location.y - rect.minY) / rect.height
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
    @ObservedObject var mapManager: MapManager
    let geometry: GeometryProxy
    
    var body: some View {
        // Get the original (untransformed) map rect
        let originalRect = CGRect(
            x: (geometry.size.width - geometry.size.height) / 2,  // Center horizontally
            y: 0,                                                 // Top edge
            width: geometry.size.height,                          // Square width
            height: geometry.size.height                          // Square height
        )
        
        // Convert normalized coordinates to original screen position
        let screenPosition = CGPoint(
            x: originalRect.minX + (beacon.position.x * originalRect.width),
            y: originalRect.minY + (beacon.position.y * originalRect.height)
        )
        
        Circle()
            .fill(beacon.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
        .position(screenPosition)
    }
}

#Preview {
    MapView(mapManager: MapManager(), beaconManager: BeaconManager())
}
