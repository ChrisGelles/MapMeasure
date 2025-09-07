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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map View
                MapView(mapManager: mapManager, measurementManager: measurementManager)
                    .ignoresSafeArea()
                
                // Reset View Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            mapManager.resetToInitialPosition()
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
            }
        }
        .onAppear {
            mapManager.setInitialZoom()
        }
    }
}

#Preview {
    ContentView()
}