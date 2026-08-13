# Coordinate Spaces

## Why this exists

Camera apps cross several coordinate domains: SwiftUI/UIKit view points, Vision normalized geometry, crop-relative points, capture-device focus points, upright image pixels, and mirrored presentation coordinates.

## Canonical image space

CameraGeometryKit canonical space is the uncropped source image, upright, non-mirrored, normalized to 0...1, with a top-left origin, x to the right, and y downward.

## Do not clamp by default

A source point may validly lie outside the current crop. Clamp only at a boundary that explicitly requires clipping.

## Photos

Normalize UIKit images at import:

```swift
let image = source.cameraGeometryCanonicalized()
```

The result is orientation `.up`, scale 1.

## Crops and custom previews

`ImageCoordinateSpace` maps source-image geometry to crop/output geometry. `ViewportMapping` maps upright canonical geometry to aspect-fit or aspect-fill viewports while keeping letterboxing, cropping, and presentation mirroring explicit.

## Vision

On iOS 18+, CameraGeometryKit uses Vision's Swift-native `NormalizedPoint` and `NormalizedRect` types. Vision uses normalized lower-left-origin geometry; canonical geometry uses normalized top-left-origin geometry.

```text
Vision                        Canonical
(0,1) ───── (1,1)            (0,0) ───── (1,0)
  │           │                 │           │
(0,0) ───── (1,0)            (0,1) ───── (1,1)
```

Convert once at the Vision boundary:

```swift
let canonical = VisionGeometry.canonicalRect(from: observation.boundingBox)
let normalized = VisionGeometry.normalizedRect(from: canonical)
```

Keep Swift-native Vision geometry typed as Vision geometry until it crosses into canonical space.

## Capture-device point-of-interest coordinates

`AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)` returns capture-device focus/exposure coordinates. Those are not canonical image coordinates. CameraGeometryKit keeps them typed separately as `CaptureDevicePoint`.

## Coordinate ownership rule

Every location must have an explicit owner coordinate space and an explicit transform when it crosses into another space. Do not pass a semantically changing untyped `CGPoint` through the pipeline.
