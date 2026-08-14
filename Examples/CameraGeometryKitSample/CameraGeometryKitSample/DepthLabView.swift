import CameraGeometryKit
import CoreVideo
import SwiftUI

struct DepthSnapshot: Sendable {
    let frameID: UInt64
    let colorSize: CGSize
    let depthSize: CGSize?
    let centerDepthMeters: Float?
    let colorRotation: CGFloat
    let depthRotation: CGFloat?
    let columns: Int
    let rows: Int
    let meters: [Float?]
}

@MainActor
final class DepthLabModel: ObservableObject {
    @Published private(set) var state = CameraCaptureSessionState(
        isConfigured: false,
        isRunning: false,
        cameraPosition: .unspecified,
        deviceUniqueID: nil,
        deviceName: nil
    )
    @Published private(set) var snapshot: DepthSnapshot?
    @Published private(set) var errorMessage: String?

    let devices: [CameraDeviceInfo]
    let camera = CameraCaptureSession(
        sessionPreset: .high,
        depthConfiguration: CameraDepthCaptureConfiguration(isFilteringEnabled: false)
    )

    init() {
        devices = CameraDeviceDiscovery.availableDeviceInfos().filter(\.supportsDepthData)
    }

    private var initialDevice: CameraDeviceInfo? {
        devices.first(where: { $0.position == .back }) ?? devices.first
    }

    func run() async {
        guard let initialDevice else {
            errorMessage = "No depth-capable camera discovered."
            return
        }

        do {
            state = try await camera.start(request: CameraDeviceRequest(device: initialDevice))
            errorMessage = nil
            guard let stream = camera.synchronizedFrameStream else {
                errorMessage = "Synchronized depth stream is unavailable."
                return
            }

            let consumer = Task.detached(priority: .utility) { [weak self] in
                var iterator = stream.frames.makeAsyncIterator()
                let clock = ContinuousClock()
                var lastPublish = clock.now - .seconds(2)

                while !Task.isCancelled, let frame = await iterator.next() {
                    let now = clock.now
                    guard lastPublish.duration(to: now) >= .milliseconds(500) else { continue }
                    lastPublish = now
                    let value = Self.makeSnapshot(frame)
                    await MainActor.run { [weak self] in self?.snapshot = value }
                }
            }

            await withTaskCancellationHandler {
                await consumer.value
            } onCancel: {
                consumer.cancel()
            }
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }

        await camera.stop()
        if !Task.isCancelled { state = camera.currentState }
    }

    func switchCameraPosition() async {
        let target: CameraPosition = state.cameraPosition == .front ? .back : .front
        guard let targetDevice = devices.first(where: { $0.position == target }) else {
            errorMessage = "No depth-capable \(target.rawValue) camera is available."
            return
        }
        await selectDevice(targetDevice)
    }

    func selectDevice(_ device: CameraDeviceInfo) async {
        guard state.isRunning else { return }
        do {
            state = try await camera.setCamera(CameraDeviceRequest(device: device))
            snapshot = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canSwitchPosition: Bool {
        let target: CameraPosition = state.cameraPosition == .front ? .back : .front
        return devices.contains(where: { $0.position == target })
    }

    nonisolated private static func makeSnapshot(_ frame: CameraSynchronizedFrame) -> DepthSnapshot {
        let depth = frame.depth
        let sampled = depth.map(sampleDepth) ?? (5, 3, Array(repeating: Optional<Float>.none, count: 15), nil)
        return DepthSnapshot(
            frameID: frame.color.id.rawValue,
            colorSize: frame.color.geometry.pixelSize,
            depthSize: depth?.geometry.pixelSize,
            centerDepthMeters: sampled.3,
            colorRotation: frame.color.geometry.appliedVideoRotationAngle,
            depthRotation: depth?.geometry.appliedVideoRotationAngle,
            columns: sampled.0,
            rows: sampled.1,
            meters: sampled.2
        )
    }

    nonisolated private static func sampleDepth(
        _ frame: CameraDepthFrame
    ) -> (Int, Int, [Float?], Float?) {
        let map = frame.depthMap
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(map) else {
            return (5, 3, Array(repeating: nil, count: 15), nil)
        }

        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(map)
        let pixelFormat = CVPixelBufferGetPixelFormatType(map)
        let columns = 5
        let rows = 3

        func depthAt(x: Int, y: Int) -> Float? {
            let rowBase = base.advanced(by: y * bytesPerRow)
            let value: Float
            switch pixelFormat {
            case kCVPixelFormatType_DepthFloat32:
                value = rowBase.assumingMemoryBound(to: Float.self)[x]
            case kCVPixelFormatType_DepthFloat16:
                value = Float(rowBase.assumingMemoryBound(to: Float16.self)[x])
            default:
                return nil
            }
            return value.isFinite && value > 0 ? value : nil
        }

        var values: [Float?] = []
        values.reserveCapacity(columns * rows)
        for row in 0..<rows {
            let y = min(height - 1, ((row * 2 + 1) * height) / (rows * 2))
            for column in 0..<columns {
                let x = min(width - 1, ((column * 2 + 1) * width) / (columns * 2))
                values.append(depthAt(x: x, y: y))
            }
        }

        return (columns, rows, values, depthAt(x: width / 2, y: height / 2))
    }
}

struct DepthLabView: View {
    @StateObject private var model = DepthLabModel()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color.black
                    LabCameraPreview(camera: model.camera, deviceUniqueID: model.state.deviceUniqueID)

                    if let snapshot = model.snapshot,
                       let depthSize = snapshot.depthSize {
                        depthGrid(snapshot: snapshot, depthSize: depthSize, viewportSize: proxy.size)
                    }

                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 2).frame(width: 30, height: 30)
                        Rectangle().fill(Color.white).frame(width: 42, height: 1)
                        Rectangle().fill(Color.white).frame(width: 1, height: 42)
                    }
                    .allowsHitTesting(false)

