# Device, Depth, and ARKit Geometry

CameraGeometryKit 0.1.1 extends the shared geometry boundary without becoming a product-level camera manager.

## Camera device selection

Use `CameraDeviceRequest` when an app needs a camera type other than the default wide-angle camera. `preferredDeviceTypes` is ordered by preference and is resolved with `AVCaptureDevice.DiscoverySession`.

```swift
let request = CameraDeviceRequest(
    position: .back,
    preferredDeviceTypes: [
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
    ]
)
try await camera.start(deviceRequest: request)
```

TrueDepth works the same way on the front side:

```swift
let request = CameraDeviceRequest(
    position: .front,
    preferredDeviceTypes: [
        .builtInTrueDepthCamera,
        .builtInWideAngleCamera,
    ]
)
```

Use framework-reported device types and capabilities. Do not branch on iPhone model identifiers.

## Depth capture

Depth is opt-in:

```swift
let camera = CameraCaptureSession(
    depthConfiguration: CameraDepthConfiguration()
)
```

When the selected active video format supports a requested depth format, `CameraFrame.depth` carries synchronized `AVDepthData`. RGB and depth preserve separate pixel dimensions and geometry metadata. Keep the enclosing `CameraFrame.id` when combining depth, masks, and Vision results.

If depth is requested but unavailable for the selected active video format, configuration fails explicitly rather than silently switching to an unrelated source.

## ARKit boundary

`ARFrameGeometry` is a narrow adapter from ARKit captured-image normalized coordinates to CameraGeometryKit canonical coordinates. It uses `ARFrame.displayTransform(for:viewportSize:)` because ARKit defines that boundary in terms of interface orientation and viewport geometry.

This does not change the AVFoundation rotation rule: do not derive `videoRotationAngle` from interface orientation.

CameraGeometryKit does not own `ARSession`, anchors, world tracking, or scene reconstruction.
