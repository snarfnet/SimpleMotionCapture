import AVFoundation
import Vision
import UIKit

@Observable
final class FrontCameraManager: NSObject {
    let session = AVCaptureSession()
    var jointPositions: [Int: CGPoint] = [:]
    var parentIndices: [Int] = []
    var isTracking = false

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "front.camera.queue")
    private let confidenceThreshold: Float = 0.1

    // Vision joints in drawing order
    private let jointNames: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle,
        .neck, .root
    ]

    // Parent index for each joint (matching jointNames order)
    private let parentMap: [Int] = [
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
        -1,  // neck (connected to root via shoulders)
        -1   // root
    ]

    func start() {
        guard !session.isRunning else { return }
        parentIndices = parentMap
        queue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
        isTracking = false
        jointPositions = [:]
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

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, _ in
            guard let self = self,
                  let results = request.results as? [VNHumanBodyPoseObservation],
                  let observation = results.first else {
                DispatchQueue.main.async { self?.isTracking = false }
                return
            }

            var positions: [Int: CGPoint] = [:]
            for (i, name) in self.jointNames.enumerated() {
                guard let point = try? observation.recognizedPoint(name),
                      point.confidence > self.confidenceThreshold else { continue }
                positions[i] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            }

            DispatchQueue.main.async {
                self.jointPositions = positions
                self.isTracking = !positions.isEmpty
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
