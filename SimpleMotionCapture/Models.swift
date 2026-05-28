import Foundation
import simd

// MARK: - 3D (ARKit)

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

// MARK: - 2D (Vision)

struct RecordedFrame2D {
    let timestamp: TimeInterval
    let jointPositions: [CGPoint?]  // normalized 0-1, nil if not detected
}

struct SkeletonInfo2D {
    let jointNames: [String]
    let parentIndices: [Int]
}

// MARK: - Recording

struct Recording: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let frameCount: Int
    let fps: Double
    let is3D: Bool

    // 3D data (ARKit)
    var skeletonInfo: SkeletonInfo?
    var frames: [RecordedFrame]?

    // 2D data (Vision)
    var skeletonInfo2D: SkeletonInfo2D?
    var frames2D: [RecordedFrame2D]?

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
