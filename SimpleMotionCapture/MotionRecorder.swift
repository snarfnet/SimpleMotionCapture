import ARKit

@Observable
final class MotionRecorder {
    var isRecording = false
    var frameCount = 0
    var recordingDuration: TimeInterval = 0

    private var frames: [RecordedFrame] = []
    private var skeletonInfo: SkeletonInfo?
    private var startTime: TimeInterval?

    func startRecording(from body: ARBodyAnchor) {
        let skeleton = body.skeleton
        let def = skeleton.definition
        let jointCount = def.jointNames.count

        let restTransforms: [simd_float4x4]
        if let neutral = def.neutralBodySkeleton3D {
            restTransforms = (0..<jointCount).map { neutral.jointLocalTransforms[$0] }
        } else {
            restTransforms = (0..<jointCount).map { skeleton.jointLocalTransforms[$0] }
        }

        skeletonInfo = SkeletonInfo(
            jointNames: def.jointNames.map { $0.rawValue },
            parentIndices: def.parentIndices.map { Int($0) },
            restPoseLocalTransforms: restTransforms
        )

        frames = []
        frameCount = 0
        recordingDuration = 0
        startTime = nil
        isRecording = true
    }

    func recordFrame(body: ARBodyAnchor, timestamp: TimeInterval) {
        guard isRecording else { return }

        if startTime == nil { startTime = timestamp }
        let elapsed = timestamp - (startTime ?? timestamp)

        let skeleton = body.skeleton
        let jointCount = skeleton.definition.jointNames.count
        let localTransforms = (0..<jointCount).map { skeleton.jointLocalTransforms[$0] }

        let rootPos = SIMD3<Float>(
            body.transform.columns.3.x,
            body.transform.columns.3.y,
            body.transform.columns.3.z
        )

        let frame = RecordedFrame(
            timestamp: elapsed,
            rootWorldPosition: rootPos,
            jointLocalTransforms: localTransforms
        )

        frames.append(frame)
        frameCount = frames.count
        recordingDuration = elapsed
    }

    func stopRecording() -> Recording? {
        isRecording = false
        guard let info = skeletonInfo, !frames.isEmpty else { return nil }

        let duration = recordingDuration
        let fps = frames.count > 1 ? Double(frames.count - 1) / max(duration, 0.001) : 60.0

        return Recording(
            date: Date(),
            duration: duration,
            frameCount: frames.count,
            fps: min(fps, 120),
            skeletonInfo: info,
            frames: frames
        )
    }
}
