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
            let baseSide = geometry.size.height
            ZStack {
                // 1. Container (can be panned and zoomed with gestures. Everything inside moves together)
                GeometryReader { mapGeometry in
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
                            BeaconDot(beacon: beacon, mapContentSize: mapGeometry.size)
                        }
                        
                        // Debug overlay - border around the map container bounds
                        Rectangle()
                            .stroke(Color.red, lineWidth: 2)
                            .frame(
                                width: mapGeometry.size.width,
                                height: mapGeometry.size.height
                            )
                            .position(
                                x: mapGeometry.size.width / 2,
                                y: mapGeometry.size.height / 2
                            )
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // If drag distance is significant, treat as pan
                                let dragDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                                if dragDistance > 10 {
                                    mapManager.updatePan(translation: value.translation)
                                }
                            }
                            .onEnded { value in
                                // If drag distance is small, treat as tap
                                let dragDistance = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)
                                if dragDistance <= 10 {
                                    let tapLocation = value.location
                                    handleMapTap(at: tapLocation, mapContentSize: mapGeometry.size)
                                } else {
                                    mapManager.endPan()
                                }
                            }
                    )
                }
                .coordinateSpace(name: "mapSpace")
                .scaleEffect(mapManager.scale)
                .offset(mapManager.offset)
                .clipped()
                .gesture(
                    // Zoom gesture
                    MagnificationGesture()
                        .onChanged { value in
                            mapManager.updateZoom(magnification: value)
                        }
                        .onEnded { _ in
                            mapManager.endZoom()
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
    
    private func handleMapTap(at location: CGPoint, mapContentSize: CGSize) {
        guard let armedBeacon = beaconManager.armedBeacon else { 
            print("No armed beacon for placement")
            return 
        }
        
        print("Map tapped at: \(location)")
        print("Map content size: \(mapContentSize)")
        
        // Normalize tap location within the map container's bounds
        let normalizedLocation = CGPoint(
            x: location.x / mapContentSize.width,
            y: location.y / mapContentSize.height
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
    let mapContentSize: CGSize
    
    var body: some View {
        // Convert normalized coordinates to position within the map container
        let position = CGPoint(
            x: beacon.position.x * mapContentSize.width,
            y: beacon.position.y * mapContentSize.height
        )
        
        Circle()
            .fill(beacon.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
        .position(position)
    }
}

#Preview {
    MapView(mapManager: MapManager(), beaconManager: BeaconManager())
}
