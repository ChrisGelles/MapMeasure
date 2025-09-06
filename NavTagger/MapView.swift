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
                // Map Image with Beacon Dots - All in one view with unified gestures
                ZStack {
                    // Map Image - fill screen height
                    Image("myFirstFloor_v03-metric")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(mapManager.scale)
                        .offset(mapManager.offset)
                        .clipped()
                    
                    // Beacon Dots - positioned relative to the map
                    ForEach(beaconManager.placedBeacons, id: \.name) { beacon in
                        BeaconDot(
                            beacon: beacon,
                            mapManager: mapManager,
                            geometry: geometry
                        )
                    }
                }
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
                
                // Armed Beacon Hint
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
        
        // Convert tap location to map coordinates
        let mapFrame = mapManager.getMapFrame(in: geometry)
        print("Map frame: \(mapFrame)")
        
        let relativeLocation = CGPoint(
            x: (location.x - mapFrame.minX) / mapFrame.width,
            y: (location.y - mapFrame.minY) / mapFrame.height
        )
        
        print("Relative location: \(relativeLocation)")
        
        // Clamp to map bounds
        let clampedLocation = CGPoint(
            x: max(0, min(1, relativeLocation.x)),
            y: max(0, min(1, relativeLocation.y))
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
        // Calculate the map's actual size and position
        let mapSize = mapManager.getMapSize(in: geometry)
        let mapOffset = mapManager.offset
        
        // Position the dot relative to the map image (not screen)
        let dotPosition = CGPoint(
            x: (beacon.position.x * mapSize.width) + mapOffset.width,
            y: (beacon.position.y * mapSize.height) + mapOffset.height
        )
        
        Circle()
            .fill(beacon.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
        .position(dotPosition)
    }
}

#Preview {
    MapView(mapManager: MapManager(), beaconManager: BeaconManager())
}
