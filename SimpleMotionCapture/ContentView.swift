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

    // Timer settings
    @State private var delaySeconds = 0
    @State private var durationSeconds = 0
    @State private var delayText = ""
    @State private var durationText = ""
    @State private var countdown = 0
    @State private var countdownTimer: Timer?
    @State private var autoStopTimer: Timer?
    @State private var showSettings = false

    private let isEn = Locale.preferredLanguages.first?.hasPrefix("ja") != true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if BodyTrackingManager.isSupported || !isBackCamera {
                // Layer 1: Camera
                cameraLayer
                    .ignoresSafeArea()

                // Layer 2: Skeleton (frequent updates, no layout impact)
                skeletonLayer
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Layer 3: UI Controls (fixed, stable)
                controlsLayer
            } else {
                unsupportedView
            }

            if countdown > 0 {
                countdownOverlay
            }
        }
        .onAppear {
            arManager.onBodyUpdate = { [recorder] body, timestamp in
                DispatchQueue.main.async {
                    recorder.recordFrame3D(body: body, timestamp: timestamp)
                }
            }
            frontManager.onPoseDetected = { [recorder] positions, timestamp in
                DispatchQueue.main.async {
                    recorder.recordFrame2D(positions: positions, timestamp: timestamp)
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

    // MARK: - Camera Layer

    private var cameraLayer: some View {
        ZStack {
            ARTrackingView(manager: arManager)
                .opacity(isBackCamera ? 1 : 0)

            if !isBackCamera {
                CameraPreview(session: frontManager.session)
            }
        }
    }

    // MARK: - Skeleton Layer

    private var skeletonLayer: some View {
        Group {
            if isBackCamera {
                SkeletonView(manager: arManager)
            } else {
                FrontSkeletonView(manager: frontManager)
            }
        }
    }

    // MARK: - Controls Layer

    private var controlsLayer: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomControls
        }
    }

    // MARK: - Countdown Overlay

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            Text("\(countdown)")
                .font(.system(size: 120, weight: .black, design: .monospaced))
                .foregroundColor(.white)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(currentlyTracking ? .green : .red.opacity(0.5))
                    .frame(width: 10, height: 10)
                Text(currentlyTracking
                     ? (isEn ? "Tracking" : "検出中")
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
                    Text(recDurationText)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(recorder.frameCount)f")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    if durationSeconds > 0 {
                        Text("/ \(durationSeconds)s")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }

            Spacer()

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "timer")
                    .font(.system(size: 18))
                    .foregroundColor(hasTimerSettings ? .cyan : .white)
                    .padding(10)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(recorder.isRecording || countdown > 0)

            Button {
                flipCamera()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .disabled(recorder.isRecording || countdown > 0)
            .opacity(recorder.isRecording || countdown > 0 ? 0.3 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.black.opacity(0.6))
    }

    private var hasTimerSettings: Bool {
        delaySeconds > 0 || durationSeconds > 0
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            if showSettings {
                settingsPanel
            }

            if !recorder.isRecording && countdown == 0 {
                Button {
                    initiateRecording()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        Circle()
                            .fill(.red)
                            .frame(width: 64, height: 64)
                        VStack(spacing: 2) {
                            Text(isEn ? "REC" : "録画")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                            if delaySeconds > 0 {
                                Text("\(delaySeconds)s")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                .disabled(!currentlyTracking)
                .opacity(currentlyTracking ? 1 : 0.4)

                if !currentlyTracking {
                    Text(isEn ? "Point camera at a person" : "人物にカメラを向けてください")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else if recorder.isRecording {
                Button {
                    stopRecording()
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

            if let rec = lastRecording, !recorder.isRecording, countdown == 0 {
                VStack(spacing: 10) {
                    Text(isEn
                         ? "\(rec.frameCount) frames / \(rec.durationString) / \(String(format: "%.0f", rec.fps)) fps"
                         : "\(rec.frameCount)フレーム / \(rec.durationString) / \(String(format: "%.0f", rec.fps)) fps")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(spacing: 12) {
                        if rec.is3D {
                            exportButton(label: "BVH") { exportBVH(rec) }
                        }
                        exportButton(label: "JSON") { exportJSON(rec) }
                    }
                }
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(spacing: 14) {
            // Delay
            HStack(spacing: 12) {
                Text(isEn ? "Delay" : "開始まで")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 80, alignment: .leading)

                HStack(spacing: 8) {
                    Button { adjustDelay(-1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                    }

                    TextField("0", text: $delayText)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: delayText) { _, newVal in
                            delaySeconds = max(0, Int(newVal) ?? 0)
                        }

                    Button { adjustDelay(1) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                    }

                    Text(isEn ? "sec" : "秒")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Duration
            HStack(spacing: 12) {
                Text(isEn ? "Duration" : "録画時間")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 80, alignment: .leading)

                HStack(spacing: 8) {
                    Button { adjustDuration(-5) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                    }

                    TextField("0", text: $durationText)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1))
                        .cornerRadius(8)
                        .onChange(of: durationText) { _, newVal in
                            durationSeconds = max(0, Int(newVal) ?? 0)
                        }

                    Button { adjustDuration(5) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.cyan)
                    }

                    Text(isEn ? "sec" : "秒")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Text(durationSeconds == 0
                 ? (isEn ? "Manual stop" : "手動停止")
                 : (isEn ? "Auto-stop after \(durationSeconds)s" : "\(durationSeconds)秒後に自動停止"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .background(.black.opacity(0.85))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    private func adjustDelay(_ delta: Int) {
        delaySeconds = max(0, delaySeconds + delta)
        delayText = delaySeconds == 0 ? "" : "\(delaySeconds)"
    }

    private func adjustDuration(_ delta: Int) {
        durationSeconds = max(0, durationSeconds + delta)
        durationText = durationSeconds == 0 ? "" : "\(durationSeconds)"
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

    // MARK: - Recording Logic

    private func initiateRecording() {
        guard currentlyTracking else { return }
        showSettings = false
        lastRecording = nil

        if delaySeconds > 0 {
            countdown = delaySeconds
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                countdown -= 1
                if countdown <= 0 {
                    countdownTimer?.invalidate()
                    countdownTimer = nil
                    beginRecording()
                }
            }
        } else {
            beginRecording()
        }
    }

    private func beginRecording() {
        if isBackCamera {
            guard let body = arManager.bodyAnchor else { return }
            recorder.startRecording3D(from: body)
        } else {
            recorder.startRecording2D()
        }

        if durationSeconds > 0 {
            autoStopTimer = Timer.scheduledTimer(withTimeInterval: Double(durationSeconds), repeats: false) { _ in
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        if let recording = recorder.stopRecording() {
            lastRecording = recording
        }
    }

    // MARK: - Camera Flip

    private func flipCamera() {
        guard !recorder.isRecording, countdown == 0 else { return }
        lastRecording = nil

        if isBackCamera {
            arManager.stopTracking()
            isBackCamera = false
            frontManager.start()
        } else {
            frontManager.stop()
            isBackCamera = true
            arManager.startTracking()
        }
    }

    // MARK: - Computed

    private var currentlyTracking: Bool {
        isBackCamera ? arManager.isTracking : frontManager.isTracking
    }

    // MARK: - Export

    private func exportBVH(_ recording: Recording) {
        let bvhString = BVHExporter.export(recording)
        guard !bvhString.isEmpty else { return }
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

    private var recDurationText: String {
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
            Text(isEn ? "Requires A12 chip or later." : "A12チップ以降が必要です。")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Skeleton View (ARKit - isolated from main UI)

struct SkeletonView: View {
    let manager: BodyTrackingManager

    var body: some View {
        Canvas { context, size in
            let positions = manager.jointScreenPositions
            let parents = manager.parentIndices

            for (i, parentIdx) in parents.enumerated() {
                guard parentIdx >= 0,
                      let childPos = positions[i],
                      let parentPos = positions[parentIdx] else { continue }
                var path = Path()
                path.move(to: childPos)
                path.addLine(to: parentPos)
                context.stroke(path, with: .color(.cyan.opacity(0.7)), lineWidth: 2.5)
            }
            for (_, pos) in positions {
                let r: CGFloat = 4
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.cyan))
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Front Skeleton View (Vision - isolated from main UI)

struct FrontSkeletonView: View {
    let manager: FrontCameraManager

    var body: some View {
        Canvas { context, size in
            let positions = manager.jointPositions
            let parents = manager.parentIndices

            for (i, parentIdx) in parents.enumerated() {
                guard parentIdx >= 0,
                      let childNorm = positions[i],
                      let parentNorm = positions[parentIdx] else { continue }
                let childPos = CGPoint(x: childNorm.x * size.width, y: childNorm.y * size.height)
                let parentPos = CGPoint(x: parentNorm.x * size.width, y: parentNorm.y * size.height)
                var path = Path()
                path.move(to: childPos)
                path.addLine(to: parentPos)
                context.stroke(path, with: .color(.cyan.opacity(0.7)), lineWidth: 2.5)
            }
            for (_, norm) in positions {
                let pos = CGPoint(x: norm.x * size.width, y: norm.y * size.height)
                let r: CGFloat = 4
                let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.cyan))
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.8)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Activity View

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
