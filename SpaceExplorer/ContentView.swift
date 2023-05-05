import SwiftUI
import RealityKit
import ARKit

struct ContentView : View {
    @State private var selectedElement = 0
    @State private var selectedElementModel = "Animated_Moon.usdz"
    @State private var isSoundEnabled = true
    
    let spaceModelOptions = ["Pick an item to view", "Cosmonaut suit", "Lunar rover US", "Jamestown lunar base (habitat)"]
    let spaceModels = ["Animated_Moon.usdz", "CosmonautSuit_en.reality", "LunarRover_English.reality", "hab_en.reality"]
    
    var body: some View {
        ZStack {
            ARViewContainer(elementModel: $selectedElementModel)
                .edgesIgnoringSafeArea(.all) // Make the camera view fullscreen
            
            VStack {
                Spacer()
                Picker(selection: $selectedElement, label: Text("Select Element")) {
                    ForEach(spaceModelOptions.indices, id: \.self) { index in
                        Text(spaceModelOptions[index]).tag(index)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .background(Color.black.opacity(0.8)) // Change to dark mode
                .frame(height: 100) // Adjust the height of the picker
                .padding(.horizontal, 0) // Set horizontal padding to 0
                .edgesIgnoringSafeArea(.bottom) // Ignore safe area at the bottom
                .onChange(of: selectedElement) { newValue in
                    selectedElementModel = spaceModels[newValue]
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var elementModel: String
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        
        // Add this code block to set the initial object
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            context.coordinator.selectedModel = elementModel
        }
        
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
                    // Get the camera transform
                    guard let cameraTransform = arView.session.currentFrame?.camera.transform else {
                        return
                    }
                    
                    // Create a translation relative to the camera position
                    let translation = simd_make_float4(0, 0, -0.5, 1)
                    let position = simd_mul(cameraTransform, translation)
                    
                    // Create an AnchorEntity at the new position
                    let anchor = AnchorEntity(world: SIMD3<Float>(position.x, position.y, position.z))
                    anchor.addChild(modelEntity)
                    arView.scene.addAnchor(anchor)
                }
            }
        }
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
            super.init()
        }
    }
}
