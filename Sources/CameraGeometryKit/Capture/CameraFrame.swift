@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ImageIO

public enum CameraPosition: String, Sendable, Hashable {
    case front
    case back
    case unspecified

    public init(_ position: AVCaptureDevice.Position) {
        switch position {
        case .front:
            self = .front
        case .back:
            self = .back
        default:
            self = .unspecified
        }
    }
}

public struct CameraFrameID: Sendable, Hashable, Comparable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Immutable geometry metadata captured at the same moment as a frame.
public struct CameraFrameGeometry: Sendable, Hashable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let cameraPosition: CameraPosition
    public let appliedVideoRotationAngle: CGFloat
    public let isMirrored: Bool

    public init(
        pixelWidth: Int,
        pixelHeight: Int,
        cameraPosition: CameraPosition,
        appliedVideoRotationAngle: CGFloat,
        isMirrored: Bool
    ) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.cameraPosition = cameraPosition
        self.appliedVideoRotationAngle = appliedVideoRotationAngle
        self.isMirrored = isMirrored
    }

    public var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    /// CameraGeometryKit's frame streams configure capture outputs so delivered
    /// buffers are already upright in canonical image space.
    public var visionOrientation: CGImagePropertyOrientation { .up }
}

/// Depth data synchronized with one `CameraFrame`.
///
/// `AVDepthData` owns a Core Video buffer and doesn't declare Sendable
/// conformance. CameraGeometryKit treats captured depth data as immutable after
/// delivery and therefore makes the concurrency boundary explicit here.
public struct CameraDepthFrame: @unchecked Sendable {
    public let depthData: AVDepthData
    public let timestamp: CMTime
    public let geometry: CameraFrameGeometry

    public init(
        depthData: AVDepthData,
        timestamp: CMTime,
        geometry: CameraFrameGeometry
    ) {
        self.depthData = depthData
        self.timestamp = timestamp
        self.geometry = geometry
    }

    public var pixelBuffer: CVPixelBuffer {
        depthData.depthDataMap
    }
}

/// A frame delivered by `CameraFrameStream`.
///
/// `pixelBuffer` is retained for the lifetime of this value. Core Video buffer
/// types don't declare Swift Sendable conformance, but the buffer is immutable
/// by convention after capture; the wrapper therefore carries an explicit
/// unchecked Sendable boundary.
///
/// When depth capture is enabled, `depth` comes from the same
/// `AVCaptureDataOutputSynchronizer` callback as the color sample. Derivatives
/// such as masks and Vision results should preserve this frame's `id` rather
/// than trying to re-match timestamps later.
public struct CameraFrame: @unchecked Sendable {
    public let id: CameraFrameID
    public let pixelBuffer: CVPixelBuffer
    public let timestamp: CMTime
    public let geometry: CameraFrameGeometry
    public let depth: CameraDepthFrame?

    public init(
        id: CameraFrameID,
        pixelBuffer: CVPixelBuffer,
        timestamp: CMTime,
        geometry: CameraFrameGeometry,
        depth: CameraDepthFrame? = nil
    ) {
        self.id = id
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.geometry = geometry
        self.depth = depth
    }
}
