import SwiftUI
import ARKit

struct ContentView: View {
    @State private var arManager = BodyTrackingManager()
    @State private var frontManager = FrontCameraManager()
    @State private var recorder = MotionRecorder()
    @State private var lastRecording: Recording?
    @State private var showExport = false
    @State private var exportItems: [Any] = []
    @State private var isBackCamera = true

    private let isEn = Locale.preferredLanguages.first?.hasPrefix("ja") != true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if BodyTrackingManager.isSupported || !isBackCamera {
                trackingView
            } else {
                unsupportedView
            }
        }
        .onAppear {
            arManager.onBodyUpdate = { [recorder] body, timestamp in
                DispatchQueue.main.async {
                    recorder.recordFrame(body: body, timestamp: timestamp)
                }
            }
            arManager.startTracking()
        }
        .sheet(isPresented: $showExport) {
            if !exportItems.isEmpty {
                ActivityView(items: exportItems)
            }
        }
    }

    // MARK: - Tracking View

    private var trackingView: some View {
        ZStack {
            // Camera views
            if isBackCamera {
                ARTrackingView(manager: arManager)
                    .ignoresSafeArea()

                SkeletonOverlay(
                    positions: arManager.jointScreenPositions,
                    parentIndices: arManager.parentIndices,
                    color: .cyan
                )
                .ignoresSafeArea()
            } else {
                CameraPreview(session: frontManager.session)
                    .ignoresSafeArea()

                // Front camera: Vision 2D skeleton (normalized 0-1 coords)
                FrontSkeletonOverlay(
                    positions: frontManager.jointPositions,
                    parentIndices: frontManager.parentIndices
                )
                .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                bottomControls
            }
        }
    }

    private var topBar: some View {
        HStack {
            // Tracking status
            HStack(spacing: 6) {
                Circle()
                    .fill(currentlyTracking ? .green : .red.opacity(0.5))
                    .frame(width: 10, height: 10)
                Text(currentlyTracking
                     ? (isEn ? "Body Detected" : "検出中")
                     : (isEn ? "No Body" : "未検出"))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            if recorder.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                    Text("REC")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    Text(durationText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(recorder.frameCount)f")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Camera flip button
            Button {
                flipCamera()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(recorder.isRecording)
            .opacity(recorder.isRecording ? 0.3 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.black.opacity(0.5))
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Camera mode indicator
            if !isBackCamera {
                Text(isEn ? "Front Camera (2D Preview)" : "前面カメラ（2Dプレビュー）")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .cornerRadius(8)
            }

            if !recorder.isRecording {
                // Record button (back camera only)
                Button {
                    if isBackCamera {
                        guard let body = arManager.bodyAnchor else { return }
                        recorder.startRecording(from: body)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        Circle()
                            .fill(isBackCamera ? .red : .gray)
                            .frame(width: 64, height: 64)
                        Text(isEn ? "REC" : "録画")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!canRecord)
                .opacity(canRecord ? 1 : 0.4)

                if !isBackCamera {
                    Text(isEn ? "Switch to back camera to record 3D motion" : "3D録画は背面カメラに切り替えてください")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                } else if !arManager.isTracking {
                    Text(isEn ? "Point camera at a person" : "人物にカメラを向けてください")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                // Stop button
                Button {
                    if let recording = recorder.stopRecording() {
                        lastRecording = recording
                    }
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 20, height: 20)
                        Text(isEn ? "STOP" : "停止")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(.red)
                    .cornerRadius(16)
                }
            }

            // Export buttons (after recording)
            if let rec = lastRecording, !recorder.isRecording {
                VStack(spacing: 10) {
                    Text(isEn
                         ? "\(rec.frameCount) frames / \(rec.durationString) / \(String(format: "%.0f", rec.fps)) fps"
                         : "\(rec.frameCount)フレーム / \(rec.durationString) / \(String(format: "%.0f", rec.fps)) fps")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 12) {
                        exportButton(label: "BVH") {
                            exportBVH(rec)
                        }
                        exportButton(label: "JSON") {
                            exportJSON(rec)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 40)
    }

    private func exportButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(.cyan)
                .cornerRadius(12)
        }
    }

    // MARK: - Camera Flip

    private func flipCamera() {
        guard !recorder.isRecording else { return }

        if isBackCamera {
            // Switch to front camera
            arManager.stopTracking()
            frontManager.start()
            isBackCamera = false
        } else {
            // Switch to back camera
            frontManager.stop()
            arManager.startTracking()
            isBackCamera = true
        }
    }

    // MARK: - Computed

    private var currentlyTracking: Bool {
        isBackCamera ? arManager.isTracking : frontManager.isTracking
    }

    private var canRecord: Bool {
        isBackCamera && arManager.isTracking
    }

    // MARK: - Export

    private func exportBVH(_ recording: Recording) {
        let bvhString = BVHExporter.export(recording)
        let fileName = "mocap_\(fileTimestamp()).bvh"
        if let url = saveToTemp(data: Data(bvhString.utf8), fileName: fileName) {
            exportItems = [url]
            showExport = true
        }
    }

    private func exportJSON(_ recording: Recording) {
        guard let data = JSONExporter.export(recording) else { return }
        let fileName = "mocap_\(fileTimestamp()).json"
        if let url = saveToTemp(data: data, fileName: fileName) {
            exportItems = [url]
            showExport = true
        }
    }

    private func saveToTemp(data: Data, fileName: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func fileTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }

    private var durationText: String {
        let mins = Int(recorder.recordingDuration) / 60
        let secs = Int(recorder.recordingDuration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Unsupported

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(isEn ? "Body Tracking Not Supported" : "ボディトラッキング非対応")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(isEn
                 ? "This device does not support ARKit Body Tracking.\nRequires A12 chip or later."
                 : "このデバイスはARKitボディトラッキングに対応していません。\nA12チップ以降が必要です。")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Skeleton Overlay (ARKit - screen coordinates)

struct SkeletonOverlay: View {
    let positions: [Int: CGPoint]
    let parentIndices: [Int]
    var color: Color = .cyan

    var body: some View {
        Canvas { context, size in
            for (i, parentIdx) in parentIndices.enumerated() {
                guard parentIdx >= 0,
                      let childPos = positions[i],
                      let parentPos = positions[parentIdx] else { continue }
                var path = Path()
                path.move(to: childPos)
                path.addLine(to: parentPos)
                context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 2.5)
            }
            for (_, pos) in positions {
                let r: CGFloat = 4
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color))
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Front Skeleton Overlay (Vision - normalized 0-1 coordinates)

struct FrontSkeletonOverlay: View {
    let positions: [Int: CGPoint]
    let parentIndices: [Int]

    var body: some View {
        Canvas { context, size in
            for (i, parentIdx) in parentIndices.enumerated() {
                guard parentIdx >= 0,
                      let childNorm = positions[i],
                      let parentNorm = positions[parentIdx] else { continue }
                let childPos = CGPoint(x: childNorm.x * size.width, y: childNorm.y * size.height)
                let parentPos = CGPoint(x: parentNorm.x * size.width, y: parentNorm.y * size.height)
                var path = Path()
                path.move(to: childPos)
                path.addLine(to: parentPos)
                context.stroke(path, with: .color(.green.opacity(0.7)), lineWidth: 2.5)
            }
            for (_, norm) in positions {
                let pos = CGPoint(x: norm.x * size.width, y: norm.y * size.height)
                let r: CGFloat = 4
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.green))
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Activity View (Share Sheet)

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
