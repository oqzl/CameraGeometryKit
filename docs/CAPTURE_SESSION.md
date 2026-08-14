# Capture Session

`CameraCaptureSession` is a deliberately thin owner of the mutable AVFoundation capture graph.

It owns camera authorization, one active video input, video-only or synchronized video/depth frame output, `AVCapturePhotoOutput`, serialized start/stop and camera switching, capture rotation, and canonical non-mirroring.

It does not own camera chrome, preview layout, focus/exposure UX, photo settings/delegates, movie recording, effects, Vision model selection, or product workflow state. It is not a universal `CameraManager`.

All mutable `AVCaptureSession` graph operations run on one private serial queue. `startRunning()` and `stopRunning()` are kept off MainActor.

The exposed `captureSession` is for attaching an `AVCaptureVideoPreviewLayer` and inspection. Do not mutate inputs, outputs, or running state through it.

## Video-only capture

```swift
let camera = CameraCaptureSession()
try await camera.start(position: .back)

for await frame in camera.frameStream.frames {
    // CameraFrame
}
```

## Synchronized depth capture

Depth is opt-in at session creation time:

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
        // CameraSynchronizedFrame
    }
}
```

The requested `sessionPreset` first establishes the active video format. CameraGeometryKit then chooses a requested depth type only from that format's `supportedDepthDataFormats`; it does not silently replace the color format. Video and depth outputs are delivered through `AVCaptureDataOutputSynchronizer`.

If depth was requested but the selected camera's active video format has no compatible requested depth format, session configuration fails explicitly.

## Preview and photos

The app owns preview layout and `videoGravity`. CameraGeometryKit can own the camera-specific preview rotation updates:

```swift
let previewLayer = AVCaptureVideoPreviewLayer(session: camera.captureSession)
previewLayer.videoGravity = .resizeAspect

var previewRotationBinding = camera.bindPreviewRotation(to: previewLayer)
```

`CameraPreviewRotationBinding` applies the current `RotationCoordinator` preview angle immediately and automatically reapplies later angle changes. Retain the binding while the preview is active. After switching to a different physical camera, stop/discard the old binding and create a new one for the new device.

`CameraRotation`, `observe(_:)`, and `applyPreviewAngle(to:)` remain available as lower-level APIs for diagnostics and specialized pipelines; normal preview code should prefer the binding.

Before issuing a photo request:

```swift
try await camera.preparePhotoCapture()
camera.photoOutput.capturePhoto(with: settings, delegate: delegate)
```

The app still owns `AVCapturePhotoSettings` and result/delegate policy.

On a camera switch, invalidate semantic analysis work and recreate the preview binding after the switch succeeds:

```swift
await vision.invalidate()
try await camera.switchCamera()
previewRotationBinding?.stop()
previewRotationBinding = camera.bindPreviewRotation(to: previewLayer)
```

In depth mode a switch to a camera whose active video format cannot provide the requested depth type fails and restores the previous input. The wrapper rebuilds its `RotationCoordinator` for a successful switch and reapplies the capture rotation/non-mirroring policy to video, depth, and photo connections. It never uses front/back fixed angle tables or device-model angle hacks.
