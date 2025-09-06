//
//  ContentView.swift
//  NavTagger
//
//  Created by Chris Gelles on 9/6/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var mapManager = MapManager()
    @StateObject private var beaconManager = BeaconManager()
    @State private var selectedDrawer: DrawerType? = nil
    
    enum DrawerType: String, CaseIterable {
        case beacons = "beacons"
        
        var icon: String {
            switch self {
            case .beacons: return "target"
            }
        }
        
        var title: String {
            switch self {
            case .beacons: return "Beacons"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map View
                MapView(mapManager: mapManager, beaconManager: beaconManager)
                    .ignoresSafeArea()
                
                // Bottom Drawer System
                VStack {
                    Spacer()
                    
                    // Drawer Tabs
                    HStack(spacing: 12) {
                        ForEach(DrawerType.allCases, id: \.self) { drawerType in
                            DrawerTab(
                                type: drawerType,
                                isSelected: selectedDrawer == drawerType,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if selectedDrawer == drawerType {
                                            selectedDrawer = nil
                                        } else {
                                            selectedDrawer = drawerType
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    
                    // Drawer Content
                    if let selectedDrawer = selectedDrawer {
                        DrawerContent(
                            type: selectedDrawer,
                            mapManager: mapManager,
                            beaconManager: beaconManager,
                            geometry: geometry
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            mapManager.requestLocationPermission()
            mapManager.setInitialZoom()
            beaconManager.loadBeaconWhitelist()
            beaconManager.clearAllPlacements()
        }
    }
}

struct DrawerTab: View {
    let type: ContentView.DrawerType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .medium))
                Text(type.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DrawerContent: View {
    let type: ContentView.DrawerType
    let mapManager: MapManager
    let beaconManager: BeaconManager
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(spacing: 0) {
            // Drawer Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // Drawer Content
            switch type {
            case .beacons:
                BeaconDrawer(
                    beaconManager: beaconManager,
                    mapManager: mapManager,
                    geometry: geometry
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
        .frame(maxHeight: geometry.size.height * 0.2)
    }
}

#Preview {
    ContentView()
}