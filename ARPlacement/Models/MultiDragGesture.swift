//
//  MultiDragGesture.swift
//  ARPlacement
//
//

import Foundation
import UIKit

/// A struct holding data related to the current drag gesture, which is applied from a
/// `SwiftUI` modifier on the parent view.  This data is used for modifying the rotation
/// and scale of a 3D object added to an `ARView`.
// TODO: Implement scaling.  At the moment, no pinch gesture or scaling is applied.
struct MultiDragGesture {
    
    /// The start location of the drag, when the user first begins movement
    /// of their finger on the display.
    var startLocation: CGPoint
    
    /// The current translation of the drag, which is provided, by `View`, as a `CGSize`,
    /// conforming the `CGSize.width` to the horizontal position and the `CGSize.height`
    /// to the vertical position.
    var translation: CGSize
    
    /// The end location of the drag, if it exists, to notate where the user's finger was removed from
    /// the display to signal the end of the gesture.
    var endLocation: CGPoint?
}
