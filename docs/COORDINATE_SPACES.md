# Coordinate Spaces

## Why this exists

Camera applications frequently pass a `CGPoint` that is syntactically valid and semantically wrong: SwiftUI touch points, Vision lower-left normalized points, crop-relative points, capture-device focus points, orientation-up image pixels, and mirrored preview points are all different spaces.

## Canonical image space

CameraGeometryKit canonical space is the uncropped source image, upright, non-mirrored, normalized to 0...1, top-left origin, x right, y down. The image center is always `CanonicalPoint(x: 0.5, y: 0.5)` regardless of pixel resolution, preview size, or crop.

## Do not clamp by default

A source point can validly lie outside the current crop. Implicit clamping turns “outside the crop” into “on the crop edge” and changes meaning. Clamp only at a boundary that explicitly requires clipping.

## Photos

UIKit images can carry orientation metadata and non-1 scale. Normalize at import:

```swift
let image = source.cameraGeometryCanonicalized()
```

The result is orientation `.up`, scale 1, so one image unit is one pixel.

## Crops

`ImageCoordinateSpace` stores uncropped source pixel size plus a crop rectangle in the same top-left pixel space. Canonical points belong to the source image; an aspect-ratio change changes only source→output mapping, not the point itself.

## Custom preview viewports

`ViewportMapping` maps an upright canonical image/frame into a view.

- aspect fit: letterbox touches return `nil`
- aspect fill: crop offset is preserved; no silent edge clamping
- mirrored presentation: display x is flipped but stored canonical x is unchanged

Example: canonical x=0.2 appears near display x=0.8 in a mirrored front preview, while the stored value remains 0.2.

## Vision

Traditional Vision bounding boxes use normalized coordinates with a lower-left origin. Canonical space is top-left origin.

```text
Vision                        Canonical
(0,1) ───── (1,1)            (0,0) ───── (1,0)
  │           │                 │           │
  │           │       →         │           │
(0,0) ───── (1,0)            (0,1) ───── (1,1)
```

Convert once at the Vision boundary:

```swift
let rect = VisionGeometry.canonicalRect(
    fromVisionNormalized: observation.boundingBox
)
```

App state should not carry raw Vision rectangles unless intentionally Vision-specific.

## Capture-device point-of-interest coordinates

`AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)` returns a normalized point in the capture device's unrotated picture area for focus/exposure. That is not canonical upright image space.

CameraGeometryKit uses a distinct `CaptureDevicePoint` type. Focus/exposure remains in device-point space; product-semantic image locations use canonical coordinates.

## Coordinate ownership rule

Every location must answer:

1. Which coordinate space owns this value?
2. Which explicit transform crosses into the next space?

If the answer is “it is just a CGPoint and we know what it means here,” the design is one refactor away from a camera-geometry bug.
