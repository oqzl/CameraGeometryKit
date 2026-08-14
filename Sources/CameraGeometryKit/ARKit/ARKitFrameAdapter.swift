@preconcurrency import ARKit
@preconcurrency import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import UIKit
import simd

public struct ARKitFrameGeometry {
    public let rawPixelSize: CGSize
    public let canonicalPixelSize: CGSize
    public let cameraIntrinsics: simd_float3x3?
    public let rawToPresentedNormalized: CGAffineTransform
    public let presentedToRawNormalized: CGAffineTransform
    public let presentationIsMirrored: Bool

    public init(rawPixelSize: CGSize, canonicalPixelSize: CGSize, rawToPresentedNormalized: CGAffineTransform, cameraIntrinsics: simd_float3x3? = nil) {
        self.rawPixelSize = rawPixelSize
        self.canonicalPixelSize = canonicalPixelSize
        self.cameraIntrinsics = cameraIntrinsics
        self.rawToPresentedNormalized = rawToPresentedNormalized
        presentedToRawNormalized = rawToPresentedNormalized.inverted()
        presentationIsMirrored = rawToPresentedNormalized.a * rawToPresentedNormalized.d - rawToPresentedNormalized.b * rawToPresentedNormalized.c < 0
    }

    public func canonicalPoint(fromARKitNormalized point: CGPoint) -> CanonicalPoint {
        let presented = point.applying(rawToPresentedNormalized)
        return CanonicalPoint(x: presentationIsMirrored ? 1 - presented.x : presented.x, y: presented.y)
    }

    public func arKitNormalizedPoint(from canonicalPoint: CanonicalPoint) -> CGPoint {
        let presented = CGPoint(x: presentationIsMirrored ? 1 - canonicalPoint.x : canonicalPoint.x, y: canonicalPoint.y)
        return presented.applying(presentedToRawNormalized)
    }
}

public struct ARKitCameraFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let timestamp: TimeInterval
    public let geometry: ARKitFrameGeometry
}

public enum ARKitDepthSource: Sendable, Hashable {
    case capturedDepthData
    case sceneDepth
    case smoothedSceneDepth
}

public struct ARKitDepthFrame: @unchecked Sendable {
    public let depthMap: CVPixelBuffer
    public let confidenceMap: CVPixelBuffer?
    public let timestamp: TimeInterval
    public let source: ARKitDepthSource
    public let imageGeometry: ARKitFrameGeometry

    public var pixelSize: CGSize { CGSize(width: CVPixelBufferGetWidth(depthMap), height: CVPixelBufferGetHeight(depthMap)) }
    public var pixelFormat: OSType { CVPixelBufferGetPixelFormatType(depthMap) }
}

public enum ARKitFrameAdapter {
    public static func geometry(for frame: ARFrame, interfaceOrientation: UIInterfaceOrientation) -> ARKitFrameGeometry {
        let rawSize = CGSize(width: CVPixelBufferGetWidth(frame.capturedImage), height: CVPixelBufferGetHeight(frame.capturedImage))
        let canonicalSize = canonicalPixelSize(rawPixelSize: rawSize, interfaceOrientation: interfaceOrientation)
        return ARKitFrameGeometry(
            rawPixelSize: rawSize,
            canonicalPixelSize: canonicalSize,
            rawToPresentedNormalized: frame.displayTransform(for: interfaceOrientation, viewportSize: canonicalSize),
            cameraIntrinsics: frame.camera.intrinsics
        )
    }

    public static func cameraFrame(from frame: ARFrame, interfaceOrientation: UIInterfaceOrientation) -> ARKitCameraFrame {
        ARKitCameraFrame(pixelBuffer: frame.capturedImage, timestamp: frame.timestamp, geometry: geometry(for: frame, interfaceOrientation: interfaceOrientation))
    }

    public static func depthFrame(from frame: ARFrame, source: ARKitDepthSource, interfaceOrientation: UIInterfaceOrientation) -> ARKitDepthFrame? {
        let imageGeometry = geometry(for: frame, interfaceOrientation: interfaceOrientation)
        switch source {
        case .capturedDepthData:
            guard let data = frame.capturedDepthData else { return nil }
            return ARKitDepthFrame(depthMap: data.depthDataMap, confidenceMap: nil, timestamp: frame.capturedDepthDataTimestamp, source: source, imageGeometry: imageGeometry)
        case .sceneDepth:
            guard let data = frame.sceneDepth else { return nil }
            return ARKitDepthFrame(depthMap: data.depthMap, confidenceMap: data.confidenceMap, timestamp: frame.timestamp, source: source, imageGeometry: imageGeometry)
        case .smoothedSceneDepth:
            guard let data = frame.smoothedSceneDepth else { return nil }
            return ARKitDepthFrame(depthMap: data.depthMap, confidenceMap: data.confidenceMap, timestamp: frame.timestamp, source: source, imageGeometry: imageGeometry)
        }
    }

    public static func canonicalPixelSize(rawPixelSize: CGSize, interfaceOrientation: UIInterfaceOrientation) -> CGSize {
        switch interfaceOrientation {
        case .portrait, .portraitUpsideDown: CGSize(width: rawPixelSize.height, height: rawPixelSize.width)
        case .landscapeLeft, .landscapeRight: rawPixelSize
        default: rawPixelSize
        }
    }
}
