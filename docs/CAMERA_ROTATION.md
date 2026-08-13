# Camera Rotation

## Policy

Camera rotation is camera geometry, not UI orientation.

Use `AVCaptureDevice.RotationCoordinator` as the authoritative resolver. It provides separate values for preview and capture because those are different problems.

This policy incorporates field lessons accumulated in CamLab and is restated here so CameraGeometryKit is self-contained. The primary project source is CamLab's [`docs/iOS_Camera_Rotate.md`](https://github.com/oqzl/CamLab/blob/main/docs/iOS_Camera_Rotate.md). CameraGeometryKit treats that document as historical/implementation evidence and this document as the reusable library policy derived from it.

## Separate these values

| Concern | Source / API | Meaning |
|---|---|---|
| App UI orientation policy | UIKit / SwiftUI | whether and how app chrome rotates |
| Physical device posture | `UIDeviceOrientation` | optional UI/debug signal |
| Preview rotation | `videoRotationAngleForHorizonLevelPreview` | level preview relative to gravity |
| Capture rotation | `videoRotationAngleForHorizonLevelCapture` | level captured media relative to gravity |
| VideoDataOutput applied rotation | `AVCaptureConnection.videoRotationAngle` | physical rotation already applied to delivered frame |
| Mirroring | `isVideoMirrored` | horizontal reflection, independent of rotation |
| Writer transform | `AVAssetWriterInput.transform` | playback orientation metadata for custom recording |

Do not collapse these into one `orientation` variable.

## RotationCoordinator is the source of truth

```swift
let rotation = CameraRotation(device: device, previewLayer: previewLayer)
rotation.applyPreviewAngle(to: previewConnection)
rotation.applyCaptureAngle(to: captureConnection)
```

When the camera changes, recreate the coordinator for the new `AVCaptureDevice`.

## Preview and capture are different

Camera chrome may remain portrait-native while preview and capture orientation change independently with physical camera orientation. The UI is not an orientation sensor for the camera.

Invalid assumptions include deriving `captureAngle` from interface orientation, using preview angle as capture angle, or rotating camera chrome by capture angle.

## `AVCaptureVideoDataOutput` physically rotates frames

When `videoRotationAngle` is applied to an `AVCaptureVideoDataOutput` connection, AVFoundation rotates the pixel buffers it delivers. If CameraGeometryKit's analysis stream uses the capture angle:

```text
Camera sensor
    ↓
AVCaptureVideoDataOutput connection rotation
    ↓
CameraFrame.pixelBuffer
    = already upright canonical frame
```

`CameraFrame.geometry.appliedVideoRotationAngle` describes what already happened. It is not a transform request for consumers. Never apply a second fixed 90° correction.

## Custom preview from VideoDataOutput

Do not change VideoDataOutput connection rotation merely to animate a custom preview. Reconfiguration can interrupt delivery and per-frame rotation costs memory/energy. Prefer rotating presentation with the preview angle.

A canonical analysis stream is a different use case: an upright frame intentionally simplifies Vision and image-processing semantics. If performance becomes critical, measure before adding a separate raw path; never silently change frame semantics.

## Photos

Before capture, apply the capture angle to the photo output connection. Do not then add another fixed EXIF/UIImage/Core Image/UI correction in the viewer.

## MovieFileOutput

Set the capture angle before recording starts. Recommended behavior is capture angle fixed at recording start, preview may continue to follow preview angle, and the next recording resolves capture angle again.

## `AVCaptureVideoDataOutput + AVAssetWriter`

For custom recording, do not physically rotate every frame merely to encode orientation. Prefer:

```text
sensor-native / unrotated sample buffer
        +
resolved capture angle
        ↓
AVAssetWriterInput.transform
        ↓
movie track metadata
```

If a VideoDataOutput connection already applied an angle, include that in the calculation. A clear writer-specific policy is connection 0° plus writer transform.

The writer must not inspect `UIDeviceOrientation`, `UIWindowScene`, front/back position, or device model. It consumes a resolved capture orientation.

## Front camera and newer devices

Sensor-native orientation can differ by camera module and device generation. Never write a model branch such as `if deviceModel.contains("iPhone17") { angle += 90 }`.

A model-specific failure belongs in `docs/validation/<device>/` with recorded angles and outputs. Fix the incorrect generic assumption, not the device.

## Mirroring is separate

| Target | Back | Front |
|---|---:|---:|
| Preview | no mirror | mirror |
| Analysis frame | no mirror | no mirror |
| Saved photo | no mirror | usually no mirror |
| Saved video | no mirror | usually no mirror |

Do not encode mirror behavior into rotation-angle logic.

## Camera switching

On camera switch:

1. stop observing the old coordinator
2. switch input on the session's serialized configuration context
3. create a coordinator for the new device
4. apply preview angle
5. apply capture/analysis angle
6. apply preview mirror policy
7. apply analysis/save mirror policy
8. invalidate old Vision/configuration generation
9. update diagnostics

Do not reuse the old coordinator.

## UI orientation lock

Some camera apps intentionally keep camera chrome portrait-native while the device is physically landscape. Supported interface orientation policy and scene geometry are UI responsibilities and remain independent from camera preview/capture rotation.

`requestGeometryUpdate` is not a substitute for correct supported-orientation policy, and neither should be converted into camera angles. CameraGeometryKit does not own product UI orientation policy.

## Project source material

- [CamLab: `docs/iOS_Camera_Rotate.md`](https://github.com/oqzl/CamLab/blob/main/docs/iOS_Camera_Rotate.md) — the detailed application-level rotation/orientation design that this package generalizes.
- [CamLab: `docs/CAMERA_FRAME_ORIENTATION.md`](https://github.com/oqzl/CamLab/blob/main/docs/CAMERA_FRAME_ORIENTATION.md) — field rules for already-rotated `AVCaptureVideoDataOutput` frames and avoiding downstream double rotation.

## Official Apple references

- [AVCaptureDevice.RotationCoordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator)
- [Preview rotation angle](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationangleforhorizonlevelpreview)
- [Capture rotation angle](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationangleforhorizonlevelcapture)
- [AVCaptureConnection.videoRotationAngle](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle)
- [AVAssetWriterInput.transform](https://developer.apple.com/documentation/avfoundation/avassetwriterinput/transform)
- [WWDC23: Support external cameras in your iPadOS app](https://developer.apple.com/videos/play/wwdc2023/10106/)
