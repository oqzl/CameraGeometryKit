# Device Selection and Depth Geometry

## Device selection

CameraGeometryKit selects cameras by AVFoundation-reported capability, never by iPhone model identifier.

`CameraDeviceRequest` takes an ordered list of `AVCaptureDevice.DeviceType` values. `CameraDeviceDiscovery` uses `AVCaptureDevice.DiscoverySession` and returns matches in the requested priority order.

```swift
let request = CameraDeviceRequest(
    position: .back,
    preferredDeviceTypes: [
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
    ]
)
try await camera.start(request: request)
```

Front cameras use the same mechanism, including TrueDepth when available.

```swift
let request = CameraDeviceRequest(
    position: .front,
    preferredDeviceTypes: [
        .builtInTrueDepthCamera,
        .builtInWideAngleCamera,
    ]
)
```

This is capability-based behavior. It does not create model-specific production branches.

`CameraCaptureSession.activeCaptureDevice` is exposed for ordinary focus, exposure, and zoom configuration. Capture-graph mutation remains owned by `CameraCaptureSession`.

## Synchronized depth capture

0.1.1 provides `CameraDepthFrameGeometry`, `CameraDepthFrame`, and `CameraSynchronizedFrame`, and can configure `AVCaptureDepthDataOutput` together with video output.

Depth capture is opt-in:

```swift
let camera = CameraCaptureSession(
    depthConfiguration: CameraDepthCaptureConfiguration()
)

try await camera.start(
    request: CameraDeviceRequest(
        position: .front,
        preferredDeviceTypes: [
            .builtInTrueDepthCamera,
            .builtInWideAngleCamera,
        ]
    )
)

if let stream = camera.synchronizedFrameStream {
    for await frame in stream.frames {
        let color = frame.color
        let depth = frame.depth
    }
}
```

When depth is enabled, the capture graph uses `AVCaptureDataOutputSynchronizer` to deliver time-matched video and depth samples. A dropped depth sample produces a `CameraSynchronizedFrame` with `depth == nil`; the color frame remains valid and keeps its `CameraFrameID`.

The session does not choose a new color video format. It lets the requested `sessionPreset` establish the device's active video format, then selects the highest-resolution requested depth data type from that format's `supportedDepthDataFormats`. If the active video format cannot provide a requested depth type, configuration fails explicitly.

The default depth type preference is `DepthFloat32`, then `DepthFloat16`. Filtering is off by default and can be enabled through `CameraDepthCaptureConfiguration`.

In video-only mode, use the existing `camera.frameStream.frames`. In depth mode, use `camera.synchronizedFrameStream?.frames`; the synchronized stream is the frame source for color/depth analysis.

The same capture rotation and canonical non-mirroring policy is applied to both video and depth connections. RGB and depth may still have different pixel dimensions, so use their geometry metadata rather than assuming equal sizes.
