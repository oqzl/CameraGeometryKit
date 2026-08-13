# Capture Session

`CameraCaptureSession` is a deliberately thin owner of the mutable AVFoundation capture graph.

It owns camera authorization, one active video input, `CameraFrameStream.output`, `AVCapturePhotoOutput`, serialized start/stop and camera switching, capture rotation, and canonical non-mirroring.

It does not own camera chrome, preview layout, focus/exposure UX, photo settings/delegates, movie recording, effects, Vision model selection, or product workflow state. It is not a universal `CameraManager`.

All mutable `AVCaptureSession` graph operations run on one private serial queue. `startRunning()` and `stopRunning()` are kept off MainActor.

The exposed `captureSession` is for attaching an `AVCaptureVideoPreviewLayer` and inspection. Do not mutate inputs, outputs, or running state through it.

```swift
let camera = CameraCaptureSession()
try await camera.start(position: .back)

let previewLayer = AVCaptureVideoPreviewLayer(session: camera.captureSession)
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

Before issuing a photo request:

```swift
try await camera.preparePhotoCapture()
camera.photoOutput.capturePhoto(with: settings, delegate: delegate)
```

The app still owns `AVCapturePhotoSettings` and result/delegate policy.

On a camera switch, invalidate semantic analysis work and recreate preview rotation after the switch succeeds:

```swift
vision.invalidate()
try await camera.switchCamera()
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

The wrapper rebuilds its capture `RotationCoordinator` for the new physical device, updates frame camera identity, and reapplies capture rotation and non-mirroring. It never uses front/back fixed angle tables or device-model angle hacks.
