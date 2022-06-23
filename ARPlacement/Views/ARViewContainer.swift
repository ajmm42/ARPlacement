//
//  ARViewContainer.swift
//  ARPlacement
//
//

import Foundation
import RealityKit
import SwiftUI

/// The `ARViewContainer`, which is a SwiftUI container for displaying the underlying `ARView.`
struct ARViewContainer: UIViewRepresentable {
    
    // MARK: - Properties
    
    // MARK: Public
    
    /// The passed file name of the USDZ model, which will be loaded as an `Entity` into
    /// the view.
    @Binding var entityName: String
    
    /// A passed boolean to determine if the SwiftUI-based drag gesture should be used to calculate
    /// the user preferred orientation of the model, or if the UIKit gestures should be applied.
    @Binding var useSwiftUIDrag: Bool
    
    /// The passed drag data, which may be used, if the above `useSwiftUIDrag` property is
    /// enabled, to modify the orientation and transform of the model in the view.
    @Binding var dragData: MultiDragGesture
    
    /// During development, Augmented Reality may be disabled for the sake of testing the 3D interactions
    /// without the use of Augmented Reality.
    var useARExperience: Bool
    
    /// Required conformance to make the underlying `UIView`, which is an `ARView` that holds the
    /// 3D experience.
    /// - Parameter context: The provided context of the SwiftUI view.
    /// - Returns: A computed `RealityARView`, a subclassed `ARView`.
    func makeUIView(context: Context) -> RealityARView {
        var arView: RealityARView!
        
        // If building for the Simulator, prepare a frame of zero and allow
        // Xcode to compile the view accordingly.
        #if targetEnvironment(simulator)
        arView = RealityARView(frame: .zero)
        
        // If not building for the Simlator, determine if the app is being built
        // for macOS (through Mac Catalyst or build for iOS device) or a practical
        // device.
        #else
        
        if ProcessInfo.processInfo.isiOSAppOnMac {
            arView = RealityARView(
                frame: .zero,
                cameraMode: .nonAR,
                automaticallyConfigureSession: true)
        } else {
            
            // TODO: During development, only leverage a non-AR experience.
            arView = RealityARView(
                frame: .zero,
                cameraMode: useARExperience ? .ar : .nonAR,
                automaticallyConfigureSession: useARExperience ? false : true)
        }
        #endif
        
        arView.configureSession(
            entityName: entityName,
            useAR: useARExperience,
            useSwiftUIGestures: useSwiftUIDrag)
        return arView
        
    }
    
    /// Required conformance to update the underlying `RealityARView` when the parent SwiftUI
    /// view updates.
    /// - Parameters:
    ///   - uiView: The provided `RealityARView` that displays the 3D experience.
    ///   - context: The provided context that can be used to update the underlying view.
    func updateUIView(_ uiView: RealityARView, context: Context) {
        guard useSwiftUIDrag else { return }
        uiView.dragGesutreData = dragData
    }
}
