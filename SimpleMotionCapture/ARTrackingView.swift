import SwiftUI
import ARKit
import RealityKit

struct ARTrackingView: UIViewRepresentable {
    let manager: BodyTrackingManager

    func makeUIView(context: Context) -> ARView {
        manager.getOrCreateARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
