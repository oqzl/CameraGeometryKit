import ARKit
import CoreGraphics
import UIKit

/// Narrow ARKit boundary for image-space geometry.
///
/// This adapter does not own `ARSession`, anchors, world tracking, or scene
/// reconstruction. It only asks ARKit for the transform from the native
/// captured-image coordinate space into an upright image coordinate space.
public enum ARFrameGeometry {
    public static func imageResolution(frame: ARFrame) -> CGSize {
        frame.camera.imageResolution
    }

    public static func canonicalImageSize(
        imageResolution: CGSize,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CGSize {
        switch interfaceOrientation {
        case .portrait, .portraitUpsideDown:
            CGSize(width: imageResolution.height, height: imageResolution.width)
        case .landscapeLeft, .landscapeRight:
            imageResolution
        default:
            imageResolution
        }
    }

    /// Uses ARKit's own display transform with a viewport matching the upright
    /// image aspect ratio. This removes app-preview cropping from the transform
    /// while retaining ARKit's camera-image rotation semantics.
    public static func capturedImageToCanonicalTransform(
        frame: ARFrame,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CGAffineTransform {
        frame.displayTransform(
            for: interfaceOrientation,
            viewportSize: canonicalImageSize(
                imageResolution: frame.camera.imageResolution,
                interfaceOrientation: interfaceOrientation
            )
        )
    }

    public static func canonicalPoint(
        fromCapturedImageNormalized point: CGPoint,
        frame: ARFrame,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CanonicalPoint {
        CanonicalPoint(
            point.applying(
                capturedImageToCanonicalTransform(
                    frame: frame,
                    interfaceOrientation: interfaceOrientation
                )
            )
        )
    }

    public static func capturedImageNormalizedPoint(
        from canonicalPoint: CanonicalPoint,
        frame: ARFrame,
        interfaceOrientation: UIInterfaceOrientation
    ) -> CGPoint {
        canonicalPoint.cgPoint.applying(
            capturedImageToCanonicalTransform(
                frame: frame,
                interfaceOrientation: interfaceOrientation
            ).inverted()
        )
    }
}
