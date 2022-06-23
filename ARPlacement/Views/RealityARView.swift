//
//  RealityARView.swift
//  ARPlacement
//
//

import ARKit
import Combine
import Foundation
import RealityKit

/// A subclassed `ARView` that can be used for displaying a 3D model and allowing for interacting with the mode.
class RealityARView: ARView {
    
    // MARK: - Properties
    
    // MARK: Public
    
    /// The provided drag gesture data, which is gathered from the parent SwiftUI view, if the user
    /// interacts with the view using a drag or pan motion.
    @Published public var dragGesutreData = MultiDragGesture(
        startLocation: .zero,
        translation: .zero,
        endLocation: .zero)
    
    // MARK: Private
    
    /// A preset offset for the position of the `AnchorEntity`, to slightly offset the position of the object
    /// for a better interactive experience in a non-AR view.
    private let worldOriginMac: SIMD3<Float> = [0.0, -0.1, 1.5]
    
    /// The main anchor for the object to place in the view.
    private var objectAnchor: AnchorEntity!
    
    /// The file name of the entity, passed from the parent `UIViewRepresentable` and is set during
    /// the `configureSession` method, which is being used as a custom initializer.
    public var entityName: String!
    
    /// The active entity, which is set when the `Entity.loadAsync` method completes successfully.
    private var activeEntity: Entity?
    
    /// The custom directional light, which can be used to modify the scene's lighting and improve the
    /// overall appearance of the model, as needed.
    private let directLight = CustomDirectionalLight()
    
    /// A reference to the current state of the property to determine if a practical Augmented Reality
    /// experience should be used.
    private var useAR: Bool = true
    
    /// A reference to the current state of the interactivity, determining whether SwiftUI or UIKit-based
    /// gestures should be used.
    private var useSwiftUIGestures = false
    
    /// A container to hold Combine-related cancellables and reactive chains.
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Methods
    
    // MARK: Public
    
    /// Configures the `ARView` session, preparing the main `AnchorEntity`
    /// and the state of whether to use Augmented Reality or a non-Augmented Reality
    /// experience.
    /// - Parameters:
    ///   - entityName: The file name of the entity to load.
    ///   - useAR: A booelan property determining if an Augmented Reality session should be
    ///   used.
    ///   - useSwiftUIGestures: A boolean property determining if the SwiftUI gestures should be
    ///   used for interactivity, or the UIKit gestures.
    public func configureSession(
        entityName: String,
        useAR: Bool,
        useSwiftUIGestures: Bool) {
            self.entityName = entityName
            self.useAR = useAR
            self.useSwiftUIGestures = useSwiftUIGestures
        #if targetEnvironment(simulator)
            objectAnchor = AnchorEntity(world: worldOriginMac)
        #else
        if ProcessInfo.processInfo.isiOSAppOnMac {
            objectAnchor = AnchorEntity(world: worldOriginMac)
        } else {
            if useAR {
                objectAnchor = AnchorEntity(
                    plane: .horizontal,
                    classification: [.floor, .table],
                    minimumBounds: SIMD2<Float>(0.1, 0.1)
                )

                if ARWorldTrackingConfiguration.isSupported {
                    automaticallyConfigureSession = false

                    let configuration = ARWorldTrackingConfiguration()
                    configuration.planeDetection = .horizontal
                    if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
                        configuration.frameSemantics.insert(.personSegmentationWithDepth)
                    }
                    session.run(configuration)

                }
            } else {
                objectAnchor = AnchorEntity(world: worldOriginMac)
            }
        }
        #endif
        
        self.environment.background = useAR ? .cameraFeed() : .color(.white)
    
