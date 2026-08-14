import AVFoundation
import CameraGeometryKit
import Foundation
import SwiftUI
import UIKit

private struct AppPreviewDiagnostics: Equatable {
    let boundsWidth: CGFloat
    let boundsHeight: CGFloat
    let videoGravity: String
    let libraryPreviewRotationAngle: CGFloat?
    let libraryCaptureRotationAngle: CGFloat?
    let connectionRotationAngle: CGFloat?
    let connectionMirrored: Bool?
    let layerTransform: String
}

@MainActor
private final class PreviewDiagnosticsStore: ObservableObject {
    @Published private(set) var snapshot: AppPreviewDiagnostics?

    func publish(_ snapshot: AppPreviewDiagnostics) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

private struct DiagnosticsShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
struct CameraSampleView: View {
    @State private var camera = CameraCaptureSession(sessionPreset: .high)
    @State private var previewDiagnosticsStore = PreviewDiagnosticsStore()
    @State private var activeDeviceUniqueID: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CameraPreviewView(
                    camera: camera,
                    deviceUniqueID: activeDeviceUniqueID,
                    diagnosticsStore: previewDiagnosticsStore
                )
                .background(Color.black)
                .ignoresSafeArea()

                CameraSampleOverlay(
                    camera: camera,
                    previewDiagnosticsStore: previewDiagnosticsStore,
                    availableSize: proxy.size
                ) { uniqueID in
                    if activeDeviceUniqueID != uniqueID {
                        activeDeviceUniqueID = uniqueID
                    }
                }
            }
        }
        .background(Color.black)
    }
}

@MainActor
private struct CameraSampleOverlay: View {
    @StateObject private var model: CameraSampleModel
    @ObservedObject private var previewDiagnosticsStore: PreviewDiagnosticsStore

    let availableSize: CGSize
    let onDeviceUniqueIDChanged: (String?) -> Void

    @State private var isDiagnosticsExpanded = false
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var interfaceOrientation: UIInterfaceOrientation = .unknown
    @State private var diagnosticsShareItem: DiagnosticsShareItem?

    init(
        camera: CameraCaptureSession,
        previewDiagnosticsStore: PreviewDiagnosticsStore,
        availableSize: CGSize,
        onDeviceUniqueIDChanged: @escaping (String?) -> Void
    ) {
        _model = StateObject(wrappedValue: CameraSampleModel(camera: camera))
        _previewDiagnosticsStore = ObservedObject(wrappedValue: previewDiagnosticsStore)
        self.availableSize = availableSize
        self.onDeviceUniqueIDChanged = onDeviceUniqueIDChanged
    }

