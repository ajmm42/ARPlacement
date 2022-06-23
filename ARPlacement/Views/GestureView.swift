//
//  GestureView.swift
//  ARPlacement
//
//

import Foundation
import RealityKit
#if canImport(Spatial)
import Spatial
#endif
import UIKit

/// A `UIView` that adds gesture interactions and handles performing actions related rotating,
/// scaling, and selecting children relative to the Entity.
public final class GestureView: UIView {
    
    // MARK: - Properties
    
    // MARK: Private
    
    /// The `Entity` which should receive transforms as related to the implemented gestures
    /// in the `init` method.
    private let entity: Entity
    
    /// A present animation duration, for testing animations when moving or modifying an Entity.
    private let animationDuration = 0.25
    
    /// Reference to the current horizontal angle offset of the `Entity`.
    var current_X_Angle: Float = 0.0
    
    /// Reference to the current vertical angle offset of the `Entity`.
    var current_Y_Angle: Float = 0.0
    
    // MARK: - Methods
    
    // MARK: Public
    
    /// Initializes the view and adds the relevant interactions for functionality.
    /// - Parameter entity: The passed `Entity`, which will receive interactions.
    init(entity: Entity) {
        self.entity = entity
        super.init(frame: .zero)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTapsRequired = 1
        addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
        
        // TODO: Add scale gesture.
//        let scaleGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
//        addGestureRecognizer(scaleGesture)
    }
    
    required init(coder: NSCoder) {
        fatalError()
    }
    
    /// Handles a received tap on the `Entity`, which then performs a raycast to determine which child (such as
    /// a door, window, wall, etc.) has been selected.
    /// - Parameter sender: The passed `UITapGestureRecognizer` to determine tap location.
    @objc func handleTap(sender: UITapGestureRecognizer) {
        guard let viewport = superview as? RealityARView,
              let ray = viewport.ray(through: sender.location(in: viewport))
        else {
            return
        }
        
        guard let raycastResult = viewport.scene.raycast(
            origin: ray.origin,
            direction: ray.direction,
            length: 5,
            query: .nearest
        ).first else {
            return
        }
        
        // TODO: Handle modification of the selected child within the model.
        _ = raycastResult
        
    }
    
    /// Receives the pan gestures to offset the `Entity` rotation relative to the provided pan parameters.
    /// - Parameter sender: The passed `UIPanGestureRecognizer` to determine the rotation
    /// events.
    @objc func handlePan(sender: UIPanGestureRecognizer) {
        switch sender.state {
            case .changed, .ended:
                let translate = sender.translation(in: sender.view)
                let angle_X = Float(translate.y / 25) * .pi / 180.0
                let angle_Y = Float(translate.x / 25) * .pi / 180.0
                current_X_Angle += angle_X
                current_Y_Angle += angle_Y
            
            let transform = Transform(
                pitch: current_X_Angle,
                yaw: current_Y_Angle,
                roll: .zero)
            
            let simRotation = transform.rotation
            if #available(iOS 16.0, *) {
                /* Began testing the `Spatial` framework in iOS 16 which appears slightly
                 easier to compute the quaternion than using a matrix or Transform.  Commented
                 out to allow for building in Xcode 13 and 14, instead of only Xcode 14.
                let spatialTransform = Rotation3D(
                    axis: RotationAxis3D(x: 1, y: 0, z: 0),
                    angle: Angle2D(degrees: 90))
                simRotation = simd_quatf(rotation: spatialTransform)
                */
            }
            
            entity.setOrientation(simRotation,
                                      relativeTo: nil)
            default: break
        }
    }
    
    /// Handles the pitch gesture to scale the `Entity`.
    /// - Parameter sender: The provided `UIPinchGestureRecognizer` that will determine the scale
    /// offset.
    @objc func handlePinch(sender: UIPinchGestureRecognizer) {
        entity.setScale(SIMD3<Float>(repeating: Float(sender.scale)), relativeTo: entity)
        entity.scale = SIMD3<Float>(repeating: min(max(0.5, entity.scale.x), 1.5))
    }
    
    /// Moves the object to the desired location.  To be used when selecting a child of the RoomPlan entity, such
    /// as a door or window, and can be moved or modified.
    /// - Parameter location: The desired location to move the object to.
    private func moveObject(to location: CGPoint) {
        guard let viewport = superview as? RealityARView,
              let raycastResult = viewport.raycast(
                from: location,
                allowing: .existingPlaneInfinite,
                alignment: .horizontal).first else {
            return
        }
        let location = Transform(matrix: raycastResult.worldTransform).translation
        let newTransform = Transform(
            scale: entity.scale(relativeTo: nil),
            rotation: entity.orientation(relativeTo: nil),
            translation: location
        )
        entity.move(to: newTransform, relativeTo: nil, duration: animationDuration)
    }
}

extension GestureView: UIGestureRecognizerDelegate {
    
    /// Determines if the gesture recognizer should be used simultaneously with other gesutres.
    /// - Parameters:
    ///   - gestureRecognizer: The passed `UIGestureRecognizer` to make this determination
    ///   regarding simultaneous gestures on.
    ///   - otherGestureRecognizer: The other `UIGestureRecognizer` to make this determination
    ///   regarding simultaneous gestures on.
    /// - Returns: A boolean determining if simultaneous gestures should be applied.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    /// Determines if the gesture recognizer should require a failure before passing interactions.
    /// - Parameters:
    ///   - gestureRecognizer: The passed `UIGestureRecognizer` to make this determination
    ///   regarding failures on.
    ///   - otherGestureRecognizer: The other `UIGestureRecognizer` to make this determination
    ///   regarding failures on.
    /// - Returns: A boolean determining if requiring a failure should be required.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPinchGestureRecognizer, otherGestureRecognizer is UIRotationGestureRecognizer {
            return true
        }
        return false
    }
}
