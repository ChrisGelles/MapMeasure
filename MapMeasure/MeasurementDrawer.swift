//
//  MeasurementDrawer.swift
//  MapMeasure
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI

struct MeasurementDrawer: View {
    @ObservedObject var measurementManager: MeasurementManager
    @ObservedObject var mapManager: MapManager
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(spacing: 12) {
            // Add Measurement Button
            Button(action: {
                measurementManager.startCreatingMeasurement()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.rectangle")
                        .font(.system(size: 16, weight: .medium))
                    Text("Add Measurement")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Measurements List
            if measurementManager.measurements.isEmpty {
                Text("No measurements yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(measurementManager.measurements) { measurement in
                            MeasurementRow(
                                measurement: measurement,
                                measurementManager: measurementManager
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct MeasurementRow: View {
    let measurement: Measurement
    @ObservedObject var measurementManager: MeasurementManager
    @State private var realWorldSizeText: String = ""
    @State private var isEditingSize: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(measurement.fillColor)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black, lineWidth: 1)
                )
            
            // Size input field
            HStack {
                Text("Size:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("meters", text: $realWorldSizeText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .onTapGesture {
                        isEditingSize = true
                    }
                    .onSubmit {
                        updateRealWorldSize()
                    }
                    .onChange(of: realWorldSizeText) { newValue in
                        // Auto-save as user types
                        if let size = Float(newValue), size > 0 {
                            measurementManager.updateMeasurementRealWorldSize(measurement, realWorldSize: size)
                        }
                    }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
        .onAppear {
            if let realWorldSize = measurement.realWorldSize {
                realWorldSizeText = String(realWorldSize)
            }
        }
    }
    
    private func updateRealWorldSize() {
        isEditingSize = false
        if let size = Float(realWorldSizeText), size > 0 {
            measurementManager.updateMeasurementRealWorldSize(measurement, realWorldSize: size)
        }
    }
}

#Preview {
    MeasurementDrawer(
        measurementManager: MeasurementManager(),
        mapManager: MapManager(),
        geometry: GeometryReader { geometry in
            Color.clear
        }.frame(width: 300, height: 200)
    )
}