    var body: some View {
        let isLandscapeHUD = availableSize.width > availableSize.height

        VStack(spacing: 0) {
            statusCard(
                availableWidth: availableSize.width,
                maxDiagnosticsHeight: max(
                    140,
                    availableSize.height - (isLandscapeHUD ? 145 : 210)
                ),
                compactHeader: isLandscapeHUD
            )
            Spacer()
            controls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .task { await model.runSession() }
        .task(id: model.requestedPosition) {
            await model.switchCamera(to: model.requestedPosition)
        }
        .onChange(of: model.state.deviceUniqueID, initial: true) { _, uniqueID in
            onDeviceUniqueIDChanged(uniqueID)
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            updateOrientationState(log: false)
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateOrientationState(log: true)
        }
        .sheet(item: $diagnosticsShareItem) { item in
            ActivityView(activityItems: [item.url])
        }
    }

    private func statusCard(
        availableWidth: CGFloat,
        maxDiagnosticsHeight: CGFloat,
        compactHeader: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("CameraGeometryKit", systemImage: "camera.viewfinder")
                    .font(.headline)
                Spacer()
                Text(model.positionTitle)
                    .font(.subheadline.weight(.medium))
                Button {
                    isDiagnosticsExpanded.toggle()
                } label: {
                    Image(systemName: isDiagnosticsExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDiagnosticsExpanded ? "診断HUDを閉じる" : "診断HUDを開く")
            }

            if compactHeader {
                HStack(spacing: 8) {
                    Text(model.state.deviceName ?? "カメラを起動しています…")
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text("•").foregroundStyle(.tertiary)
                    Text(model.frameSummary)
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                    Text("•").foregroundStyle(.tertiary)
                    Text(
                        "d \(model.statistics.deliveredFrames)  " +
                        "drop \(model.statistics.droppedByAVFoundation)  " +
                        "repl \(model.statistics.replacedInLatestBuffer)"
                    )
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.72)
            } else {
                Text(model.state.deviceName ?? "カメラを起動しています…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(model.frameSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(
                    "delivered \(model.statistics.deliveredFrames)  •  " +
                    "dropped \(model.statistics.droppedByAVFoundation)  •  " +
                    "replaced \(model.statistics.replacedInLatestBuffer)"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if isDiagnosticsExpanded {
                Divider().padding(.vertical, 4)

                HStack(spacing: 8) {
                    Text("ORIENTATION DIAGNOSTICS")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        copyDiagnosticsJSON()
                    } label: {
                        Label("Copy JSON", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)

                    Button {
                        exportDiagnosticsJSON()
                    } label: {
                        Label("Share JSON", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    diagnosticsContent(availableWidth: availableWidth - 28)
                }
                .frame(maxHeight: maxDiagnosticsHeight)
            }
        }
        .padding(14)
        .foregroundStyle(.white)
        .background(
            Color.black.opacity(0.82),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    @ViewBuilder
    private func diagnosticsContent(availableWidth: CGFloat) -> some View {
        let useTwoColumns = availableWidth >= 620
        let columns = useTwoColumns
            ? [
                GridItem(.flexible(), spacing: 16, alignment: .top),
                GridItem(.flexible(), spacing: 16, alignment: .top),
            ]
            : [GridItem(.flexible(), spacing: 12, alignment: .top)]

        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            diagnosticSection("LIBRARY → APP / SESSION") {
                diagnosticRow("device type", model.state.deviceTypeRawValue ?? "—")
                diagnosticRow("depth enabled", boolText(model.state.depthCaptureEnabled))
                diagnosticRow("active format", formatSize(
                    width: model.librarySessionDiagnostics?.activeFormatWidth,
                    height: model.librarySessionDiagnostics?.activeFormatHeight
                ))
                diagnosticRow("analysis conn", angleText(model.librarySessionDiagnostics?.analysisConnectionRotationAngle))
                diagnosticRow("analysis mirror", boolText(model.librarySessionDiagnostics?.analysisMirrored))
                diagnosticRow("photo conn", angleText(model.librarySessionDiagnostics?.photoConnectionRotationAngle))
                diagnosticRow("photo mirror", boolText(model.librarySessionDiagnostics?.photoMirrored))
            }

            diagnosticSection("LIBRARY → APP / FRAME") {
                diagnosticRow("frame id", model.deliveredFrameDiagnostics.map { String($0.frameID) } ?? "—")
                diagnosticRow("camera", model.deliveredFrameDiagnostics.map { $0.cameraPosition.rawValue } ?? "—")
                diagnosticRow("buffer", formatSize(
                    width: model.deliveredFrameDiagnostics?.pixelWidth,
                    height: model.deliveredFrameDiagnostics?.pixelHeight
                ))
                diagnosticRow("frame rotation", angleText(model.deliveredFrameDiagnostics?.appliedVideoRotationAngle))
                diagnosticRow("frame mirrored", boolText(model.deliveredFrameDiagnostics?.isMirrored))
            }

            diagnosticSection("LIBRARY → APP / PREVIEW") {
                diagnosticRow("requested preview", angleText(previewDiagnostics?.libraryPreviewRotationAngle))
                diagnosticRow("requested capture", angleText(previewDiagnostics?.libraryCaptureRotationAngle))
            }

            diagnosticSection("APP / PREVIEW + UI") {
                diagnosticRow("device", deviceOrientationText(deviceOrientation))
                diagnosticRow("interface", interfaceOrientationText(interfaceOrientation))
                diagnosticRow("orientation notify", "on")
                diagnosticRow("preview bounds", previewDiagnostics.map {
                    String(format: "%.0f × %.0f pt", $0.boundsWidth, $0.boundsHeight)
                } ?? "—")
                diagnosticRow("gravity", previewDiagnostics?.videoGravity ?? "—")
                diagnosticRow("preview actual", angleText(previewDiagnostics?.connectionRotationAngle))
                diagnosticRow("preview mirror", boolText(previewDiagnostics?.connectionMirrored))
                diagnosticRow("layer transform", previewDiagnostics?.layerTransform ?? "—")
            }
        }
        .padding(.bottom, 2)
    }

    private var previewDiagnostics: AppPreviewDiagnostics? {
        previewDiagnosticsStore.snapshot
    }

    private func diagnosticSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.monospaced().weight(.bold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .frame(width: 112, alignment: .leading)
                .foregroundStyle(.white.opacity(0.72))
            Text(value)
                .textSelection(.enabled)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .font(.caption2.monospaced())
    }

    private var controls: some View {
        HStack {
            Text("iOS 18+ / Swift 6")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Button {
                model.requestedPosition = model.state.cameraPosition == .front ? .back : .front
            } label: {
                Label("切替", systemImage: "arrow.triangle.2.circlepath.camera")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .disabled(!model.isRunning)
        }
    }

    private func diagnosticsJSONObject() -> [String: Any] {
        let session = model.librarySessionDiagnostics
        let frame = model.deliveredFrameDiagnostics
        let preview = previewDiagnostics

        return [
            "capturedAt": ISO8601DateFormatter().string(from: Date()),
            "libraryToApp": [
                "session": [
                    "deviceName": jsonValue(model.state.deviceName),
                    "deviceType": jsonValue(model.state.deviceTypeRawValue),
                    "cameraPosition": model.state.cameraPosition.rawValue,
                    "depthEnabled": model.state.depthCaptureEnabled,
                    "activeFormat": [
                        "width": jsonValue(session?.activeFormatWidth),
                        "height": jsonValue(session?.activeFormatHeight),
                    ],
                    "analysisConnection": [
                        "rotationAngle": jsonValue(session?.analysisConnectionRotationAngle),
                        "mirrored": jsonValue(session?.analysisMirrored),
                    ],
                    "photoConnection": [
                        "rotationAngle": jsonValue(session?.photoConnectionRotationAngle),
                        "mirrored": jsonValue(session?.photoMirrored),
                    ],
                ],
                "frame": [
                    "id": jsonValue(frame?.frameID),
                    "cameraPosition": jsonValue(frame?.cameraPosition.rawValue),
                    "pixelWidth": jsonValue(frame?.pixelWidth),
                    "pixelHeight": jsonValue(frame?.pixelHeight),
                    "appliedVideoRotationAngle": jsonValue(frame?.appliedVideoRotationAngle),
                    "mirrored": jsonValue(frame?.isMirrored),
                ],
                "previewRotation": [
                    "requestedPreviewAngle": jsonValue(preview?.libraryPreviewRotationAngle),
                    "requestedCaptureAngle": jsonValue(preview?.libraryCaptureRotationAngle),
                ],
            ],
            "app": [
                "deviceOrientation": deviceOrientationText(deviceOrientation),
                "interfaceOrientation": interfaceOrientationText(interfaceOrientation),
                "preview": [
                    "boundsWidth": jsonValue(preview?.boundsWidth),
                    "boundsHeight": jsonValue(preview?.boundsHeight),
                    "videoGravity": jsonValue(preview?.videoGravity),
                    "actualConnectionRotationAngle": jsonValue(preview?.connectionRotationAngle),
                    "mirrored": jsonValue(preview?.connectionMirrored),
                    "layerTransform": jsonValue(preview?.layerTransform),
                ],
            ],
            "statistics": [
                "deliveredFrames": model.statistics.deliveredFrames,
                "droppedByAVFoundation": model.statistics.droppedByAVFoundation,
                "replacedInLatestBuffer": model.statistics.replacedInLatestBuffer,
            ],
        ]
    }

    private func jsonValue<T>(_ value: T?) -> Any {
        guard let value else { return NSNull() }
        return value
    }

    private func diagnosticsJSONData() -> Data? {
        try? JSONSerialization.data(
            withJSONObject: diagnosticsJSONObject(),
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    private func copyDiagnosticsJSON() {
        guard let data = diagnosticsJSONData(),
              let text = String(data: data, encoding: .utf8) else { return }
        UIPasteboard.general.string = text
    }

    private func exportDiagnosticsJSON() {
        guard let data = diagnosticsJSONData() else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CameraGeometryKit-diagnostics-\(formatter.string(from: Date())).json"
            )
        do {
            try data.write(to: url, options: .atomic)
            diagnosticsShareItem = DiagnosticsShareItem(url: url)
        } catch {
            print("[OrientationDebug] failed to export JSON: \(error.localizedDescription)")
        }
    }

    private func updateOrientationState(log: Bool) {
        deviceOrientation = UIDevice.current.orientation
        interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .interfaceOrientation ?? .unknown

        guard log else { return }
        print(
            "[OrientationDebug] " +
            "device=\(deviceOrientationText(deviceOrientation)) " +
            "interface=\(interfaceOrientationText(interfaceOrientation)) " +
            "libraryPreview=\(angleText(previewDiagnostics?.libraryPreviewRotationAngle)) " +
            "previewActual=\(angleText(previewDiagnostics?.connectionRotationAngle)) " +
            "frameRotation=\(angleText(model.deliveredFrameDiagnostics?.appliedVideoRotationAngle))"
        )
    }

    private func angleText(_ value: CGFloat?) -> String {
        value.map { String(format: "%.1f°", $0) } ?? "—"
    }

    private func boolText(_ value: Bool?) -> String {
        value.map { $0 ? "true" : "false" } ?? "—"
    }

    private func boolText(_ value: Bool) -> String { value ? "true" : "false" }

    private func formatSize(width: Int?, height: Int?) -> String {
        guard let width, let height else { return "—" }
        return "\(width) × \(height)"
    }

    private func deviceOrientationText(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .unknown: "unknown"
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        case .faceUp: "faceUp"
        case .faceDown: "faceDown"
        @unknown default: "unknown(\(orientation.rawValue))"
        }
    }

    private func interfaceOrientationText(_ orientation: UIInterfaceOrientation) -> String {
        switch orientation {
        case .unknown: "unknown"
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        @unknown default: "unknown(\(orientation.rawValue))"
        }
    }
}

@MainActor
private struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraCaptureSession
    let deviceUniqueID: String?
    let diagnosticsStore: PreviewDiagnosticsStore

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.update(
            camera: camera,
            deviceUniqueID: deviceUniqueID,
            diagnosticsStore: diagnosticsStore
        )
        return view
    }

    func updateUIView(_ view: PreviewContainerView, context: Context) {
        view.update(
            camera: camera,
            deviceUniqueID: deviceUniqueID,
            diagnosticsStore: diagnosticsStore
        )
    }
}

@MainActor
private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private weak var diagnosticsStore: PreviewDiagnosticsStore?
    private var previewRotationBinding: CameraPreviewRotationBinding?
    private var latestLibraryRotation: CameraRotationSnapshot?
    private var observedDeviceUniqueID: String?
    private var lastPublishedDiagnostics: AppPreviewDiagnostics?

    private var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("PreviewContainerView must use AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    func update(
        camera: CameraCaptureSession,
        deviceUniqueID: String?,
        diagnosticsStore: PreviewDiagnosticsStore
    ) {
        self.diagnosticsStore = diagnosticsStore

        if previewLayer.session !== camera.captureSession {
            previewLayer.session = camera.captureSession
        }
        if previewLayer.videoGravity != .resizeAspect {
            previewLayer.videoGravity = .resizeAspect
        }

        if observedDeviceUniqueID != deviceUniqueID || previewRotationBinding == nil {
            previewRotationBinding?.stop()
            previewRotationBinding = nil
            latestLibraryRotation = nil
            observedDeviceUniqueID = deviceUniqueID

            if deviceUniqueID != nil,
               let binding = camera.bindPreviewRotation(to: previewLayer) {
                previewRotationBinding = binding
                latestLibraryRotation = binding.snapshot
                binding.observe { [weak self] snapshot in
                    guard let self else { return }
                    self.latestLibraryRotation = snapshot
                    self.publishDiagnosticsIfChanged()
                }
            }
        }

        publishDiagnosticsIfChanged()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        previewRotationBinding?.refresh()
        publishDiagnosticsIfChanged()
    }

    private func publishDiagnosticsIfChanged() {
        let connection = previewLayer.connection
        let transform = previewLayer.affineTransform()
        let snapshot = AppPreviewDiagnostics(
            boundsWidth: bounds.width,
            boundsHeight: bounds.height,
            videoGravity: previewLayer.videoGravity.rawValue,
            libraryPreviewRotationAngle: latestLibraryRotation?.previewAngle,
            libraryCaptureRotationAngle: latestLibraryRotation?.captureAngle,
            connectionRotationAngle: connection?.videoRotationAngle,
            connectionMirrored: connection?.isVideoMirrored,
            layerTransform: transform.isIdentity
                ? "identity"
                : String(
                    format: "[%.2f %.2f %.2f %.2f %.1f %.1f]",
                    transform.a,
                    transform.b,
                    transform.c,
                    transform.d,
                    transform.tx,
                    transform.ty
                )
        )

        guard snapshot != lastPublishedDiagnostics else { return }
        lastPublishedDiagnostics = snapshot
        diagnosticsStore?.publish(snapshot)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}