import CoreGraphics
import Foundation

public struct CameraDiagnosticsSnapshot: Sendable, Hashable {
    public let cameraPosition: CameraPosition
    public let previewRotationAngle: CGFloat
    public let captureRotationAngle: CGFloat
    public let analysisConnectionRotationAngle: CGFloat
    public let previewMirrored: Bool
    public let analysisMirrored: Bool
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let deliveredFrames: UInt64
    public let droppedFrames: UInt64
    public let replacedPendingFrames: UInt64

    public init(
        cameraPosition: CameraPosition,
        previewRotationAngle: CGFloat,
        captureRotationAngle: CGFloat,
        analysisConnectionRotationAngle: CGFloat,
        previewMirrored: Bool,
        analysisMirrored: Bool,
        pixelWidth: Int,
        pixelHeight: Int,
        deliveredFrames: UInt64,
        droppedFrames: UInt64,
        replacedPendingFrames: UInt64
    ) {
        self.cameraPosition = cameraPosition
        self.previewRotationAngle = previewRotationAngle
        self.captureRotationAngle = captureRotationAngle
        self.analysisConnectionRotationAngle = analysisConnectionRotationAngle
        self.previewMirrored = previewMirrored
        self.analysisMirrored = analysisMirrored
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.deliveredFrames = deliveredFrames
        self.droppedFrames = droppedFrames
        self.replacedPendingFrames = replacedPendingFrames
    }

    public var debugText: String {
        """
        CAMERA
        position: \(cameraPosition.rawValue)
        preview rotation: \(previewRotationAngle)°
        capture rotation: \(captureRotationAngle)°
        analysis connection rotation: \(analysisConnectionRotationAngle)°
        preview mirrored: \(previewMirrored)
        analysis mirrored: \(analysisMirrored)

        FRAME
        size: \(pixelWidth)×\(pixelHeight)
        delivered: \(deliveredFrames)
        dropped by AVFoundation: \(droppedFrames)
        replaced pending: \(replacedPendingFrames)
        """
    }
}
