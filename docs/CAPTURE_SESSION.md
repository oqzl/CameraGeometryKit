# Capture Session

`CameraCaptureSession` is a deliberately thin owner of the mutable AVFoundation capture graph.

It owns camera authorization, one active video input, `CameraFrameStream.output`, `AVCapturePhotoOutput`, serialized start/stop and camera switching, capture rotation, canonical non-mirroring, and narrow attachment points for one optional audio input and one app-owned `AVCaptureMovieFileOutput`.

It does not own camera chrome, preview layout, focus/exposure UX, photo settings/delegates, movie recording lifecycle, temporary-file or persistence policy, effects, Vision model selection, or product workflow state. It is not a universal `CameraManager`.

All mutable `AVCaptureSession` graph operations run on one private serial queue. `startRunning()` and `stopRunning()` are kept off MainActor.

The exposed `captureSession` is for attaching an `AVCaptureVideoPreviewLayer` and inspection. Do not mutate inputs, outputs, presets, or running state through it.

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

## Optional audio and movie output

Apps that record with `AVCaptureMovieFileOutput` still keep the output object and recording lifecycle themselves. `CameraCaptureSession` only performs the capture-graph mutation on its serialized queue and applies the package's capture rotation and canonical non-mirroring policy to the movie connection.

Microphone authorization and device choice also remain app policy. After authorization, attach the selected audio device and app-owned movie output through the wrapper:

```swift
let movieOutput = AVCaptureMovieFileOutput()
let microphone = AVCaptureDevice.default(for: .audio)!

try await camera.setAudioCaptureDevice(microphone)
try await camera.setMovieFileOutput(movieOutput, sessionPreset: .high)

movieOutput.startRecording(to: url, recordingDelegate: delegate)
```

Returning to photo mode can detach the movie output and audio input without exposing independent capture-graph mutation to the app:

```swift
try await camera.setMovieFileOutput(nil, sessionPreset: .photo)
try await camera.setAudioCaptureDevice(nil)
```

These methods intentionally do not request microphone permission, choose recording formats, start or stop recording, create temporary files, or persist media. Those decisions remain in the application.

On a camera switch, invalidate semantic analysis work and recreate preview rotation after the switch succeeds:

```swift
vision.invalidate()
try await camera.switchCamera()
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

The wrapper rebuilds its capture `RotationCoordinator` for the new physical device, updates frame camera identity, and reapplies capture rotation and non-mirroring to frame, photo, and attached movie connections. It never uses front/back fixed angle tables or device-model angle hacks.
