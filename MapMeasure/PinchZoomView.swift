//
//  PinchZoomView.swift
//  MapMeasure
//
//  Created by Chris Gelles on 9/7/25.
//

import SwiftUI
import UIKit

struct PinchZoomView: UIViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let onZoomChanged: (CGFloat, CGPoint) -> Void
    let onZoomEnded: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = true
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinchGesture.delegate = context.coordinator
        view.addGestureRecognizer(pinchGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the view if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let parent: PinchZoomView
        private var initialCenter: CGPoint = .zero
        
        init(_ parent: PinchZoomView) {
            self.parent = parent
        }
        
        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                // Calculate the center point between the two fingers
                if recognizer.numberOfTouches >= 2 {
                    let touch1 = recognizer.location(ofTouch: 0, in: recognizer.view)
                    let touch2 = recognizer.location(ofTouch: 1, in: recognizer.view)
                    initialCenter = CGPoint(
                        x: (touch1.x + touch2.x) / 2,
                        y: (touch1.y + touch2.y) / 2
                    )
                } else {
                    // Fallback to single touch location
                    initialCenter = recognizer.location(in: recognizer.view)
                }
                
            case .changed:
                let scale = recognizer.scale
                // Use the initial center point, don't update it as fingers move
                let swiftUICenter = CGPoint(x: initialCenter.x, y: initialCenter.y)
                parent.onZoomChanged(scale, swiftUICenter)
                
            case .ended, .cancelled:
                parent.onZoomEnded()
                
            default:
                break
            }
        }
        
        // Allow simultaneous gestures so pan and pinch can work together
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        // Allow the pinch gesture to receive touches, but let other gestures work simultaneously
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            return true
        }
    }
}
