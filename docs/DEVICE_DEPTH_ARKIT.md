# Device Selection, Depth Geometry, and ARKit

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

## Depth geometry

0.1.1 introduces `CameraDepthFrameGeometry`, `CameraDepthFrame`, and `CameraSynchronizedFrame` as the typed geometry/identity vocabulary for depth-aware pipelines. It also exposes `supportsDepthData` in device/session metadata.

The package does not yet own `AVCaptureDepthDataOutput` setup or RGB/depth synchronization. `AVCaptureDataOutputSynchronizer` integration remains a near-term item so it can be added without silently changing app-level video resolution/FPS policy.

## ARKit adapter

CameraGeometryKit does not own `ARSession`, tracking configuration, anchors, raycasts, world mapping, or scene reconstruction.

`ARKitFrameAdapter` provides the geometry boundary between `ARFrame` camera/depth data and canonical image space. The frame geometry carries `ARCamera.intrinsics` in raw captured-image pixel coordinates and uses ARKit's `displayTransform(for:viewportSize:)` as the orientation/mapping source.

```swift
let cameraFrame = ARKitFrameAdapter.cameraFrame(
    from: frame,
    interfaceOrientation: interfaceOrientation
)

let canonical = cameraFrame.geometry.canonicalPoint(
    fromARKitNormalized: normalizedImagePoint
)
```

ARKit's display transform can include front-camera presentation mirroring. The adapter removes that presentation reflection when converting points into CameraGeometryKit canonical space, which remains upright and non-mirrored.

Depth adapters cover `capturedDepthData`, `sceneDepth`, and `smoothedSceneDepth`:

```swift
let depth = ARKitFrameAdapter.depthFrame(
    from: frame,
    source: .sceneDepth,
    interfaceOrientation: interfaceOrientation
)
```

Feature availability stays capability-checked by the app/configuration; CameraGeometryKit does not infer it from device models.
