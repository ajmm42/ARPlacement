//
//  CustomDirectionalLight.swift
//  ARPlacement
//
//

import Foundation
import RealityKit

/// A custom directional light, which can be used for lighting the 3D or AR scene in a
/// custom manner.
class CustomDirectionalLight: Entity, HasDirectionalLight {
    required init() {
        super.init()
        self.light = DirectionalLightComponent(color: .yellow,
                                           intensity: 20000,
                                    isRealWorldProxy: true)
        self.shadow = DirectionalLightComponent.Shadow(
                                       maximumDistance: 100,
                                             depthBias: 5.0)
        self.orientation = simd_quatf(angle: -.pi/1.5,
                                       axis: [1,0,0])
    }
}
