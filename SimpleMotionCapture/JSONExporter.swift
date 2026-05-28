import Foundation
import simd

struct JSONExporter {

    struct MocapJSON: Codable {
        let version: String
        let generator: String
        let mode: String  // "3D" or "2D"
        let fps: Double
        let duration: Double
        let frameCount: Int
        let date: String
        let skeleton: SkeletonJSON
        let frames: [FrameJSON]
    }

    struct SkeletonJSON: Codable {
        let jointNames: [String]
        let parentIndices: [Int]
        let restPose: [JointTransformJSON]?  // 3D only
    }

    struct FrameJSON: Codable {
        let t: Double
        let root: [Float]?        // 3D: world position
        let joints3D: [[Float]]?  // 3D: quaternion [x,y,z,w]
        let joints2D: [[Float?]]? // 2D: [x, y] normalized
    }

    struct JointTransformJSON: Codable {
        let position: [Float]
        let rotation: [Float]
    }

    static func export(_ recording: Recording) -> Data? {
        if recording.is3D {
            return export3D(recording)
        } else {
            return export2D(recording)
        }
    }

    private static func export3D(_ recording: Recording) -> Data? {
        guard let info = recording.skeletonInfo, let frames = recording.frames else { return nil }

        let restPose = info.restPoseLocalTransforms.map { t -> JointTransformJSON in
            let pos = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            let q = simd_quatf(t)
            return JointTransformJSON(
                position: [pos.x, pos.y, pos.z],
                rotation: [q.imag.x, q.imag.y, q.imag.z, q.real]
            )
        }

        let skeleton = SkeletonJSON(
            jointNames: info.jointNames,
            parentIndices: info.parentIndices,
            restPose: restPose
        )

        let jsonFrames = frames.map { frame -> FrameJSON in
            let joints = frame.jointLocalTransforms.map { t -> [Float] in
                let q = simd_quatf(t)
                return [q.imag.x, q.imag.y, q.imag.z, q.real]
            }
            return FrameJSON(
                t: frame.timestamp,
                root: [frame.rootWorldPosition.x, frame.rootWorldPosition.y, frame.rootWorldPosition.z],
                joints3D: joints,
                joints2D: nil
            )
        }

        return encode(MocapJSON(
            version: "1.0", generator: "SimpleMotionCapture", mode: "3D",
            fps: recording.fps, duration: recording.duration,
            frameCount: recording.frameCount,
            date: ISO8601DateFormatter().string(from: recording.date),
            skeleton: skeleton, frames: jsonFrames
        ))
    }

    private static func export2D(_ recording: Recording) -> Data? {
        guard let info = recording.skeletonInfo2D, let frames = recording.frames2D else { return nil }

        let skeleton = SkeletonJSON(
            jointNames: info.jointNames,
            parentIndices: info.parentIndices,
            restPose: nil
        )

        let jsonFrames = frames.map { frame -> FrameJSON in
            let joints = frame.jointPositions.map { p -> [Float?] in
                guard let p = p else { return [nil, nil] }
                return [Float(p.x), Float(p.y)]
            }
            return FrameJSON(
                t: frame.timestamp,
                root: nil,
                joints3D: nil,
                joints2D: joints
            )
        }

        return encode(MocapJSON(
            version: "1.0", generator: "SimpleMotionCapture", mode: "2D",
            fps: recording.fps, duration: recording.duration,
            frameCount: recording.frameCount,
            date: ISO8601DateFormatter().string(from: recording.date),
            skeleton: skeleton, frames: jsonFrames
        ))
    }

    private static func encode(_ json: MocapJSON) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(json)
    }
}
