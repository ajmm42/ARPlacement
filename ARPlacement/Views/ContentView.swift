//
//  ContentView.swift
//  ARPlacement
//
//

import SwiftUI
import RealityKit

/// The main `ContentView`, which acts as the parent view to the underlying
/// `ARView` that holds and displays the 3D content.
struct ContentView : View {
    
    // MARK: - Properties
    
    // MARK: Private
    
    /// The current file name of the 3D model to display and load.  This may be modified at runtime
    /// or set as a static file name if only one file is to be loaded (as is this case during development).
    @State private var modelName = "room.usdz"
    
    /// The current drag data, as related to the drag gesture being applied on the parent view and
    /// passed to the underlying `ARView`.
    @State private var dragData = MultiDragGesture(startLocation: .zero, translation: .zero, endLocation: .zero)
    
    /// During development, this property signifies whether to use the SwiftUI `DragGesture` modifier, rather
    /// than applying traditional pan and pinch gestures in UIKit.
    @State private var useSwiftUIDrag = false
    
    /// A boolean property to determine if Augmented Reality should be used, or a 3D experience for testing
    /// interactions.
    private var useARExperience = false
    
    /// The main view, which contains the underlying `ARView` wrapped in a `UIViewRepresentable`.
    var body: some View {
        ARViewContainer(
            entityName: $modelName,
            useSwiftUIDrag: $useSwiftUIDrag,
            dragData: $dragData,
            useARExperience: useARExperience)
            .gesture(
                DragGesture()
                    .onChanged({ value in
                        dragData.startLocation = value.startLocation
                        dragData.translation = value.translation
                    })
                    .onEnded({ endedValue in
                        dragData.endLocation = endedValue.location
                    })
            )
            .edgesIgnoringSafeArea(.all)
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
