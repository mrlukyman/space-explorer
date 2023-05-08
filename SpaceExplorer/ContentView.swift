import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    @State private var selectedElement = 0
    @State private var selectedElementModel = "empty"
    @State private var isLoading = true
    
    let spaceModelOptions = [ "Cosmonaut suit", "Lunar rover US", "Jamestown base"]
    let spaceModels = ["CosmonautSuit_en.reality", "LunarRover_English.reality", "hab_en.reality"]
    let imageNames = ["cosmonaut", "rover", "base"]
    
    var body: some View {
        if isLoading {
           VStack {
               Text("Space Explorer")
                   .font(.system(size: 30))
                   .fontWeight(.bold)
                   .foregroundColor(.white)
               Text("Loading...")
                   .font(.system(size: 15))
                   .foregroundColor(.white)
           }
           .frame(maxWidth: .infinity, maxHeight: .infinity)
           .background(Color.black.opacity(0.8))
           .edgesIgnoringSafeArea(.all)
           .onAppear {
               DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                   isLoading = false
               }
           }
        } else {
            ZStack {
                ARViewContainer(elementModel: $selectedElementModel)
                    .edgesIgnoringSafeArea(.all) // Make the camera view fullscreen
                
                VStack {
                    Spacer()
                    Text("Pick a model")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(spaceModelOptions.indices, id: \.self) { index in
                                    VStack {
                                        Button(action: {
                                            selectedElement = index
                                            selectedElementModel = spaceModels[index]
                                        }) {
                                            Image(imageNames[index])
                                                .resizable()
                                                .frame(width: 100, height: 100)
                                                .aspectRatio(contentMode: .fit)
                                        }
                                        Text(spaceModelOptions[index])
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, (26))
                        }
                    .frame(height: 140)
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var elementModel: String
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Enable horizontal plane detection
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        arView.session.run(configuration)
        
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.selectedModel = elementModel
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARViewContainer
        var arView: ARView?

        var selectedModel: String? {
            didSet {
                guard let arView = arView else { return }
                arView.scene.anchors.removeAll()

                if let modelName = selectedModel, let modelEntity = try? Entity.load(named: modelName) {
                    // Apply scale to the modelEntity
                    modelEntity.scale = SIMD3<Float>(5, 5, 5)

                    // Get the camera transform
                    guard (arView.session.currentFrame?.camera.transform) != nil else {
                        return
                    }

                    // Perform a raycast to find the floor
                    let query = ARRaycastQuery(origin: arView.cameraTransform.translation,
                                               direction: SIMD3<Float>(-arView.cameraTransform.matrix.columns.2.x, -arView.cameraTransform.matrix.columns.2.y, -arView.cameraTransform.matrix.columns.2.z),
                                               allowing: .estimatedPlane,
                                               alignment: .horizontal)
                    let raycastResults = arView.session.raycast(query)

                    if let result = raycastResults.first {
                        // Create an AnchorEntity at the raycast intersection with the floor
                        let anchor = AnchorEntity(world: SIMD3<Float>(result.worldTransform.columns.3.x, result.worldTransform.columns.3.y, result.worldTransform.columns.3.z))
                        anchor.addChild(modelEntity)
                        arView.scene.addAnchor(anchor)
                    }
                }
            }
        }

        init(_ parent: ARViewContainer) {
            self.parent = parent
            super.init()
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
           guard let arView = arView, let modelName = selectedModel, let modelEntity = try? Entity.load(named: modelName) else { return }

           if arView.scene.anchors.count == 0 {
               // Check if the added anchor is an ARPlaneAnchor
               for anchor in anchors {
                   if let planeAnchor = anchor as? ARPlaneAnchor {
                       // Create an AnchorEntity at the plane's position
                       let anchorEntity = AnchorEntity(anchor: planeAnchor)
                       anchorEntity.addChild(modelEntity)
                       arView.scene.addAnchor(anchorEntity)

                       // Stop plane detection and updating the session after placing the model
                       let configuration = ARWorldTrackingConfiguration()
                       configuration.planeDetection = []
                       arView.session.run(configuration, options: [])

                       break
                   }
               }
           }
        }
    }
}
