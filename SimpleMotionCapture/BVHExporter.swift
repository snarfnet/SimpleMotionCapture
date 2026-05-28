import Foundation
import simd

struct BVHExporter {

    static func export(_ recording: Recording) -> String {
        guard let info = recording.skeletonInfo, let frames = recording.frames else { return "" }

        var bvh = "HIERARCHY\n"
        bvh += writeJoint(index: 0, info: info, depth: 0, isRoot: true)
        bvh += "MOTION\n"
        bvh += "Frames: \(frames.count)\n"
        let frameTime = frames.count > 1
            ? recording.duration / Double(frames.count - 1)
            : 1.0 / 60.0
        bvh += String(format: "Frame Time: %.6f\n", frameTime)

        for frame in frames {
            var values: [String] = []

            let pos = frame.rootWorldPosition * 100
            values.append(String(format: "%.4f", pos.x))
            values.append(String(format: "%.4f", pos.y))
            values.append(String(format: "%.4f", pos.z))
            let rootEuler = eulerZXY(from: frame.jointLocalTransforms[0])
            values.append(String(format: "%.4f", rootEuler.z))
            values.append(String(format: "%.4f", rootEuler.x))
            values.append(String(format: "%.4f", rootEuler.y))

            for i in 1..<info.jointNames.count {
                let euler = eulerZXY(from: frame.jointLocalTransforms[i])
                values.append(String(format: "%.4f", euler.z))
                values.append(String(format: "%.4f", euler.x))
                values.append(String(format: "%.4f", euler.y))
            }

            bvh += values.joined(separator: " ") + "\n"
        }

        return bvh
    }

    private static func writeJoint(index: Int, info: SkeletonInfo, depth: Int, isRoot: Bool) -> String {
        let indent = String(repeating: "\t", count: depth)
        let name = sanitize(info.jointNames[index])
        var s = ""

        s += isRoot ? "\(indent)ROOT \(name)\n" : "\(indent)JOINT \(name)\n"
        s += "\(indent){\n"

        let rest = info.restPoseLocalTransforms[index]
        let offset = SIMD3<Float>(rest.columns.3.x, rest.columns.3.y, rest.columns.3.z) * 100
        s += String(format: "\(indent)\tOFFSET %.4f %.4f %.4f\n", offset.x, offset.y, offset.z)

        if isRoot {
            s += "\(indent)\tCHANNELS 6 Xposition Yposition Zposition Zrotation Xrotation Yrotation\n"
        } else {
            s += "\(indent)\tCHANNELS 3 Zrotation Xrotation Yrotation\n"
        }

        let children = info.parentIndices.enumerated().compactMap { (i, parent) in
            parent == index ? i : nil
        }

        if children.isEmpty {
            s += "\(indent)\tEnd Site\n"
            s += "\(indent)\t{\n"
            s += "\(indent)\t\tOFFSET 0.0000 0.0000 0.0000\n"
            s += "\(indent)\t}\n"
        } else {
            for child in children {
                s += writeJoint(index: child, info: info, depth: depth + 1, isRoot: false)
            }
        }

        s += "\(indent)}\n"
        return s
    }

    static func eulerZXY(from m: simd_float4x4) -> SIMD3<Float> {
        let r01 = m.columns.1.x
        let r11 = m.columns.1.y
        let r20 = m.columns.0.z
        let r21 = m.columns.1.z
        let r22 = m.columns.2.z
        let r00 = m.columns.0.x
        let r10 = m.columns.0.y

        let x = asin(clamp(r21, -1, 1))
        let y: Float
        let z: Float

        if abs(cos(x)) > 0.001 {
            y = atan2(-r20, r22)
            z = atan2(-r01, r11)
        } else {
            y = 0
            z = atan2(r10, r00)
        }

        let deg: Float = 180.0 / .pi
        return SIMD3<Float>(x * deg, y * deg, z * deg)
    }

    private static func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        max(lo, min(hi, v))
    }

    private static func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
}
