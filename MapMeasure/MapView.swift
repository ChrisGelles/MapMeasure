//
//  MapView.swift
//  MapMeasure
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI

struct MapView: View {
    @ObservedObject var mapManager: MapManager
    @ObservedObject var measurementManager: MeasurementManager
    @ObservedObject var viewport: ViewportState
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Unified map container with all transforms applied
                UnifiedMapView(viewport: viewport, onTap: { point, size in
                    handleTap(at: point, containerSize: size)
                }) {
                    GeometryReader { mapGeometry in
                        ZStack {
                            // Map Image
                            Image("myFirstFloor_v03-metric")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: .infinity)
                            
                            // Measurement squares
                            ForEach(measurementManager.measurements, id: \.id) { measurement in
                                MeasurementSquare(measurement: measurement, mapContentSize: mapGeometry.size, viewport: viewport)
                            }
                            
                            // Beacon pins from NavTagger
                            ForEach(measurementManager.beaconPins, id: \.id) { beacon in
                                BeaconPinView(beacon: beacon, mapContentSize: mapGeometry.size, viewport: viewport)
                            }
                        }
                    }
                    // Apply transforms to the entire map content
                    .scaleEffect(viewport.scale, anchor: .center)
                    .rotationEffect(.degrees(viewport.rotation))
                    .offset(viewport.offset)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            // Sync initial state with legacy MapManager
            viewport.scale = mapManager.scale
            viewport.offset = mapManager.offset
        }
        .onChange(of: viewport.scale) { newScale in
            mapManager.scale = newScale
        }
        .onChange(of: viewport.offset) { newOffset in
            mapManager.offset = newOffset
        }
    }
    
    private func handleTap(at location: CGPoint, containerSize: CGSize) {
        if measurementManager.isCreatingMeasurement {
            // Use the coordinate mapper to get normalized coordinates
            Task { @MainActor in
                let normalizedLocation = CoordinateMapper.normalizedPoint(
                    in: containerSize,
                    from: location,
                    viewport: viewport
                )
                
                let defaultSize = CGSize(width: 0.1, height: 0.1) // 10% of screen size
                measurementManager.createMeasurement(at: normalizedLocation, size: defaultSize)
            }
        }
    }
}

struct MeasurementSquare: View {
    let measurement: Measurement
    let mapContentSize: CGSize
    @ObservedObject var viewport: ViewportState
    
    var body: some View {
        // Convert normalized coordinates to container coordinates
        // Since measurements are inside the transformed container, we don't apply viewport transforms here
        let position = CGPoint(
            x: measurement.position.x * mapContentSize.width,
            y: measurement.position.y * mapContentSize.height
        )
        
        Rectangle()
            .fill(measurement.fillColor.opacity(0.3))
            .overlay(
                Rectangle()
                    .stroke(measurement.strokeColor, lineWidth: 1)
            )
            .frame(
                width: measurement.size.width * mapContentSize.width,
                height: measurement.size.height * mapContentSize.height
            )
            .position(position)
    }
}

struct BeaconPinView: View {
    let beacon: BeaconPin
    let mapContentSize: CGSize
    @ObservedObject var viewport: ViewportState
    
    var body: some View {
        // Convert normalized coordinates to container coordinates
        // Since beacons are inside the transformed container, we don't apply viewport transforms here
        let position = CGPoint(
            x: beacon.position.x * mapContentSize.width,
            y: beacon.position.y * mapContentSize.height
        )
        
        Circle()
            .fill(beacon.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 2)
            )
            // Apply visual offset to account for visual center vs actual center
            // Fixed offset since the container scaling will handle zoom scaling
            .offset(y: -6) // Half the marker height
            .position(position)
    }
}

#Preview {
    MapView(mapManager: MapManager(), measurementManager: MeasurementManager(), viewport: ViewportState())
}