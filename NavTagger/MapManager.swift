//
//  MapManager.swift
//  NavTagger
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI
import CoreLocation

class MapManager: NSObject, ObservableObject {
    // Map state
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    
    // Bounds checking
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    private let maxOffset: CGFloat = 500.0
    
    // Gesture state
    private var lastPanOffset: CGSize = .zero
    private var lastScale: CGFloat = 1.0
    
    // Location manager
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Gesture Handling
    func updatePan(translation: CGSize) {
        let newOffset = CGSize(
            width: lastPanOffset.width + translation.width,
            height: lastPanOffset.height + translation.height
        )
        
        // Apply bounds checking
        let clampedOffset = clampOffset(newOffset)
        offset = clampedOffset
    }
    
    func endPan() {
        lastPanOffset = offset
    }
    
    func updateZoom(magnification: CGFloat) {
        let newScale = lastScale * magnification
        scale = clampScale(newScale)
    }
    
    func endZoom() {
        lastScale = scale
    }
    
    // MARK: - Bounds Checking
    private func clampScale(_ newScale: CGFloat) -> CGFloat {
        return max(minScale, min(maxScale, newScale))
    }
    
    private func clampOffset(_ newOffset: CGSize) -> CGSize {
        let maxOffsetValue = maxOffset * scale
        return CGSize(
            width: max(-maxOffsetValue, min(maxOffsetValue, newOffset.width)),
            height: max(-maxOffsetValue, min(maxOffsetValue, newOffset.height))
        )
    }
    
    // MARK: - Map Frame Calculation
    func getMapSize(in geometry: GeometryProxy) -> CGSize {
        let screenSize = geometry.size
        let imageAspectRatio: CGFloat = 1.0 // Assuming square image (2048x2048)
        let screenAspectRatio = screenSize.width / screenSize.height
        
        var mapSize: CGSize
        
        if screenAspectRatio > imageAspectRatio {
            // Screen is wider than image - fit to height
            mapSize = CGSize(
                width: screenSize.height * imageAspectRatio,
                height: screenSize.height
            )
        } else {
            // Screen is taller than image - fit to width
            mapSize = CGSize(
                width: screenSize.width,
                height: screenSize.width / imageAspectRatio
            )
        }
        
        // Apply scale
        return CGSize(
            width: mapSize.width * scale,
            height: mapSize.height * scale
        )
    }
    
    func getMapFrame(in geometry: GeometryProxy) -> CGRect {
        let screenSize = geometry.size
        let imageAspectRatio: CGFloat = 1.0 // Assuming square image (2048x2048)
        let screenAspectRatio = screenSize.width / screenSize.height
        
        var mapSize: CGSize
        var mapOrigin: CGPoint
        
        if screenAspectRatio > imageAspectRatio {
            // Screen is wider than image - fit to height
            mapSize = CGSize(
                width: screenSize.height * imageAspectRatio,
                height: screenSize.height
            )
            mapOrigin = CGPoint(
                x: (screenSize.width - mapSize.width) / 2,
                y: 0
            )
        } else {
            // Screen is taller than image - fit to width
            mapSize = CGSize(
                width: screenSize.width,
                height: screenSize.width / imageAspectRatio
            )
            mapOrigin = CGPoint(
                x: 0,
                y: (screenSize.height - mapSize.height) / 2
            )
        }
        
        // Apply scale and offset
        let scaledSize = CGSize(
            width: mapSize.width * scale,
            height: mapSize.height * scale
        )
        
        let scaledOrigin = CGPoint(
            x: mapOrigin.x + offset.width,
            y: mapOrigin.y + offset.height
        )
        
        return CGRect(origin: scaledOrigin, size: scaledSize)
    }
    
    // MARK: - Location Permission
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Reset
    func resetMap() {
        scale = 1.0
        offset = .zero
        lastScale = 1.0
        lastPanOffset = .zero
    }
}

// MARK: - CLLocationManagerDelegate
extension MapManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location permission granted")
        case .denied, .restricted:
            print("Location permission denied")
        case .notDetermined:
            print("Location permission not determined")
        @unknown default:
            print("Unknown location permission status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}