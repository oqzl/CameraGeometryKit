# Coordinate spaces

CameraGeometryKit keeps each framework's coordinate domain explicit. Convert
at the boundary and keep the resulting value typed as its destination domain.

## Canonical space

``CanonicalPoint`` and ``CanonicalRect`` use the uncropped, upright,
non-mirrored source image with a top-left origin and normalized coordinates.
They are the semantic image locations used by application code.

## Crop and viewport mappings

Use ``ImageCoordinateSpace`` when a canonical source image is cropped into an
output image. Use ``ViewportMapping`` when an upright image is rendered into a
viewport with aspect-fit or aspect-fill behavior.

Aspect-fit letterbox areas map to `nil`. Aspect-fill crop offsets remain part of
the mapping and are not silently clamped.

## Vision and capture-device coordinates

Vision's `NormalizedPoint` and `NormalizedRect` use a lower-left origin.
``VisionGeometry`` performs the vertical-axis conversion to and from canonical
space.

The focus/exposure point returned by
`AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)` is a
different domain. ``CaptureDevicePoint`` keeps it separate from canonical
image geometry.
