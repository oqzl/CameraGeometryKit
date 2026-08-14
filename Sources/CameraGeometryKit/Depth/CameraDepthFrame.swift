@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

public struct CameraDepthFrameGeometry: Sendable, Hashable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let cameraPosition: CameraPosition
    public let appliedVideoRotationAngle: CGFloat
    public let isMirrored: Bool
    public let depthDataType: OSType
    public let isFiltered: Bool

    public init(
        pixelWidth: Int,
        pixelHeight: Int,
        cameraPosition: CameraPosition,
        appliedVideoRotationAngle: CGFloat,
        isMirrored: Bool,
        depthDataType: OSType,
        isFiltered: Bool
    ) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.cameraPosition = cameraPosition
        self.appliedVideoRotationAngle = appliedVideoRotationAngle
        self.isMirrored = isMirrored
        self.depthDataType = depthDataType
        self.isFiltered = isFiltered
    }

    public var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }
}

public struct CameraDepthFrame: @unchecked Sendable {
    public let depthData: AVDepthData
    public let timestamp: CMTime
    public let geometry: CameraDepthFrameGeometry

    public init(
        depthData: AVDepthData,
        timestamp: CMTime,
        geometry: CameraDepthFrameGeometry
    ) {
        self.depthData = depthData
        self.timestamp = timestamp
        self.geometry = geometry
    }

    public var depthMap: CVPixelBuffer {
        depthData.depthDataMap
    }
}

/// A color frame and its time-matched depth sample.
///
/// `depth` is nil when AVFoundation delivered the color frame but dropped the
/// corresponding depth sample. The color frame remains useful and keeps its
/// normal `CameraFrameID` identity.
public struct CameraSynchronizedFrame: @unchecked Sendable {
    public let color: CameraFrame
    public let depth: CameraDepthFrame?

    public init(color: CameraFrame, depth: CameraDepthFrame?) {
        self.color = color
        self.depth = depth
    }
}
