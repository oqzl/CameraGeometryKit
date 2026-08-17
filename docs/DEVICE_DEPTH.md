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

When a caller requires live depth, set `requiresDepthData`. Discovery then keeps only devices that report at least one video format with compatible depth data. The active video/depth format pair is still validated after the session preset establishes the active video format.

```swift
let request = CameraDeviceRequest(
    position: .front,
    preferredDeviceTypes: [
        .builtInTrueDepthCamera,
        .builtInWideAngleCamera,
    ],
    requiresDepthData: true
)
```

A `CameraCaptureSession` created with `depthConfiguration` always enforces that depth requirement. Its `start(position:)`, `setCameraPosition(_:)`, and `switchCamera()` convenience paths search the runtime-discovered device types for a depth-capable device. An explicit `CameraDeviceRequest` keeps its requested device-type order and exact `uniqueID`, if any, while adding the depth requirement.

This is capability-based behavior. It does not create model-specific production branches.

`CameraCaptureSession.activeCaptureDevice` is exposed for ordinary focus, exposure, and zoom configuration. Capture-graph mutation remains owned by `CameraCaptureSession`.

## Synchronized depth capture

0.1.1 provides `CameraDepthFrameGeometry`, `CameraDepthFrame`, and `CameraSynchronizedFrame`, and can configure `AVCaptureDepthDataOutput` together with video output.

Depth capture is opt-in:

```swift
let camera = CameraCaptureSession(
    depthConfiguration: CameraDepthCaptureConfiguration()
)

try await camera.start(position: .front)

if let stream = camera.synchronizedFrameStream {
    for await frame in stream.frames {
        let color = frame.color
        let depth = frame.depth
    }
}
```

When depth is enabled, the capture graph uses `AVCaptureDataOutputSynchronizer` to deliver time-matched video and depth samples. A dropped depth sample produces a `CameraSynchronizedFrame` with `depth == nil`; the color frame remains valid and keeps its `CameraFrameID`.

The synchronized path reuses the same `CameraFrameStream.output` as video-only capture. Therefore `camera.frameStream.frames` remains a valid color-only source even when depth is enabled, preserves any requested color pixel format, and emits the same `CameraFrame` identity used by `CameraSynchronizedFrame.color`. Use `synchronizedFrameStream.frames` only when the consumer needs the time-matched depth sample.

The session does not choose a new color video format. It lets the requested `sessionPreset` establish the device's active video format, then selects the highest-resolution requested depth data type from that format's `supportedDepthDataFormats`. If the active video format cannot provide a requested depth type, configuration fails explicitly.

The default depth type preference is `DepthFloat32`, then `DepthFloat16`. Filtering is off by default and can be enabled through `CameraDepthCaptureConfiguration`.

`CameraSynchronizedFrameStream.statistics()` reports synchronized deliveries, dropped color samples, dropped depth samples, and replacements in the latest-frame buffer. `CameraFrameStream.statistics()` continues to report color delivery statistics.

The same capture rotation and canonical non-mirroring policy is applied to both video and depth connections. RGB and depth may still have different pixel dimensions, so use their geometry metadata rather than assuming equal sizes.