                    VStack {
                        HStack(alignment: .top) {
                            LabHUD("SYNCHRONIZED DEPTH") {
                                Text(model.state.deviceName ?? "starting depth camera…")
                                if let snapshot = model.snapshot {
                                    Text("frame: \(snapshot.frameID)")
                                    Text("RGB: \(Int(snapshot.colorSize.width)) × \(Int(snapshot.colorSize.height))")
                                    Text("depth: \(snapshot.depthSize.map { "\(Int($0.width)) × \(Int($0.height))" } ?? "dropped")")
                                    Text("center: \(snapshot.centerDepthMeters.map { String(format: "%.2f m", $0) } ?? "—")")
                                    Text("rotation: \(String(format: "%.1f", snapshot.colorRotation))° / \(snapshot.depthRotation.map { String(format: "%.1f°", $0) } ?? "—")")
                                } else {
                                    Text("waiting for RGB + depth…")
                                }
                                if let error = model.errorMessage {
                                    Text(error).foregroundStyle(Color.red)
                                }
                            }
                            Spacer()
                            VStack(spacing: 8) {
                                LabCameraSwitchButton(
                                    position: model.state.cameraPosition,
                                    enabled: model.state.isRunning && model.canSwitchPosition
                                ) {
                                    Task { await model.switchCameraPosition() }
                                }
                                depthDeviceMenu
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .navigationTitle("Depth Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.run() }
        }
    }

    @ViewBuilder
    private func depthGrid(snapshot: DepthSnapshot, depthSize: CGSize, viewportSize: CGSize) -> some View {
        let mapping = ViewportMapping(
            imageSize: depthSize,
            viewportSize: viewportSize,
            contentMode: .aspectFit,
            isMirrored: model.state.cameraPosition == .front
        )

        ForEach(0..<(snapshot.columns * snapshot.rows), id: \.self) { index in
            let row = index / snapshot.columns
            let column = index % snapshot.columns
            let canonical = CanonicalPoint(
                x: (CGFloat(column) + 0.5) / CGFloat(snapshot.columns),
                y: (CGFloat(row) + 0.5) / CGFloat(snapshot.rows)
            )
            if let point = mapping.viewportPoint(from: canonical) {
                Text(snapshot.meters[index].map { String(format: "%.1f", $0) } ?? "—")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 4))
                    .position(point)
                    .allowsHitTesting(false)
            }
        }
    }

    private var depthDeviceMenu: some View {
        Menu {
            ForEach(model.devices) { device in
                Button {
                    Task { await model.selectDevice(device) }
                } label: {
                    HStack {
                        Text("\(device.position.rawValue.capitalized) · \(device.localizedName)")
                        if device.uniqueID == model.state.deviceUniqueID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "camera.aperture")
                .font(.title3.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.76), in: Circle())
                .foregroundStyle(Color.white)
        }
    }
}
