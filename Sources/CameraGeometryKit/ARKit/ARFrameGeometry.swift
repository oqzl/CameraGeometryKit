import ARKit
import CoreGraphics
import UIKit

public enum ARFrameGeometry {
    public static func imageResolution(frame: ARFrame) -> CGSize {
        frame.camera.imageResolution
    }
}
