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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transformed container with map, measurements, and beacon pins
                ZStack {
                    // Map Image
                    Image("myFirstFloor_v03-metric")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: .infinity)
                    
                    // Measurement squares
                    ForEach(measurementManager.measurements, id: \.id) { measurement in
                        MeasurementSquare(measurement: measurement, geometry: geometry)
                    }
                    
                    // Beacon pins from NavTagger
                    ForEach(measurementManager.beaconPins, id: \.id) { beacon in
                        BeaconPinView(beacon: beacon, geometry: geometry)
                    }
                }
                .scaleEffect(mapManager.scale, anchor: .center)
                .offset(mapManager.offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            mapManager.updatePan(translation: value.translation)
                        }
                        .onEnded { _ in
                            mapManager.endPan()
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            mapManager.updateZoom(magnification: value)
                        }
                        .onEnded { _ in
                            mapManager.endZoom()
                        }
                )
                .onTapGesture { location in
                    if measurementManager.isCreatingMeasurement {
                        // Convert tap location to normalized coordinates
                        let normalizedX = location.x / geometry.size.width
                        let normalizedY = location.y / geometry.size.height
                        let defaultSize = CGSize(width: 0.1, height: 0.1) // 10% of screen size
                        measurementManager.createMeasurement(at: CGPoint(x: normalizedX, y: normalizedY), size: defaultSize)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct MeasurementSquare: View {
    let measurement: Measurement
    let geometry: GeometryProxy
    
    var body: some View {
        let pos = CGPoint(
            x: measurement.position.x * geometry.size.width,
            y: measurement.position.y * geometry.size.height
        )
        
        Rectangle()
            .fill(measurement.fillColor.opacity(0.3))
            .overlay(
                Rectangle()
                    .stroke(measurement.strokeColor, lineWidth: 1)
            )
            .frame(width: measurement.size.width * geometry.size.width, height: measurement.size.height * geometry.size.height)
            .position(pos)
    }
}

struct BeaconPinView: View {
    let beacon: BeaconPin
    let geometry: GeometryProxy
    
    var body: some View {
        let pos = CGPoint(
            x: beacon.position.x * geometry.size.width,
            y: beacon.position.y * geometry.size.height
        )
        
        Circle()
            .fill(beacon.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 2)
            )
            .position(pos)
    }
}

#Preview {
    MapView(mapManager: MapManager(), measurementManager: MeasurementManager())
}