        configureListeners()
        loadEntity()
    }
    
    // MARK: Private
    
    /// Configures any Combine-related subscribers and reactive methods.
    private func configureListeners() {
        $dragGesutreData
            .receive(on: RunLoop.main)
            .sink { [weak self] dragData in
                guard let strongSelf = self else { return }
                strongSelf.handlePan(data: dragData)
            }
            .store(in: &cancellables)
    }
    
    /// Loads the Entity, if possible, and performs post-loading actions (in this case, modifying
    /// the model to test the capabilities of a RoomPlan-based model, adds physics to the model,
    /// and prepares lighting and gestures, if needed).
    private func loadEntity() {
        Entity.loadAsync(named: entityName)
            .receive(on: RunLoop.main)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    fatalError("Could not load entity. \(error.localizedDescription)")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] entity in
                guard let strongSelf = self else { return }
                
                // Test to determine what it looks like to modify a component of a
                // RoomPlan model, such as altering the material of a "Window".
                let archGroup = entity.findEntity(named: "Arch_grp")
                _ = archGroup?.children.compactMap { child in
                    if let window = child.findEntity(named: "Window") {
                        let material = SimpleMaterial(color: UIColor(red: 180.0/255.0, green: 238.0/255.0, blue: 180.0/255.0, alpha: 1.0), roughness: 3.0, isMetallic: false)
                        _ = material // Unused for now
                        let occlusionMaterial = OcclusionMaterial(receivesDynamicLighting: true)
                        guard var modelComponent = window.children[0].children[0].components[ModelComponent.self] as? ModelComponent else {
                            return
                        }
                        modelComponent.materials = [occlusionMaterial]
                        window.children[0].children[0].components[ModelComponent.self] = modelComponent
                    }
                }
                
                // Adds a floor to a RoomPlan model as the provided USDZ from RoomPlan
                // does not include a floor.
                let floor = entity.roomPlanfloor()
                entity.addChild(floor)
                
                strongSelf.addPhysics()
                strongSelf.addEntityToScene(entity: entity)
                strongSelf.addLighting()
                strongSelf.addGestures()
            }
            .store(in: &cancellables)
    }
    
    /// Adds the Entity to the scene by adding the Entity as a child to the anchor.
    /// - Parameter entity: The passed Entity, after it has been loaded.
    private func addEntityToScene(entity: Entity) {
        objectAnchor.addChild(entity)
        scene.addAnchor(objectAnchor)
        activeEntity = entity
    }
    
    /// Adds lighting to the scene by applying the custom directional light and
    /// positioning as needed.
    private func addLighting() {
        let lightAnchor = AnchorEntity()
        lightAnchor.position = objectAnchor.position
        lightAnchor.position += SIMD3<Float>(0.0, 0.0, -3.0)
        lightAnchor.addChild(directLight)
        scene.anchors.append(lightAnchor)
    }
    
    /// Adds physics to the entity, allowing interactions to have a weighted or
    /// more dynamic feel.
    private func addPhysics() {
        guard let entity = activeEntity else { return }
        entity.generateCollisionShapes(recursive: true)
        
        let kinematics: PhysicsBodyComponent = .init(massProperties: .init(mass: 90),
                                                                   material: nil,
                                                                       mode: .kinematic)

        let motion: PhysicsMotionComponent = .init(linearVelocity: [0.1 ,0, 0],
                                                          angularVelocity: [3, 3, 3])
        entity.components.set(kinematics)
        entity.components.set(motion)
    }
    
    /// Adds the `GestureView` to the parent view, which allows for handling interactions
    /// through UIKit.
    private func addGestures() {
        guard let entity = activeEntity,
              !useSwiftUIGestures
        else { return }
        
        let gestureView = GestureView(entity: entity)
        addSubview(gestureView)
        gestureView.translatesAutoresizingMaskIntoConstraints = false
        addConstraints([
            gestureView.topAnchor.constraint(equalTo: topAnchor),
            gestureView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gestureView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gestureView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    /// Handles the interactions as gathered from the parent SwiftUI view, if the usage of
    /// SwiftUI interactions is enabled.
    /// - Parameter data: The provided gesture data, as a `MultiDragGesture`
    /// for interactions.
    private func handlePan(data: MultiDragGesture) {
        let xPosition = data.translation.width
        let xRotation: Float = Float(xPosition * 0.005)
        let xTransform = Transform(pitch: 0, yaw: xRotation, roll: 0)
        guard let entity = activeEntity else { return }
        entity.move(to: xTransform, relativeTo: entity, duration: 0.1, timingFunction: .easeInOut)
    }
}

extension Entity {
    
    /// Generates a box mesh, slightly larger than the bounds of the loaded `Entity`,
    /// which can be added as a floor to the RoomPlan model.
    /// - Returns: The computed floor as a `ModelEntity`, which can be added as a
    /// child to the RoomPlan model.
    func roomPlanfloor() -> ModelEntity {
        let entityBounds = self.visualBounds(relativeTo: nil)
        let width = entityBounds.extents.x + 0.025
        let height = Float(0.002)
        let depth = entityBounds.extents.z + 0.0125
        
        let boxResource = MeshResource.generateBox(
            size: SIMD3<Float>(width, height, depth))
        let material = SimpleMaterial(
            color: .blue,
            roughness: 0,
            isMetallic: true)
        let floorEntity = ModelEntity(
            mesh: boxResource,
            materials: [material])
        
        let yCenter = (entityBounds.center.y * 100) - 1.0
        floorEntity.scale = [100.0, 100.0, 100.0]
        floorEntity.position = [entityBounds.center.x * 100, yCenter, entityBounds.center.z * 100]
        
        return floorEntity
    }
}
