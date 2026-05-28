import Foundation
import simd

struct JSONExporter {

    struct MocapJSON: Codable {
        let version: String
        let generator: String
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
        let restPose: [JointTransformJSON]
    }

    struct FrameJSON: Codable {
        let t: Double
        let root: [Float]
        let joints: [[Float]]  // quaternion [x,y,z,w] per joint
    }

    struct JointTransformJSON: Codable {
        let position: [Float]
        let rotation: [Float]
    }

    static func export(_ recording: Recording) -> Data? {
        let info = recording.skeletonInfo

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

        let frames = recording.frames.map { frame -> FrameJSON in
            let joints = frame.jointLocalTransforms.map { t -> [Float] in
                let q = simd_quatf(t)
                return [q.imag.x, q.imag.y, q.imag.z, q.real]
            }
            return FrameJSON(
                t: frame.timestamp,
                root: [frame.rootWorldPosition.x, frame.rootWorldPosition.y, frame.rootWorldPosition.z],
                joints: joints
            )
        }

        let json = MocapJSON(
            version: "1.0",
            generator: "SimpleMotionCapture",
            fps: recording.fps,
            duration: recording.duration,
            frameCount: recording.frameCount,
            date: ISO8601DateFormatter().string(from: recording.date),
            skeleton: skeleton,
            frames: frames
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(json)
    }
}
