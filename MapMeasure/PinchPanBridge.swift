//
//  PinchPanBridge.swift
//  MapMeasure
//
//  Created by Chris Gelles on 9/7/25.
//

import SwiftUI
import UIKit

struct PinchPanBridge<Content: View>: UIViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let onTap: (CGPoint) -> Void
    let content: () -> Content
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = true
        
        // Create a UIHostingController to host the SwiftUI content
        let hostingController = UIHostingController(rootView: content())
        hostingController.view.backgroundColor = UIColor.clear
        hostingController.view.isUserInteractionEnabled = false // Disable touch handling on hosting controller
        
        // Add the hosting controller's view as a child
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Store reference to hosting controller
        context.coordinator.hostingController = hostingController
        
        // Add gesture recognizers
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        
        // Configure pan gesture for single finger only
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        
        // Set delegates
        pinchGesture.delegate = context.coordinator
        panGesture.delegate = context.coordinator
        tapGesture.delegate = context.coordinator
        
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Reliably refresh hosted SwiftUI when scale/offset bindings change
        if let hc = context.coordinator.hostingController {
            hc.rootView = content()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let parent: PinchPanBridge
        var hostingController: UIHostingController<Content>?
        private var startOffset: CGSize = .zero
        
        init(_ parent: PinchPanBridge) {
            self.parent = parent
        }
        
        // MARK: - Pinch Gesture Handler
        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                // Reset scale to 1.0 for incremental changes
                recognizer.scale = 1.0
                
            case .changed:
                guard let view = recognizer.view else { return }
                
                let sOld = parent.scale
                let sNew = max(0.5, min(3.0, sOld * recognizer.scale)) // clamp if you like
                let t = sNew / sOld
                if recognizer.state == .changed { print("pinch s", recognizer.scale) }
                
                // Midpoint between fingers (in bridge view coords)
                let focal: CGPoint
                if recognizer.numberOfTouches >= 2 {
                    let p0 = recognizer.location(ofTouch: 0, in: view)
                    let p1 = recognizer.location(ofTouch: 1, in: view)
                    focal = CGPoint(x: (p0.x + p1.x) / 2.0, y: (p0.y + p1.y) / 2.0)
                } else {
                    focal = recognizer.location(in: view)
                }
                
                // IMPORTANT: account for scale anchor = .center
                let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
                let old = parent.offset
                let dx = focal.x - center.x - old.width
                let dy = focal.y - center.y - old.height
                
                // Keep the focal point stationary on screen as scale changes
                let newOffset = CGSize(
                    width: old.width + (1 - t) * dx,
                    height: old.height + (1 - t) * dy
                )
                
                parent.scale = sNew
                parent.offset = newOffset
                
                // make next change incremental
                recognizer.scale = 1.0
                
            case .ended, .cancelled:
                break
                
            default:
                break
            }
        }
        
        // MARK: - Pan Gesture Handler
        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                startOffset = parent.offset
                
            case .changed:
                let translation = recognizer.translation(in: recognizer.view)
                if recognizer.state == .changed { print("pan Δ", translation) }
                parent.offset = CGSize(
                    width: startOffset.width + translation.x,
                    height: startOffset.height + translation.y
                )
                
            case .ended, .cancelled:
                startOffset = parent.offset
                
            default:
                break
            }
        }
        
        // MARK: - Tap Gesture Handler
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            let tapPoint = recognizer.location(in: recognizer.view)
            parent.onTap(tapPoint)
        }
        
        // MARK: - Gesture Recognizer Delegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow pinch and pan to work simultaneously
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Allow all gestures to receive touches
            return true
        }
    }
}
