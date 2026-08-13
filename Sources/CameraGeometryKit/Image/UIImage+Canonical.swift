import UIKit

public extension UIImage {
    /// Returns an orientation-up, scale-1 image where one UIKit point equals one
    /// image pixel. Use this at the photo-import boundary before constructing
    /// canonical geometry.
    func cameraGeometryCanonicalized() -> UIImage {
        if imageOrientation == .up, scale == 1, let cgImage {
            return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        }

        let pixelSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        guard pixelSize.width > 0, pixelSize.height > 0 else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }

    /// Downsamples a canonicalized image for interactive preview work without
    /// changing its normalized coordinate system.
    func cameraGeometryDownsampled(maxPixelDimension: CGFloat = 1600) -> UIImage {
        let source = cameraGeometryCanonicalized()
        guard let cgImage = source.cgImage else { return source }

        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixelDimension, maxPixelDimension > 0 else { return source }

        let ratio = maxPixelDimension / longest
        let targetSize = CGSize(
            width: max(1, floor(pixelSize.width * ratio)),
            height: max(1, floor(pixelSize.height * ratio))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
