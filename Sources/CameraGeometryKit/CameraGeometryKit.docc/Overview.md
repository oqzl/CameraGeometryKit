# CameraGeometryKit

CameraGeometryKit gives camera applications one explicit coordinate system for
photos, camera frames, Vision results, previews, and touch input.

The package targets iOS 18 and Swift 6. It provides the reusable camera and
geometry boundaries; an application still owns its UI, capture settings,
Vision model semantics, storage, and product workflow.

## Canonical image space

Canonical image space describes the uncropped, upright, non-mirrored source
image:

- the origin is at the top-left
- `x` increases from left to right
- `y` increases from top to bottom
- coordinates are normalized to `0...1`

Values are not implicitly clamped. A location outside the unit square can be
valid when it is being mapped through a crop or a viewport.

```swift
let point = CanonicalPoint(x: 0.42, y: 0.61)
let imageSpace = ImageCoordinateSpace.source(
    size: CGSize(width: 4032, height: 3024)
)
let outputPoint = imageSpace.outputNormalizedPoint(for: point)
```

## Capture and analysis

`CameraCaptureSession` serializes capture-graph changes and keeps
`startRunning()` and `stopRunning()` off the main actor. Depth capture is
opt-in and uses synchronized RGB/depth delivery.

`CameraVisionWorker` runs one expensive operation at a time, keeps only the
newest pending frame, and suppresses results from obsolete generations.

```swift
let camera = CameraCaptureSession()
try await camera.start(position: .back)

for await frame in camera.frameStream.frames {
    // Submit frame to application-specific analysis.
}
```

## Topics

### Coordinate mapping

- ``CanonicalPoint``
- ``CanonicalRect``
- ``ImageCoordinateSpace``
- ``ViewportMapping``
- ``VisionGeometry``
- ``CaptureDevicePoint``

### Camera capture

- ``CameraCaptureSession``
- ``CameraCaptureSessionState``
- ``CameraCaptureSessionError``
- ``CameraDeviceDiscovery``
- ``CameraDeviceRequest``
- ``CameraDeviceInfo``
- ``CameraFrame``
- ``CameraFrameID``
- ``CameraFrameGeometry``
- ``CameraFrameStream``
- ``CameraRotation``
- ``CameraPreviewRotationBinding``

### Depth and Vision

- ``CameraDepthCaptureConfiguration``
- ``CameraDepthFrame``
- ``CameraDepthFrameGeometry``
- ``CameraSynchronizedFrame``
- ``CameraSynchronizedFrameStream``
- ``CameraVisionWorker``
- ``CameraVisionOutput``

### Concurrency and diagnostics

- ``WorkGeneration``
- ``CameraDiagnosticsSnapshot``

## Related guides

- <doc:CoordinateSpaces>
- <doc:CaptureAndAnalysis>

The repository also contains design and validation notes in the
[English documentation](https://github.com/oqzl/CameraGeometryKit/tree/main/docs).
