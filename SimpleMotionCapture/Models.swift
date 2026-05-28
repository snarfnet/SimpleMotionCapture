import Foundation
import simd

struct RecordedFrame {
    let timestamp: TimeInterval
    let rootWorldPosition: SIMD3<Float>
    let jointLocalTransforms: [simd_float4x4]
}

struct SkeletonInfo {
    let jointNames: [String]
    let parentIndices: [Int]
    let restPoseLocalTransforms: [simd_float4x4]
}

struct Recording: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let frameCount: Int
    let fps: Double
    let skeletonInfo: SkeletonInfo
    let frames: [RecordedFrame]

    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    var durationString: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
