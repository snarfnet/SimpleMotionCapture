import ARKit

@Observable
final class MotionRecorder {
    var isRecording = false
    var frameCount = 0
    var recordingDuration: TimeInterval = 0
    var is3DRecording = true

    private var frames3D: [RecordedFrame] = []
    private var frames2D: [RecordedFrame2D] = []
    private var skeletonInfo: SkeletonInfo?
    private var startTime: TimeInterval?

    // MARK: - 3D Recording (ARKit)

    func startRecording3D(from body: ARBodyAnchor) {
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
            jointNames: def.jointNames,
            parentIndices: def.parentIndices.map { Int($0) },
            restPoseLocalTransforms: restTransforms
        )

        frames3D = []
        frames2D = []
        frameCount = 0
        recordingDuration = 0
        startTime = nil
        is3DRecording = true
        isRecording = true
    }

    func recordFrame3D(body: ARBodyAnchor, timestamp: TimeInterval) {
        guard isRecording, is3DRecording else { return }

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

        frames3D.append(frame)
        frameCount = frames3D.count
        recordingDuration = elapsed
    }

    // MARK: - 2D Recording (Vision)

    func startRecording2D() {
        frames3D = []
        frames2D = []
        skeletonInfo = nil
        frameCount = 0
        recordingDuration = 0
        startTime = nil
        is3DRecording = false
        isRecording = true
    }

    func recordFrame2D(positions: [CGPoint?], timestamp: TimeInterval) {
        guard isRecording, !is3DRecording else { return }

        if startTime == nil { startTime = timestamp }
        let elapsed = timestamp - (startTime ?? timestamp)

        let frame = RecordedFrame2D(
            timestamp: elapsed,
            jointPositions: positions
        )

        frames2D.append(frame)
        frameCount = frames2D.count
        recordingDuration = elapsed
    }

    // MARK: - Stop

    func stopRecording() -> Recording? {
        isRecording = false

        if is3DRecording {
            guard let info = skeletonInfo, !frames3D.isEmpty else { return nil }
            let duration = recordingDuration
            let fps = frames3D.count > 1 ? Double(frames3D.count - 1) / max(duration, 0.001) : 60.0
            return Recording(
                date: Date(),
                duration: duration,
                frameCount: frames3D.count,
                fps: min(fps, 120),
                is3D: true,
                skeletonInfo: info,
                frames: frames3D
            )
        } else {
            guard !frames2D.isEmpty else { return nil }
            let duration = recordingDuration
            let fps = frames2D.count > 1 ? Double(frames2D.count - 1) / max(duration, 0.001) : 30.0
            return Recording(
                date: Date(),
                duration: duration,
                frameCount: frames2D.count,
                fps: min(fps, 120),
                is3D: false,
                skeletonInfo2D: SkeletonInfo2D(
                    jointNames: FrontCameraManager.jointNames,
                    parentIndices: FrontCameraManager.parentMap
                ),
                frames2D: frames2D
            )
        }
    }
}
