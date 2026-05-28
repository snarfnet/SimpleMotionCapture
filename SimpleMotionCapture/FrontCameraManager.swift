import AVFoundation
import Vision
import UIKit

@Observable
final class FrontCameraManager: NSObject {
    let session = AVCaptureSession()
    var jointPositions: [Int: CGPoint] = [:]
    var parentIndices: [Int] = []
    var isTracking = false

    var onPoseDetected: (([CGPoint?], TimeInterval) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "front.camera.queue")
    private let confidenceThreshold: Float = 0.1
    private var isConfigured = false

    static let jointNames: [String] = [
        "nose", "leftEye", "rightEye", "leftEar", "rightEar",
        "leftShoulder", "rightShoulder",
        "leftElbow", "rightElbow",
        "leftWrist", "rightWrist",
        "leftHip", "rightHip",
        "leftKnee", "rightKnee",
        "leftAnkle", "rightAnkle",
        "neck", "root"
    ]

    private let visionJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle,
        .neck, .root
    ]

    static let parentMap: [Int] = [
        17,  // nose -> neck
        0,   // leftEye -> nose
        0,   // rightEye -> nose
        1,   // leftEar -> leftEye
        2,   // rightEar -> rightEye
        17,  // leftShoulder -> neck
        17,  // rightShoulder -> neck
        5,   // leftElbow -> leftShoulder
        6,   // rightElbow -> rightShoulder
        7,   // leftWrist -> leftElbow
        8,   // rightWrist -> rightElbow
        18,  // leftHip -> root
        18,  // rightHip -> root
        11,  // leftKnee -> leftHip
        12,  // rightKnee -> rightHip
        13,  // leftAnkle -> leftKnee
        14,  // rightAnkle -> rightKnee
        -1,  // neck
        -1   // root
    ]

    func start() {
        parentIndices = FrontCameraManager.parentMap
        queue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.configureSession()
                self.isConfigured = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
        DispatchQueue.main.async { [weak self] in
            self?.isTracking = false
            self?.jointPositions = [:]
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            connection.isVideoMirrored = true
        }

        session.commitConfiguration()
    }
}

extension FrontCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, _ in
            guard let self = self,
                  let results = request.results as? [VNHumanBodyPoseObservation],
                  let observation = results.first else {
                DispatchQueue.main.async { [weak self] in self?.isTracking = false }
                return
            }

            var positions: [Int: CGPoint] = [:]
            var posArray: [CGPoint?] = Array(repeating: nil, count: self.visionJoints.count)

            for (i, name) in self.visionJoints.enumerated() {
                guard let point = try? observation.recognizedPoint(name),
                      point.confidence > self.confidenceThreshold else { continue }
                let p = CGPoint(x: point.location.x, y: 1 - point.location.y)
                positions[i] = p
                posArray[i] = p
            }

            DispatchQueue.main.async {
                self.jointPositions = positions
                self.isTracking = !positions.isEmpty
            }

            self.onPoseDetected?(posArray, timestamp)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
