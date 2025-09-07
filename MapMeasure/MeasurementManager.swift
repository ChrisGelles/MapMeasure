//
//  MeasurementManager.swift
//  MapMeasure
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI
import Foundation

// MARK: - Data Models
struct Measurement: Identifiable {
    let id = UUID()
    let position: CGPoint // Center position (normalized coordinates 0-1)
    let size: CGSize // Size in normalized coordinates (0-1)
    let fillColor: Color
    let strokeColor: Color = .black
    var realWorldSize: Float? = nil // Size in meters (user input)
}

struct BeaconPin: Identifiable {
    let id = UUID()
    let name: String
    let position: CGPoint // Normalized coordinates (0-1)
    let color: Color
}

// MARK: - Measurement Manager
class MeasurementManager: ObservableObject {
    @Published var measurements: [Measurement] = []
    @Published var isCreatingMeasurement: Bool = false
    @Published var currentMeasurement: Measurement? = nil
    @Published var beaconPins: [BeaconPin] = []
    
    private let persistenceKey = "measurements"
    private let beaconPersistenceKey = "placedBeacons" // NavTagger's key
    private let sharedUserDefaults = UserDefaults(suiteName: "group.com.cmnh.beaconapps") ?? UserDefaults.standard
    
    init() {
        loadMeasurements()
        loadBeaconPinsFromNavTagger()
    }
    
    // MARK: - Measurement Creation
    func startCreatingMeasurement() {
        isCreatingMeasurement = true
        currentMeasurement = nil
    }
    
    func cancelCreatingMeasurement() {
        isCreatingMeasurement = false
        currentMeasurement = nil
    }
    
    func createMeasurement(at position: CGPoint, size: CGSize) {
        let measurement = Measurement(
            position: position,
            size: size,
            fillColor: .red
        )
        measurements.append(measurement)
        isCreatingMeasurement = false
        currentMeasurement = nil
        saveMeasurements()
    }
    
    func updateMeasurement(_ measurement: Measurement, position: CGPoint? = nil, size: CGSize? = nil, realWorldSize: Float? = nil) {
        guard let index = measurements.firstIndex(where: { $0.id == measurement.id }) else { return }
        
        var updatedMeasurement = measurement
        if let position = position {
            updatedMeasurement = Measurement(
                position: position,
                size: updatedMeasurement.size,
                fillColor: updatedMeasurement.fillColor
            )
        }
        if let size = size {
            updatedMeasurement = Measurement(
                position: updatedMeasurement.position,
                size: size,
                fillColor: updatedMeasurement.fillColor
            )
        }
        if let realWorldSize = realWorldSize {
            updatedMeasurement = Measurement(
                position: updatedMeasurement.position,
                size: updatedMeasurement.size,
                fillColor: updatedMeasurement.fillColor
            )
            // Note: We can't directly modify realWorldSize since it's a let property
            // We'll need to replace the entire measurement
            let newMeasurement = Measurement(
                position: updatedMeasurement.position,
                size: updatedMeasurement.size,
                fillColor: updatedMeasurement.fillColor
            )
            measurements[index] = newMeasurement
        } else {
            measurements[index] = updatedMeasurement
        }
        
        saveMeasurements()
    }
    
    func updateMeasurementRealWorldSize(_ measurement: Measurement, realWorldSize: Float) {
        guard let index = measurements.firstIndex(where: { $0.id == measurement.id }) else { return }
        
        let updatedMeasurement = Measurement(
            position: measurement.position,
            size: measurement.size,
            fillColor: measurement.fillColor
        )
        measurements[index] = updatedMeasurement
        saveMeasurements()
    }
    
    func clearAllMeasurements() {
        measurements = []
        saveMeasurements()
    }
    
    // MARK: - Persistence
    private func saveMeasurements() {
        let data = measurements.map { measurement in
            [
                "id": measurement.id.uuidString,
                "positionX": measurement.position.x,
                "positionY": measurement.position.y,
                "sizeWidth": measurement.size.width,
                "sizeHeight": measurement.size.height,
                "colorRed": UIColor(measurement.fillColor).red,
                "colorGreen": UIColor(measurement.fillColor).green,
                "colorBlue": UIColor(measurement.fillColor).blue,
                "colorAlpha": UIColor(measurement.fillColor).alpha,
                "realWorldSize": measurement.realWorldSize as Any
            ]
        }
        
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
    
    private func loadMeasurements() {
        guard let data = UserDefaults.standard.array(forKey: persistenceKey) as? [[String: Any]] else {
            print("No saved measurements found.")
            return
        }
        
        var loadedMeasurements: [Measurement] = []
        
        for measurementData in data {
            guard let idString = measurementData["id"] as? String,
                  let positionX = measurementData["positionX"] as? CGFloat,
                  let positionY = measurementData["positionY"] as? CGFloat,
                  let sizeWidth = measurementData["sizeWidth"] as? CGFloat,
                  let sizeHeight = measurementData["sizeHeight"] as? CGFloat,
                  let red = measurementData["colorRed"] as? CGFloat,
                  let green = measurementData["colorGreen"] as? CGFloat,
                  let blue = measurementData["colorBlue"] as? CGFloat,
                  let alpha = measurementData["colorAlpha"] as? CGFloat else {
                continue
            }
            
            let position = CGPoint(x: positionX, y: positionY)
            let size = CGSize(width: sizeWidth, height: sizeHeight)
            let color = Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
            let realWorldSize = measurementData["realWorldSize"] as? Float
            
            let measurement = Measurement(
                position: position,
                size: size,
                fillColor: color
            )
            loadedMeasurements.append(measurement)
        }
        
        measurements = loadedMeasurements
        print("Loaded \(loadedMeasurements.count) measurements from storage.")
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

// MARK: - Beacon Pin Loading from NavTagger
extension MeasurementManager {
    func loadBeaconPinsFromNavTagger() {
        guard let data = sharedUserDefaults.array(forKey: beaconPersistenceKey) as? [[String: Any]] else {
            print("No beacon data found from NavTagger.")
            return
        }
        
        var loadedPins: [BeaconPin] = []
        
        for beaconData in data {
            guard let name = beaconData["name"] as? String,
                  let x = beaconData["x"] as? CGFloat,
                  let y = beaconData["y"] as? CGFloat,
                  let red = beaconData["colorRed"] as? CGFloat,
                  let green = beaconData["colorGreen"] as? CGFloat,
                  let blue = beaconData["colorBlue"] as? CGFloat,
                  let alpha = beaconData["colorAlpha"] as? CGFloat else {
                continue
            }
            
            let color = Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
            let pin = BeaconPin(
                name: name,
                position: CGPoint(x: x, y: y),
                color: color
            )
            loadedPins.append(pin)
        }
        
        beaconPins = loadedPins
        print("Loaded \(beaconPins.count) beacon pins from NavTagger")
    }
}
