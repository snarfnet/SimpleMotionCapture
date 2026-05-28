import ARKit
import RealityKit
import Combine
import simd

@Observable
final class BodyTrackingManager: NSObject {
    var isTracking = false
    var bodyAnchor: ARBodyAnchor?
    var jointScreenPositions: [Int: CGPoint] = [:]
    var parentIndices: [Int] = []
    var jointCount = 0

    static var isSupported: Bool {
        ARBodyTrackingConfiguration.isSupported
    }

    private var arView: ARView?
    var onBodyUpdate: ((ARBodyAnchor, TimeInterval) -> Void)?

    func getOrCreateARView() -> ARView {
        if let existing = arView { return existing }
        let view = ARView(frame: .zero)
        view.session.delegate = self
        view.environment.background = .cameraFeed()
        self.arView = view
        return view
    }

    func startTracking() {
        guard BodyTrackingManager.isSupported, let arView = arView else { return }
        let config = ARBodyTrackingConfiguration()
        config.automaticSkeletonScaleEstimationEnabled = true
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stopTracking() {
        arView?.session.pause()
        isTracking = false
        bodyAnchor = nil
        jointScreenPositions = [:]
    }

    private func projectJoints(_ body: ARBodyAnchor) {
        guard let arView = arView else { return }
        let skeleton = body.skeleton
        let def = skeleton.definition
        let names = def.jointNames
        let count = names.count

        if parentIndices.isEmpty {
            parentIndices = def.parentIndices.map { Int($0) }
            jointCount = count
        }

        var positions: [Int: CGPoint] = [:]
        for i in 0..<count {
            let modelTransform = skeleton.jointModelTransforms[i]
            let worldMatrix = body.transform * modelTransform
            let worldPos = SIMD3<Float>(worldMatrix.columns.3.x, worldMatrix.columns.3.y, worldMatrix.columns.3.z)
            if let sp = arView.project(worldPos) {
                positions[i] = CGPoint(x: CGFloat(sp.x), y: CGFloat(sp.y))
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.jointScreenPositions = positions
        }
    }
}

extension BodyTrackingManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let body = anchors.compactMap({ $0 as? ARBodyAnchor }).first else { return }

        DispatchQueue.main.async { [weak self] in
            self?.bodyAnchor = body
            self?.isTracking = true
        }

        projectJoints(body)

        let timestamp = session.currentFrame?.timestamp ?? CACurrentMediaTime()
        onBodyUpdate?(body, timestamp)
    }
}
