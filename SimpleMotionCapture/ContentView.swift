import SwiftUI
import ARKit

struct ContentView: View {
    @State private var manager = BodyTrackingManager()
    @State private var recorder = MotionRecorder()
    @State private var lastRecording: Recording?
    @State private var showExport = false
    @State private var exportItems: [Any] = []
    @State private var showUnsupported = false

    private let isEn = Locale.preferredLanguages.first?.hasPrefix("ja") != true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if BodyTrackingManager.isSupported {
                trackingView
            } else {
                unsupportedView
            }
        }
        .onAppear {
            if BodyTrackingManager.isSupported {
                manager.onBodyUpdate = { [recorder] body, timestamp in
                    DispatchQueue.main.async {
                        recorder.recordFrame(body: body, timestamp: timestamp)
                    }
                }
                manager.startTracking()
            }
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
            ARTrackingView(manager: manager)
                .ignoresSafeArea()

            // Skeleton overlay
            SkeletonOverlay(
                positions: manager.jointScreenPositions,
                parentIndices: manager.parentIndices
            )
            .ignoresSafeArea()

            VStack {
                // Top status bar
                topBar

                Spacer()

                // Bottom controls
                bottomControls
            }
        }
    }

    private var topBar: some View {
        HStack {
            // Tracking status
            HStack(spacing: 6) {
                Circle()
                    .fill(manager.isTracking ? .green : .red.opacity(0.5))
                    .frame(width: 10, height: 10)
                Text(manager.isTracking
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
                        .opacity(pulseOpacity)
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.black.opacity(0.5))
    }

    @State private var pulsePhase = false

    private var pulseOpacity: Double {
        // Simple blink indicator
        recorder.isRecording ? (Int(Date().timeIntervalSince1970 * 2) % 2 == 0 ? 1 : 0.3) : 0
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if !recorder.isRecording {
                // Record button
                Button {
                    guard let body = manager.bodyAnchor else { return }
                    recorder.startRecording(from: body)
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        Circle()
                            .fill(.red)
                            .frame(width: 64, height: 64)
                        Text(isEn ? "REC" : "録画")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .disabled(!manager.isTracking)
                .opacity(manager.isTracking ? 1 : 0.4)

                if !manager.isTracking {
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

    // MARK: - Helpers

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

// MARK: - Skeleton Overlay

struct SkeletonOverlay: View {
    let positions: [Int: CGPoint]
    let parentIndices: [Int]

    var body: some View {
        Canvas { context, size in
            // Lines (child -> parent)
            for (i, parentIdx) in parentIndices.enumerated() {
                guard parentIdx >= 0,
                      let childPos = positions[i],
                      let parentPos = positions[parentIdx] else { continue }
                var path = Path()
                path.move(to: childPos)
                path.addLine(to: parentPos)
                context.stroke(path, with: .color(.cyan.opacity(0.7)), lineWidth: 2.5)
            }

            // Joints
            for (_, pos) in positions {
                let r: CGFloat = 4
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.cyan))
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
