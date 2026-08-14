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
struct CameraSampleView: View {
    @StateObject private var model = CameraSampleModel()
    @State private var isDiagnosticsExpanded = false
    @State private var previewDiagnostics: AppPreviewDiagnostics?
    @State private var deviceOrientation = UIDevice.current.orientation
    @State private var interfaceOrientation: UIInterfaceOrientation = .unknown

    var body: some View {
        ZStack {
            CameraPreviewView(
                camera: model.camera,
                deviceUniqueID: model.state.deviceUniqueID
            ) { diagnostics in
                if previewDiagnostics != diagnostics {
                    previewDiagnostics = diagnostics
                }
            }
            .background(Color.black)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                statusCard
                Spacer()
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black)
        .task {
            await model.runSession()
        }
        .task(id: model.requestedPosition) {
            await model.switchCamera(to: model.requestedPosition)
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
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("CameraGeometryKit", systemImage: "camera.viewfinder")
                    .font(.headline)
                Spacer()
                Text(model.positionTitle)
                    .font(.subheadline.weight(.medium))
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isDiagnosticsExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isDiagnosticsExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDiagnosticsExpanded ? "診断HUDを閉じる" : "診断HUDを開く")
            }

            Text(model.state.deviceName ?? "カメラを起動しています…")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(model.frameSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("delivered \(model.statistics.deliveredFrames)  •  dropped \(model.statistics.droppedByAVFoundation)  •  replaced \(model.statistics.replacedInLatestBuffer)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if isDiagnosticsExpanded {
                Divider()
                    .padding(.vertical, 4)

                ScrollView(.vertical, showsIndicators: true) {
                    diagnosticsContent
                }
                .frame(maxHeight: 440)
            }
        }
        .padding(14)
        .foregroundStyle(.primary)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var diagnosticsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
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

    private func diagnosticSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(.primary)
            content()
        }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .frame(width: 112, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
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

    private func boolText(_ value: Bool) -> String {
        value ? "true" : "false"
    }

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

private struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraCaptureSession
    let deviceUniqueID: String?
    let onDiagnostics: (AppPreviewDiagnostics) -> Void

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.onDiagnostics = onDiagnostics
        return view
    }

    func updateUIView(_ view: PreviewContainerView, context: Context) {
        view.onDiagnostics = onDiagnostics
        view.update(camera: camera, deviceUniqueID: deviceUniqueID)
    }
}

@MainActor
private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var onDiagnostics: ((AppPreviewDiagnostics) -> Void)?

    private var cameraRotation: CameraRotation?
    private var latestLibraryRotation: CameraRotationSnapshot?
    private var observedDeviceUniqueID: String?

    private var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("PreviewContainerView must use AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    func update(camera: CameraCaptureSession, deviceUniqueID: String?) {
        previewLayer.session = camera.captureSession
        previewLayer.videoGravity = .resizeAspectFill

        if observedDeviceUniqueID != deviceUniqueID || cameraRotation == nil {
            cameraRotation?.stopObserving()
            cameraRotation = nil
            latestLibraryRotation = nil
            observedDeviceUniqueID = deviceUniqueID

            if deviceUniqueID != nil,
               let rotation = camera.makePreviewRotation(previewLayer: previewLayer) {
                cameraRotation = rotation
                latestLibraryRotation = rotation.snapshot
                rotation.observe { [weak self] snapshot in
                    guard let self else { return }
                    self.latestLibraryRotation = snapshot
                    self.publishDiagnostics()
                }
            }
        }

        // Deliberately do not call applyPreviewAngle here. This verification HUD
        // must expose whether the sample app has actually applied the value that
        // CameraGeometryKit handed to it.
        publishDiagnostics()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        publishDiagnostics()
    }

    private func publishDiagnostics() {
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

        Task { @MainActor [weak self] in
            self?.onDiagnostics?(snapshot)
        }
    }
}
