//
//  ContentView.swift
//  MapMeasure
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI

struct ContentView: View {
    @State private var mapManager = MapManager()
    @State private var measurementManager = MeasurementManager()
    @StateObject private var viewport = ViewportState()
    @StateObject private var beaconScanner = BeaconScanner()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map View
                MapView(mapManager: mapManager, measurementManager: measurementManager, viewport: viewport)
                    .ignoresSafeArea()
                
                // Reset View Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewport.resetTransform()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color.orange)
                                        .shadow(radius: 4)
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
                .allowsHitTesting(true) // Allow button to receive touches
                
                // Distance HUD at bottom
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        // 14-jazzyWombat (Red)
                        DistanceBox(
                            beaconName: "14-jazzyWombat",
                            color: .red,
                            distance: beaconScanner.distances["14-jazzyWombat"] ?? 0.0,
                            rssi: beaconScanner.rssi["14-jazzyWombat"] ?? 0
                        )
                        
                        // 15-frostyIbis (Green)
                        DistanceBox(
                            beaconName: "15-frostyIbis",
                            color: .green,
                            distance: beaconScanner.distances["15-frostyIbis"] ?? 0.0,
                            rssi: beaconScanner.rssi["15-frostyIbis"] ?? 0
                        )
                        
                        // 16-emberMarmot (Blue)
                        DistanceBox(
                            beaconName: "16-emberMarmot",
                            color: .blue,
                            distance: beaconScanner.distances["16-emberMarmot"] ?? 0.0,
                            rssi: beaconScanner.rssi["16-emberMarmot"] ?? 0
                        )
                        
                        // 17-thornyPangolin (Orange)
                        DistanceBox(
                            beaconName: "17-thornyPangolin",
                            color: .orange,
                            distance: beaconScanner.distances["17-thornyPangolin"] ?? 0.0,
                            rssi: beaconScanner.rssi["17-thornyPangolin"] ?? 0
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            mapManager.setInitialZoom()
            print("🚀 MapMeasure: Starting beacon scanner...")
            beaconScanner.start()
        }
        .onDisappear {
            beaconScanner.stop()
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Distance Box Component
struct DistanceBox: View {
    let beaconName: String
    let color: Color
    let distance: Double
    let rssi: Int
    
    var body: some View {
        VStack(spacing: 4) {
            // Beacon name (shortened)
            Text(beaconName.components(separatedBy: "-").last ?? beaconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Distance value
            Text(distance > 0 ? String(format: "%.2f", distance) : "—.—")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(distance > 0 ? .white : .white.opacity(0.5))
            
            // RSSI value (small text for debugging)
            Text("RSSI: \(rssi)")
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: 1)
                )
        )
    }
}